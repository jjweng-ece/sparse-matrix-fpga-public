"""Independent small teaching vectors; actual ModelSim, frozen RTL snapshots and CSV/VCD."""
import csv,hashlib,json,shutil,subprocess,tempfile
from pathlib import Path
from datetime import datetime
P=Path(__file__).resolve().parent;R=P.parents[1]
D=P/'results'/datetime.now().astimezone().strftime('simulation_%Y%m%dT%H%M%S%z');D.mkdir(parents=True)
stage=Path(tempfile.mkdtemp(prefix='circuit_teaching_'))
tool=Path('C:/altera/13.0sp1/modelsim_ase/win32aloem')
A=[[2,0,3,0],[0,0,0,0],[0,-1,0,0],[0,0,0,4]]
B=[[1,2,0,-1],[3,0,1,2],[0,-2,4,1],[1,1,-1,0]]
C=[[sum(A[i][k]*B[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
values=[];cols=[];ptr=[0]
for row in A:
 for j,v in enumerate(row):
  if v:values.append(v);cols.append(j)
 ptr.append(len(values))
loads=[]
for eng in (0,1):
 for i,v in enumerate(sum(A,[]) if eng==0 else values):loads.append((eng,0,i,v))
 for i,v in enumerate(sum(B,[])):loads.append((eng,1,i,v))
 if eng:
  loads.extend((eng,3,i,v) for i,v in enumerate(cols))
  loads.extend((eng,4,i,v) for i,v in enumerate(ptr));loads.append((eng,5,0,len(values)))
(stage/'loads.txt').write_text(''.join(f'{e} {b} {a} {v&0xffffffff:08x}\n' for e,b,a,v in loads))
(stage/'expected.hex').write_text(''.join(f'{v&0xffffffff:08x}\n' for v in sum(C,[])))
(D/'golden.json').write_text(json.dumps(dict(a=A,b=B,c=C,values=values,col_idx=cols,row_ptr=ptr),indent=2)+'\n')
sources=[R/'rtl/gate4/matrix_mac.sv',R/'rtl/gate4/matrix_csr.sv',R/'ai_lab/memory_enable/rtl/matrix_dense_memce.sv',R/'ai_lab/memory_enable/rtl/sync_read_ram.sv',P/'tb_circuit_walkthrough.sv']
record=dict(status='FAIL',scope='Small teaching simulation; not a replacement for full verified regressions',stage=str(stage),seed='directed fixed vectors, no randomness',clock_period_ns=20,commands=[],source_sha256={str(s.relative_to(R)):hashlib.sha256(s.read_bytes()).hexdigest() for s in sources},hardware_operations=0)
try:
 for s in sources:shutil.copy2(s,stage/s.name)
 for label,args in [('version',[tool/'vsim.exe','-version']),('vlib',[tool/'vlib.exe','work']),('vlog',[tool/'vlog.exe','-sv',*[s.name for s in sources]]),('vsim',[tool/'vsim.exe','-c','-onfinish','exit','work.tb_circuit_walkthrough','-do','run -all; quit -code 0'])]:
  r=subprocess.run(list(map(str,args)),cwd=stage,capture_output=True,timeout=180)
  text=(r.stdout+r.stderr).decode(errors='replace');(D/(label+'.log')).write_text(text)
  record['commands'].append(dict(argv=list(map(str,args)),cwd=str(stage),exit_code=r.returncode))
  assert r.returncode==0 and '** Error:' not in text and '** Fatal:' not in text,label
  if label=='vsim':assert 'PASS_CIRCUIT_WALKTHROUGH mac_checks=12 matrix_outputs=32' in text
 for name in ['mac_trace.csv','engine_trace.csv']:
  with (stage/name).open() as f:
   rows=list(csv.reader(f))
  assert rows and all(len(row)==len(rows[0]) for row in rows),name+' malformed columns'
 record['status']='PASS_ACTUAL_MODELSIM_CIRCUIT_WALKTHROUGH'
finally:
 snap=D/'sources';snap.mkdir()
 for s in sources:shutil.copy2(s,snap/s.name)
 for name in ['mac_trace.csv','engine_trace.csv','circuit_trace.vcd','loads.txt','expected.hex']:
  if (stage/name).exists():shutil.copy2(stage/name,D/name)
 (D/'run.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps(dict(status=record['status'],evidence=str(D))))
assert record['status'].startswith('PASS')
