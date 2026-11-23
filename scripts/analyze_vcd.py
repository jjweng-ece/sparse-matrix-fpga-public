"""Count actual emitted VCD bit events in the common [measuring rise, fall) window.

No physical capacitance, clock load, cell delay or power model is implied.
"""
import argparse
import gzip
import json
from collections import defaultdict
from pathlib import Path

MONITORS = {
    'base_mul_a': 8, 'base_mul_b': 8, 'sparse_mul_a': 8, 'sparse_mul_b': 8,
    'base_product': 16, 'sparse_product': 16,
    'base_product_q': 16, 'sparse_product_q': 16,
    'base_acc': 32, 'sparse_acc': 32,
    'base_pvalid': 1, 'sparse_pvalid': 1, 'base_valid': 1, 'sparse_valid': 1,
    'sparse_a_zero': 1, 'sparse_b_zero': 1, 'sparse_zero': 1, 'sparse_isolate': 1,
    'capture_condition': 1, 'base_acc_condition': 1, 'sparse_acc_condition': 1,
    'clk': 1, 'measuring': 1,
}


def read_vcd(path):
    op = gzip.open if str(path).endswith('.gz') else open
    declarations = {}
    events = []
    scopes = []
    widths = {}
    time = 0
    timescale = None
    with op(path, 'rt', encoding='ascii') as stream:
        header = True
        for line in stream:
            line = line.strip()
            if not line:
                continue
            if header:
                if line.startswith('$timescale'):
                    parts = line.split()
                    if '$end' in parts:
                        timescale = ' '.join(parts[1:-1])
                    else:
                        timescale = next(stream).strip()
                elif line.startswith('$scope'):
                    scopes.append(line.split()[2])
                elif line.startswith('$upscope'):
                    scopes.pop()
                elif line.startswith('$var'):
                    parts = line.split()
                    width, code, name = int(parts[2]), parts[3], parts[4]
                    if width == 1 and len(parts) > 5 and parts[5].startswith('['):
                        name += parts[5]  # ModelSim 10.1d bit-blasted vector declaration
                    declarations['.'.join(scopes + [name])] = (code, width)
                    if code in widths and widths[code] != width:
                        raise ValueError('inconsistent alias widths')
                    widths[code] = width
                elif line.startswith('$enddefinitions'):
                    header = False
                continue
            if line.startswith('#'):
                time = int(line[1:])
            elif line[0] in '01xXzZ':
                events.append((time, line[1:], line[0].lower()))
            elif line[0] in 'bB':
                value, code = line[1:].split()
                value = value.lower()
                if code not in widths:
                    raise ValueError('event for undeclared signal')
                fill = value[0] if value[0] in 'xz' else '0'
                events.append((time, code, value.rjust(widths[code], fill)))
    if timescale is None:
        raise ValueError('missing VCD timescale')
    return declarations, events, timescale


def count_events(declarations, events, marker_name, names):
    marker = declarations[marker_name][0]
    rises = [t for t, code, val in events if code == marker and val == '1']
    if len(rises) != 1:
        raise ValueError('expected exactly one measurement interval')
    start = rises[0]
    falls = [t for t, code, val in events if code == marker and val == '0' and t > start]
    if len(falls) != 1:
        raise ValueError('measurement window never closed or closed multiple times')
    end = falls[0]
    selected_codes = {declarations[name][0] for name in names}
    old = {}
    totals = defaultdict(int)
    unknown = defaultdict(int)
    checked_initial_state = False
    for t, code, val in events:
        if t >= start and not checked_initial_state:
            for selected in selected_codes:
                if selected not in old or any(c in 'xz' for c in old[selected]):
                    raise ValueError('unknown/uninitialized signal at measurement boundary')
            checked_initial_state = True
        if code not in selected_codes:
            continue
        before = old.get(code)
        if start <= t < end:
            if before is None or any(c in 'xz' for c in before + val):
                unknown[code] += 1
            else:
                totals[code] += (int(before, 2) ^ int(val, 2)).bit_count()
        old[code] = val
    if any(unknown.values()):
        raise ValueError(f'unknown/uninitialized measured transition(s): {dict(unknown)}')
    result = {}
    for name in names:
        code, width = declarations[name]
        result[name] = dict(width=width, toggles=totals[code], unknown_events=unknown[code])
    # Count enable high at rising edges using settled timestamp groups.
    levels = {}
    grouped = defaultdict(list)
    for t, code, val in events:
        grouped[t].append((code, val))
    clk_code = declarations.get('tb_mac_equiv.clk', (None,))[0]
    rising = 0
    high = defaultdict(int)
    for t, group in grouped.items():
        prior_clk = levels.get(clk_code)
        prior_conditions = {name: levels.get(declarations[name][0])
                            for name in names if name.endswith('condition')}
        for code, val in group:
            levels[code] = val
        if start <= t < end and prior_clk == '0' and levels.get(clk_code) == '1':
            rising += 1
            for name in names:
                if name.endswith('condition'):
                    value = prior_conditions[name]  # pre-edge register update condition
                    if value not in ('0', '1'):
                        raise ValueError('unknown condition on measured clock edge')
                    high[name] += int(value)
    return dict(start_tick=start, end_tick=end, duration_ticks=end-start,
                clock_rising_edges=rising, condition_high_edges=dict(high), signals=result)


def analyze(path):
    declarations, events, timescale = read_vcd(path)
    names = []
    components = {}
    for short, width in MONITORS.items():
        name = 'tb_mac_equiv.' + short
        if name in declarations and declarations[name][1] == width:
            parts = [name]
        else:
            parts = [f'{name}[{i}]' for i in range(width)]
            if any(p not in declarations or declarations[p][1] != 1 for p in parts):
                raise ValueError(f'missing signal or unexpected width: {name}')
        if short != 'measuring':
            names.extend(parts)
            components[name] = parts
    result = count_events(declarations, events, 'tb_mac_equiv.measuring', names)
    raw_signals = result['signals']
    result['signals'] = {
        name: dict(width=sum(raw_signals[p]['width'] for p in parts),
                   toggles=sum(raw_signals[p]['toggles'] for p in parts),
                   unknown_events=sum(raw_signals[p]['unknown_events'] for p in parts))
        for name, parts in components.items()
    }
    result['timescale'] = timescale
    result['groups'] = {}
    def group(label, shorts):
        result['groups'][label] = sum(result['signals']['tb_mac_equiv.' + s]['toggles'] for s in shorts)
    for impl in ('base', 'sparse'):
        group(impl + '_operand', [impl + '_mul_a', impl + '_mul_b'])
        group(impl + '_product', [impl + '_product'])
        group(impl + '_product_q', [impl + '_product_q'])
        group(impl + '_accumulator', [impl + '_acc'])
        group(impl + '_registers', [impl + '_product_q', impl + '_acc', impl + '_pvalid', impl + '_valid'])
    group('zero_detector', ['sparse_a_zero', 'sparse_b_zero', 'sparse_zero'])
    group('isolation_control', ['sparse_isolate'])
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('vcd', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    text = json.dumps(analyze(args.vcd), indent=2) + '\n'
    if args.output:
        args.output.write_text(text)
    else:
        print(text)
