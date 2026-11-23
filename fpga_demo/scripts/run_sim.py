"""Real ModelSim integration regression; timestamped source snapshots and logs."""
import hashlib,json,re,shutil,subprocess,tempfile
from datetime import datetime
from pathlib import Path
from generate_rom import generate
ROOT=Path(__file__).resolve().parents[2]

def main():
    dest=ROOT/'fpga_demo/results/5B'/datetime.now().strftime('%Y%m%dT%H%M%S%f');dest.mkdir(parents=True)
    stage=Path(tempfile.mkdtemp(prefix='gate5_demo_'));generated=dest/'generated';generate(generated)
    sources=[*sorted((ROOT/'rtl/gate4').glob('*.sv')),*sorted((ROOT/'fpga_demo/rtl').glob('*.sv')),*sorted((ROOT/'fpga_demo/tb').glob('*.sv'))]
    assert (generated/'demo_rom.sv').read_bytes()==(ROOT/'fpga_demo/rtl/demo_rom.sv').read_bytes(),'stale authored ROM'
    snap=dest/'source_snapshot';snap.mkdir()
    for f in sources:shutil.copy2(f,stage/f.name);shutil.copy2(f,snap/f.name)
    shutil.copy2(generated/'tb_vectors.txt',stage/'tb_vectors.txt')
    tool=lambda n:Path('C:/altera/13.0sp1/modelsim_ase/win32aloem')/(n+'.exe')
    record=dict(status='FAIL',stage=str(stage),commands=[],sources={f.relative_to(ROOT).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sources})
    try:
        for label,argv in [('version',[tool('vsim'),'-version']),('vlib',[tool('vlib'),'work']),
            ('vlog',[tool('vlog'),'-sv',*[f.name for f in sources]]),
            ('vsim',[tool('vsim'),'-c','-onfinish','exit','work.tb_demo','-do','run -all; quit -code 0']),
            ('inputs',[tool('vsim'),'-c','-onfinish','exit','work.tb_inputs','-do','run -all; quit -code 0'])]:
            print('START '+label,flush=True)
            r=subprocess.run(list(map(str,argv)),cwd=stage,capture_output=True,text=True,errors='replace',timeout=180)
            output=r.stdout+r.stderr;(dest/(label+'.log')).write_text(output,encoding='utf-8')
            record['commands'].append(dict(argv=list(map(str,argv)),cwd=str(stage),exit_code=r.returncode))
            if r.returncode or (label=='vsim' and (not re.search('PASS DEMO successful_runs=11 output_pairs=176 negative_runs=2 reset_aborts=3',output) or '** Fatal:' in output or '** Error:' in output)):raise RuntimeError(label+' failed')
            if label=='inputs' and ('PASS INPUTS production_debounce=1000000 presses=2 reset_held_rejected=1' not in output or '** Fatal:' in output or '** Error:' in output):raise RuntimeError('input conditioning failed')
        record['status']='PASS'
    except Exception as e:record['error']=repr(e)
    finally:
        if (stage/'performance.csv').exists():shutil.copy2(stage/'performance.csv',dest/'performance.csv')
        (dest/'acceptance.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status']+' '+str(dest),flush=True)
    return int(record['status']!='PASS')
if __name__=='__main__':raise SystemExit(main())
