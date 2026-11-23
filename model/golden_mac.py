"""Independent integer/cycle reference; no HDL parsing or simulator dependency."""
MASK32 = (1 << 32) - 1


def signed32(bits):
    bits &= MASK32
    return bits - (1 << 32) if bits & (1 << 31) else bits


class MacModel:
    def __init__(self):
        self.acc = 0
        self.pending = None

    def tick(self, rst_n, clear_acc, in_valid, a, b):
        if not (-128 <= a <= 127 and -128 <= b <= 127):
            raise ValueError("operands must be signed 8-bit integers")
        if not rst_n or clear_acc:
            self.acc = 0
            self.pending = None
            return 0, 0
        valid = self.pending is not None
        if valid:
            self.acc = (self.acc + self.pending) % (1 << 32)
        self.pending = a * b if in_valid else None
        return int(valid), self.acc
