"""Deterministic cycle vectors, plus independently counted traffic/coverage."""
import hashlib
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from model.golden_mac import MacModel, signed32

SEEDS = (0x1234, 0x4567, 0x89AB)


def generate(path):
    m = MacModel()
    stats = dict(cycles=0, accepted=0, retired=0, flushed=0,
                 positive_overflows=0, negative_overflows=0,
                 zero_valid=0, reset_cycles=0, clear_cycles=0)
    sections = {}

    with Path(path).open('w', encoding='ascii', newline='\n') as f:
        def emit(section, a=0, b=0, valid=0, clear=0, rst=1):
            before = signed32(m.acc)
            pending = m.pending
            if not rst or clear:
                stats['flushed'] += int(pending is not None)
            else:
                stats['accepted'] += int(bool(valid))
                stats['zero_valid'] += int(bool(valid) and (a == 0 or b == 0))
                if pending is not None:
                    total = before + pending
                    stats['positive_overflows'] += int(total > 2147483647)
                    stats['negative_overflows'] += int(total < -2147483648)
            ov, result = m.tick(rst, clear, valid, a, b)
            stats['retired'] += ov
            stats['cycles'] += 1
            stats['reset_cycles'] += int(not rst)
            stats['clear_cycles'] += int(bool(rst and clear))
            sections[section] = sections.get(section, 0) + 1
            f.write(f'{rst} {clear} {valid} {a} {b} {ov} {result:08x}\n')

        emit('initial_reset', valid=1, a=127, b=127, rst=0)
        emit('initial_reset', rst=0, clear=1, valid=1)
        emit('idle')
        for a, b in ((3, 5), (0, 127), (-128, 0), (0, 0),
                     (-128, 127), (127, -128), (-128, -128), (127, 127),
                     (-1, 1), (1, -1), (-1, -1)):
            emit('directed', a, b, 1)
        emit('valid_gaps')
        emit('valid_gaps', 127, -128)
        emit('valid_gaps', -7, -11, 1)
        emit('valid_gaps')
        for reset in (False, True):
            tag = 'reset_flush' if reset else 'clear_flush'
            emit(tag, 4, 5, 1)
            emit(tag, 127, 127, 1, clear=int(not reset), rst=int(not reset))
            emit(tag)
            emit(tag, 2, -3, 1)
            emit(tag)
            emit(tag, 7, 9, 1, clear=1)  # priority over coincident input
            emit(tag, valid=1, clear=1)
            emit(tag)
        emit('exhaustive', clear=1)
        for a in range(-128, 128):
            for b in range(-128, 128):
                emit('exhaustive', a, b, 1)
        emit('exhaustive')
        for tag, a, b, count in (('positive_overflow', -128, -128, 131073),
                                  ('negative_overflow', -128, 127, 132106)):
            emit(tag, clear=1)
            for _ in range(count):
                emit(tag, a, b, 1)
            emit(tag)
        for seed in SEEDS:
            rng = random.Random(seed)
            tag = f'random_0x{seed:04x}'
            emit(tag, clear=1)
            for _ in range(5000):
                emit(tag, rng.randint(-128, 127), rng.randint(-128, 127),
                     valid=int(rng.random() < .8), clear=int(rng.random() < .01),
                     rst=int(rng.random() >= .005))
            emit(tag)
        emit('final_drain')
        emit('final_drain')
    assert m.pending is None
    assert stats['accepted'] == stats['retired'] + stats['flushed']
    assert stats['positive_overflows'] and stats['negative_overflows']
    manifest = dict(stats=stats, sections=sections, seeds=list(SEEDS),
                    random_cycles_per_seed=5000, exhaustive_operand_pairs=65536,
                    vector_sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest(),
                    format='rst_n clear_acc in_valid signed_a signed_b expected_valid expected_hex32')
    return manifest


if __name__ == '__main__':
    dest = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('build/vectors.txt')
    dest.parent.mkdir(parents=True, exist_ok=True)
    manifest = generate(dest)
    dest.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))
