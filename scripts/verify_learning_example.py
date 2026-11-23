"""No board/EDA/dependencies: recompute example and check archived ModelSim evidence."""
import hashlib,json,re,sys
from pathlib import Path
R=Path(__file__).resolve().parents[1]
A=[[2,0,3,0],[0,0,0,0],[0,-1,0,0],[0,0,0,4]]
B=[[1,2,0,-1],[3,0,1,2],[0,-2,4,1],[1,1,-1,0]]
wrap=lambda n:((n+(1<<31))%(1<<32))-(1<<31)
dense=[[wrap(sum(A[i][k]*B[k][j] for k in range(4))) for j in range(4)] for i in range(4)]
values=[];columns=[];pointers=[0]
for row in A:
 for k,v in enumerate(row):
  if v!=0:values.append(v);columns.append(k)
 pointers.append(len(values))
sparse=[[wrap(sum(values[p]*B[columns[p]][j] for p in range(pointers[i],pointers[i+1]))) for j in range(4)] for i in range(4)]
expected=[[2,-2,12,1],[0,0,0,0],[-3,0,-1,-2],[4,4,-4,0]]
assert dense==sparse==expected
assert (values,columns,pointers)==([2,3,-1,4],[0,2,1,3],[0,2,2,3,4])
assert wrap((1<<31)-1+1)==-(1<<31)
D=R/'learning/circuit_walkthrough/results/simulation_20261123T105513+0800'
golden=json.loads((D/'golden.json').read_text());assert golden['a']==A and golden['b']==B and golden['c']==expected
run=json.loads((D/'run.json').read_text());assert run['status']=='PASS_ACTUAL_MODELSIM_CIRCUIT_WALKTHROUGH' and all(c['exit_code']==0 for c in run['commands'])
log=(D/'vsim.log').read_text();rows=re.findall(r'RESULT i=(\d+) dense=(-?\d+) csr=(-?\d+) golden=(-?\d+)',log)
flat=sum(expected,[]);assert len(rows)==16
assert all(int(i)==n and int(d)==int(s)==int(g)==flat[n] for n,(i,d,s,g) in enumerate(rows))
assert 'COUNTERS dense_cycles=178 csr_cycles=90 dense_mac=64 csr_mac=16' in log
print(json.dumps(dict(status='PASS_SOFTWARE_EXAMPLE_AND_ARCHIVED_EVIDENCE',python=sys.version.split()[0],a=A,b=B,c=dense,csr=dict(values=values,col_idx=columns,row_ptr=pointers),dense_mac=64,csr_mac=len(values)*4,archived_simulation=dict(dense_cycles=178,csr_cycles=90,output_checks=32,path=str(D.relative_to(R)),log_sha256=hashlib.sha256((D/'vsim.log').read_bytes()).hexdigest()),new_rtl_simulation=False,hardware_operations=0),indent=2))
