import unittest
from model.golden_mac import MacModel, signed32


class GoldenTests(unittest.TestCase):
    def test_latency_zero_and_drain(self):
        m = MacModel()
        self.assertEqual(m.tick(0, 0, 1, 127, 127), (0, 0))
        self.assertEqual(m.tick(1, 0, 1, -128, -128), (0, 0))
        self.assertEqual(m.tick(1, 0, 1, 0, -128), (1, 16384))
        self.assertEqual(m.tick(1, 0, 1, -128, 127), (1, 16384))
        self.assertEqual(m.tick(1, 0, 0, 99, -12), (1, 128))
        self.assertEqual(m.tick(1, 0, 0, -128, -128), (0, 128))

    def test_clear_and_reset_flush(self):
        for reset in (False, True):
            m = MacModel()
            m.tick(1, 0, 1, 3, 5)
            self.assertEqual(m.tick(int(not reset), int(not reset), 1, 7, 9), (0, 0))
            self.assertEqual(m.tick(1, 0, 0, 0, 0), (0, 0))

    def test_legal_traffic_wrap_both_directions(self):
        for a, b, count in ((-128, -128, 131073), (-128, 127, 132106)):
            m = MacModel()
            for _ in range(count):
                m.tick(1, 0, 1, a, b)
            valid, bits = m.tick(1, 0, 0, 0, 0)
            self.assertEqual((valid, bits), (1, (a * b * count) & 0xffffffff))
        self.assertEqual(signed32(0x80000000), -2147483648)
        self.assertEqual(signed32(0x7fffffff), 2147483647)

    def test_reject_out_of_range(self):
        with self.assertRaises(ValueError):
            MacModel().tick(1, 0, 1, 128, 0)


if __name__ == '__main__':
    unittest.main()
