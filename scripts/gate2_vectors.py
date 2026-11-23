"""Gate 2 vectors; Gate 1 generator/model are imported without modification."""
import hashlib
import random
from collections import Counter
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from model.golden_mac import MacModel

SEEDS = (0x1234, 0x4567, 0x89AB)
RATES = (0, 25, 50, 75, 90)
ROWS = 4000


def write_rows(path, rows):
    m = MacModel()
    retired = accepted = flushed = 0
    with Path(path).open('w', encoding='ascii', newline='\n') as f:
        for rst, clear, valid, a, b in rows:
            if not rst or clear:
                flushed += int(m.pending is not None)
            else:
                accepted += valid
            ov, bits = m.tick(rst, clear, valid, a, b)
            retired += ov
            f.write(f'{rst} {clear} {valid} {a} {b} {ov} {bits:08x}\n')
    assert m.pending is None
    assert accepted == retired + flushed
    return dict(cycles=len(rows), accepted=accepted, retired=retired, flushed=flushed,
                vector_sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest())


def directed(path):
    rows = [(0, 0, 0, 0, 0)] * 2
    sections = {}
    def block(name, data):
        data = list(data)
        rows.extend(data)
        sections[name] = len(data)
    block('nonzero_prefix', [(1, 0, 1, -128, 127)] * 16)
    block('zero_burst_changing_partner', ((1, 0, 1, 0, (i % 255) - 128) for i in range(256)))
    block('alternating_zero_nonzero', ((1, 0, 1, -128 if i % 2 else 0, 127) for i in range(256)))
    block('invalid_noisy_operands', ((1, 0, 0, (i % 256) - 128, ((i * 97) % 256) - 128) for i in range(1024)))
    block('abrupt_transitions', [(1, 0, 1, 127, -128)] * 64 +
          [(1, 0, 1, 0, -128)] * 64 + [(1, 0, 1, -128, -128)] * 64)
    block('clear_reset_at_boundary', [(1, 1, 1, 127, 127), (1, 0, 1, 0, -128),
          (0, 1, 1, -128, -128), (1, 0, 0, 0, 0), (1, 0, 1, -1, 1)])
    rows += [(1, 0, 0, 0, 0)] * 2
    result = write_rows(path, rows)
    result['sections'] = sections
    return result


def workload(path, seed, rate, pattern):
    assert rate in RATES and pattern in ('random', 'bursty')
    rng = random.Random(seed)
    nonzero = [x for x in range(-128, 128) if x]
    pool = [(rng.choice(nonzero), rng.choice(nonzero)) for _ in range(100)]
    zero_count = ROWS * rate // 100
    if pattern == 'random':
        mask = [True] * zero_count + [False] * (ROWS - zero_count)
        random.Random(seed ^ 0x5A5A).shuffle(mask)
    else:
        # 20 periods of 200 cycles, each with an exact contiguous zero burst.
        mask = ([True] * (2 * rate) + [False] * (200 - 2 * rate)) * 20
    measured = []
    nz = z = 0
    for zero in mask:
        if zero:
            a, b = pool[z % 100]
            # Keep the nonzero partner changing even during long zero bursts.
            if z % 3 == 0:
                a = 0
            elif z % 3 == 1:
                b = 0
            else:
                a = b = 0
            z += 1
        else:
            a, b = pool[nz % 100]
            nz += 1
        measured.append((1, 0, 1, a, b))
    assert sum(a == 0 or b == 0 for _, _, _, a, b in measured) == zero_count
    normalized = sorted((a, b, count // (nz // 100))
                        for (a, b), count in Counter((r[3], r[4]) for r in measured if r[3] and r[4]).items())
    # Same reset/warm-up and predecessor state across all measurements.
    prefix = [(0, 0, 0, 0, 0)] * 2 + [(1, 0, 0, 0, 0)] * 4
    prefix += [(1, 0, 1, a, b) for a, b in pool[:16]]
    prefix += [(1, 1, 0, 0, 0), (1, 0, 0, 0, 0)]
    result = write_rows(path, prefix + measured + [(1, 0, 0, 0, 0)] * 2)
    result.update(seed=seed, zero_percent_requested=rate, zero_percent_realized=100 * z / ROWS,
                  pattern=pattern, measured_rows=ROWS, first_measure_row=len(prefix) + 1,
                  zero_transactions=z, nonzero_transactions=nz, nonzero_pool_size=100,
                  nonzero_distribution_sha256=hashlib.sha256(repr(normalized).encode()).hexdigest())
    return result
