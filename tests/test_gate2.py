import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from analyze_vcd import count_events, read_vcd
from gate2_vectors import workload


class Gate2Tests(unittest.TestCase):
    def test_hand_counted_vcd_alias_and_window(self):
        text = '''$timescale 1ns $end
$scope module tb $end
$var wire 1 ! measuring $end
$var wire 4 # data $end
$var wire 4 # alias $end
$upscope $end
$enddefinitions $end
#0
0!
b0 #
#10
1!
b11 #
#11
b101 #
#20
0!
b1111 #
'''
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'sample.vcd'
            p.write_text(text)
            decl, events, scale = read_vcd(p)
        r = count_events(decl, events, 'tb.measuring', ['tb.data', 'tb.alias'])
        self.assertEqual(scale, '1ns')
        self.assertEqual(r['signals']['tb.data']['toggles'], 4)  # 0000->0011->0101
        self.assertEqual(r['signals']['tb.alias']['toggles'], 4)
        self.assertEqual((r['start_tick'], r['end_tick']), (10, 20))

    def test_unknown_or_missing_window_fails(self):
        d = {'gate': ('!', 1), 'data': ('#', 1)}
        with self.assertRaises(ValueError):
            count_events(d, [(0, '!', '0'), (0, '#', 'x'), (1, '!', '1'),
                             (1, '#', '1'), (2, '!', '0')], 'gate', ['data'])
        with self.assertRaises(ValueError):
            count_events(d, [(0, '!', '0')], 'gate', ['data'])
        with self.assertRaises(ValueError):
            count_events(d, [(0, '!', '0'), (0, '#', 'x'), (1, '!', '1'),
                             (2, '!', '0')], 'gate', ['data'])

    def test_condition_sample_is_before_clock_edge(self):
        d = {'gate': ('!', 1), 'tb_mac_equiv.clk': ('#', 1), 'capture_condition': ('%', 1)}
        e = [(0, '!', '0'), (0, '#', '0'), (0, '%', '0'), (10, '!', '1'),
             (15, '#', '1'), (15, '%', '1'), (20, '!', '0')]
        r = count_events(d, e, 'gate', ['tb_mac_equiv.clk', 'capture_condition'])
        self.assertEqual(r['clock_rising_edges'], 1)
        self.assertEqual(r['condition_high_edges']['capture_condition'], 0)

    def test_modelsim_bit_blasted_declarations(self):
        text = '''$timescale
1ps
$end
$scope module tb $end
$var wire 1 ! measuring $end
$var wire 1 # data [1] $end
$var wire 1 % data [0] $end
$upscope $end
$enddefinitions $end
#0
0!
0#
0%
#10
1!
1#
1%
#20
0!
0#
'''
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'bits.vcd'
            p.write_text(text)
            d, e, scale = read_vcd(p)
        r = count_events(d, e, 'tb.measuring', ['tb.data[1]', 'tb.data[0]'])
        self.assertEqual(scale, '1ps')
        self.assertEqual(sum(s['toggles'] for s in r['signals'].values()), 2)

    def test_exact_rates_and_matched_distributions(self):
        with tempfile.TemporaryDirectory() as tmp:
            seen = set()
            for rate in (0, 25, 50, 75, 90):
                for pattern in ('random', 'bursty'):
                    m = workload(Path(tmp) / 'vectors.txt', 0x1234, rate, pattern)
                    self.assertEqual(m['zero_percent_realized'], rate)
                    self.assertEqual(m['measured_rows'], 4000)
                    seen.add(m['nonzero_distribution_sha256'])
            self.assertEqual(len(seen), 1)


if __name__ == '__main__':
    unittest.main()
