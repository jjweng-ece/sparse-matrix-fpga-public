import random
import unittest
from model.matrix_golden import matmul,encode_csr,decode_csr,matmul_csr


class MatrixGoldenTests(unittest.TestCase):
    def test_hand_calculated_identity_and_empty_rows(self):
        eye=[int(i==j) for i in range(4) for j in range(4)]
        b=list(range(-8,8))
        self.assertEqual(matmul(eye,b),[v & 0xffffffff for v in b])
        a=[0]*16;a[7]=-2
        v,c,p=encode_csr(a)
        self.assertEqual((v,c,p),([-2],[3],[0,0,1,1,1]))
        self.assertEqual(decode_csr(v,c,p),a)
        self.assertEqual(matmul_csr(v,c,p,b),matmul(a,b))

    def test_pure_bounds_and_legal_seeded_wrap(self):
        self.assertEqual(matmul([-128]*16,[-128]*16),[65536]*16)
        self.assertEqual(matmul([-128]*16,[127]*16),[(-65024)&0xffffffff]*16)
        self.assertEqual(matmul([-128]*16,[-128]*16,[0x7ffff000]*16),[0x8000f000]*16)
        self.assertEqual(matmul([-128]*16,[127]*16,[0x80001000]*16),[0x7fff1200]*16)

    def test_reject_noncanonical_csr(self):
        bad=[([1,2],[0,0],[0,2,2,2,2]),([1,2],[2,1],[0,2,2,2,2]),
             ([0],[0],[0,1,1,1,1]),([1],[0],[0,1,0,1,1]),([],[],[0,0,0,0,1])]
        for v,c,p in bad:
            with self.assertRaises(ValueError):decode_csr(v,c,p)

    def test_independent_sparse_dense_random(self):
        for seed in (0x1234,0x4567,0x89ab):
            rng=random.Random(seed)
            for _ in range(100):
                a=[rng.choice([0,0,rng.randint(-128,127)]) for _ in range(16)]
                b=[rng.randint(-128,127) for _ in range(16)]
                initial=[rng.randrange(1<<32) for _ in range(16)]
                self.assertEqual(matmul_csr(*encode_csr(a),b,initial),matmul(a,b,initial))


if __name__=='__main__':unittest.main()
