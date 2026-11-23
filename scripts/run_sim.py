"""Run real ModelSim in an ASCII staging directory; keep immutable run evidence."""
import argparse
import csv
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from generate_vectors import generate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sim-dir', type=Path, help='directory containing vsim/vlog/vlib')
    args = parser.parse_args()
    stamp = datetime.now().astimezone().strftime('%Y%m%dT%H%M%S%z')
    run = ROOT / 'results' / 'logs' / stamp
    run.mkdir(parents=True, exist_ok=False)
    evidence = dict(run=stamp, local_time=datetime.now().astimezone().isoformat(),
                    python=sys.version, platform=platform.platform(), target='RTL simulation; no FPGA part selected',
                    commands=[], status='FAIL', source_sha256={})
    for folder in ('rtl', 'tb', 'model', 'tests', 'scripts'):
        for src in sorted((ROOT / folder).glob('*')):
            if src.is_file():
                evidence['source_sha256'][src.relative_to(ROOT).as_posix()] = hashlib.sha256(src.read_bytes()).hexdigest()

    def execute(label, argv, cwd):
        entry = dict(label=label, argv=[str(x) for x in argv], cwd=str(cwd))
        evidence['commands'].append(entry)
        proc = subprocess.run(entry['argv'], cwd=cwd, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, timeout=180, errors='replace')
        entry['exit_code'] = proc.returncode
        (run / (label + '.log')).write_text(proc.stdout, encoding='utf-8')
        print(f'{label}: exit={proc.returncode}', flush=True)
        if proc.returncode:
            raise RuntimeError(f'{label} failed; see {run / (label + ".log")}')
        return proc.stdout

    try:
        execute('python_tests', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-v'], ROOT)
        sim = args.sim_dir
        if sim is None:
            found = shutil.which('vsim')
            if not found:
                raise RuntimeError('vsim not found; use --sim-dir. Python tests alone are not RTL PASS.')
            sim = Path(found).parent
        suffix = '.exe' if os.name == 'nt' else ''
        def tool(name):
            path = sim / (name + suffix)
            if not path.is_file():
                raise RuntimeError(f'missing simulator executable: {path}')
            return str(path.resolve())
        execute('simulator_version', [tool('vsim'), '-version'], ROOT)
        # Legacy ModelSim installations can reject Unicode working directories.
        with tempfile.TemporaryDirectory(prefix='sparse_mac_') as tmp:
            stage = Path(tmp)
            str(stage).encode('ascii')
            shutil.copy2(ROOT / 'rtl/mac_baseline.sv', stage / 'mac_baseline.sv')
            shutil.copy2(ROOT / 'tb/tb_mac_baseline.sv', stage / 'tb_mac_baseline.sv')
            manifest = generate(stage / 'vectors.txt')
            (run / 'vector_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
            evidence['vectors'] = manifest
            execute('vlib', [tool('vlib'), 'work'], stage)
            execute('vlog', [tool('vlog'), '-sv', 'mac_baseline.sv', 'tb_mac_baseline.sv'], stage)
            # onerror is valid inside a macro (a .do file), not a command string.
            macro = 'onerror {quit -code 1}\nrun -all\nquit -code 0\n'
            (stage / 'simulate.do').write_text(macro, encoding='ascii')
            (run / 'simulate.do').write_text(macro, encoding='ascii')
            try:
                output = execute('vsim', [tool('vsim'), '-c', '-onfinish', 'exit',
                                         '-l', 'transcript.log', 'work.tb_mac_baseline',
                                         '-do', 'do simulate.do'], stage)
            finally:
                if (stage / 'transcript.log').exists():
                    shutil.copy2(stage / 'transcript.log', run / 'transcript.log')
            marker = f"PASS baseline cycles={manifest['stats']['cycles']} retired={manifest['stats']['retired']}"
            if output.count(marker) != 1 or 'FAIL' in output or '** Error' in output or '** Fatal' in output:
                raise RuntimeError('Simulation did not produce exactly one expected PASS marker, or reported an error')
            evidence['status'] = 'PASS'
    except Exception as exc:
        evidence['error'] = str(exc)
        print(str(exc), file=sys.stderr)
    finally:
        (run / 'run.json').write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf-8')
        summary = ROOT / 'results/summary.csv'
        exists = summary.exists()
        with summary.open('a', newline='', encoding='utf-8') as stream:
            writer = csv.writer(stream)
            if not exists:
                writer.writerow(['run', 'status', 'cycles_checked', 'transactions_retired', 'evidence'])
            stats = evidence.get('vectors', {}).get('stats', {})
            writer.writerow([stamp, evidence['status'], stats.get('cycles', ''), stats.get('retired', ''),
                             run.relative_to(ROOT).as_posix() + '/run.json'])
        print(f"{evidence['status']}: evidence {run}", flush=True)
    return 0 if evidence['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
