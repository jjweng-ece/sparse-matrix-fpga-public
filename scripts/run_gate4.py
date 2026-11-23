"""Stage ASCII paths, run real ModelSim, retain phase-specific immutable evidence."""
import argparse,hashlib,json,re,shutil,subprocess,tempfile
from datetime import datetime
from pathlib import Path
from gate4_vectors import generate
ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser();p.add_argument('--phase',choices=['4B','4C','4D'],required=True);args=p.parse_args()
    stamp=datetime.now().astimezone().strftime('%Y%m%dT%H%M%S%f%z')
    dest=ROOT/'results/gate4'/args.phase/stamp;dest.mkdir(parents=True)
    logs=ROOT/'results/logs'/('gate4_'+args.phase+'_'+stamp);logs.mkdir(parents=True)
    stage=Path(tempfile.mkdtemp(prefix='matrix_gate4_'))
    cases=generate(dest)
    shutil.copy2(dest/'vectors.txt',stage/'vectors.txt')
    files=['rtl/gate4/matrix_mac.sv','rtl/gate4/matrix_dense.sv','tb/tb_matrix.sv']
    if args.phase!='4B':files.insert(2,'rtl/gate4/matrix_csr.sv')
    for f in files:shutil.copy2(ROOT/f,stage/Path(f).name)
    snapshot=dest/'source_snapshot';snapshot.mkdir()
    for f in files:shutil.copy2(ROOT/f,snapshot/Path(f).name)
    record=dict(phase=args.phase,stage=str(stage),status='FAIL',cases=len(cases),commands=[],sha256={})
    for f in files+['scripts/run_gate4.py','scripts/gate4_vectors.py','model/matrix_golden.py','docs/GATE4_SPEC.md']:
        record['sha256'][f]=hashlib.sha256((ROOT/f).read_bytes()).hexdigest()
    tool=lambda n:Path('C:/altera/13.0sp1/modelsim_ase/win32aloem')/(n+'.exe')
    jobs=[('version',[tool('vsim'),'-version']),('vlib',[tool('vlib'),'work']),
          ('vlog',[tool('vlog'),'-sv']+(['+define+WITH_CSR'] if args.phase!='4B' else [])+[Path(f).name for f in files]),
          ('vsim',[tool('vsim'),'-c','-onfinish','exit','work.tb_matrix','-do','onerror {quit -code 1}; run -all; quit -code 0'])]
    try:
        for label,argv in jobs:
            print('START '+label,flush=True)
            r=subprocess.run([str(a) for a in argv],cwd=stage,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace',timeout=180)
            (logs/(label+'.log')).write_text(r.stdout,encoding='utf-8')
            record['commands'].append(dict(argv=list(map(str,argv)),cwd=str(stage),exit_code=r.returncode))
            if r.returncode or (label=='vsim' and (not re.search(r'PASS MATRIX cases='+str(len(cases))+r'\b',r.stdout) or '** Fatal:' in r.stdout or '** Error:' in r.stdout)):
                raise RuntimeError(label+' failed: see retained log')
            print('END '+label,flush=True)
        shutil.copy2(stage/'performance.csv',dest/'performance.csv')
        record['status']='PASS'
    except Exception as e:record['error']=repr(e)
    finally:
        for f in stage.glob('*.log'):shutil.copy2(f,logs/f.name)
        record['log_root']=str(logs.relative_to(ROOT));record['vectors_sha256']=hashlib.sha256((dest/'vectors.txt').read_bytes()).hexdigest()
        (dest/'acceptance.json').write_text(json.dumps(record,indent=2)+'\n')
        print(record['status']+' '+str(dest),flush=True)
    return int(record['status']!='PASS')
if __name__=='__main__':raise SystemExit(main())
