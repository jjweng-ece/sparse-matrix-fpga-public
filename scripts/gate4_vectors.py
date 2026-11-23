"""Deterministic matrix inputs, independent Python expected results."""
import json,random,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from model.matrix_golden import matmul,matmul_csr,encode_csr

def generate(dest):
    dest=Path(dest);dest.mkdir(parents=True,exist_ok=True)
    cases=[]
    def add(label,a,b,seeds=None,seed=None):
        v,c,p=encode_csr(a); expected=matmul(a,b,seeds)
        assert expected==matmul_csr(v,c,p,b,seeds)
        cases.append(dict(id=len(cases),label=label,a=a,b=b,seeds=seeds or [0]*16,
                          seeded=int(seeds is not None),values=v,columns=c,pointers=p,
                          expected=expected,seed=seed,nnz=len(v),zero_fraction=1-len(v)/16))
    eye=[int(i//4==i%4) for i in range(16)]
    b=list(range(-8,8))
    add('all_zero',[0]*16,b);add('identity',eye,b)
    add('negative_diagonal',[-128 if i//4==i%4 else 0 for i in range(16)],b)
    add('dense_negative',list(range(-16,0)),b)
    add('positive_bound',[-128]*16,[-128]*16)
    add('negative_bound',[-128]*16,[127]*16)
    add('positive_wrap',[-128]*16,[-128]*16,[0x7ffff000]*16)
    add('negative_wrap',[-128]*16,[127]*16,[0x80001000]*16)
    add('empty_rows_single',[0]*7+[-2]+[0]*8,b)
    add('zero_B',list(range(1,17)),[0]*16)
    add('zero_A_seed',[0]*16,b,[0x80000000+i for i in range(16)])
    for seed in (0x1234,0x4567,0x89ab):
        rng=random.Random(seed)
        for nnz in (0,1,2,4,8,12,14,16):
            for rep in range(5):
                a=[0]*16
                for pos in rng.sample(range(16),nnz):a[pos]=rng.choice([x for x in range(-128,128) if x])
                b=[rng.randrange(-128,128) for _ in range(16)]
                seeds=[rng.getrandbits(32) for _ in range(16)] if rep%2 else None
                add(f'random_{seed:x}_nnz{nnz}_{rep}',a,b,seeds,seed)
    lines=[str(len(cases))]
    for x in cases:
        lines += [f"{x['id']} {x['seeded']} {x['nnz']}", ' '.join(map(str,x['a'])),
                  ' '.join(map(str,x['b'])), ' '.join(f'{s:08x}' for s in x['seeds']),
                  ' '.join(map(str,x['pointers'])),
                  ' '.join(map(str,x['values']+[0]*(16-x['nnz']))),
                  ' '.join(map(str,x['columns']+[0]*(16-x['nnz']))),
                  ' '.join(f'{s:08x}' for s in x['expected'])]
    (dest/'vectors.txt').write_text('\n'.join(lines)+'\n')
    (dest/'vectors.json').write_text(json.dumps(cases,indent=2)+'\n')
    return cases

if __name__=='__main__':generate(sys.argv[1])
