"""Independent arithmetic check of saved actual-FPGA numerical readback; no hardware IO."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent
runs=json.loads((R/'evidence/board/readback.json').read_text());checks=0;tiles=0
wrap=lambda n:((n+(1<<31))%(1<<32))-(1<<31)
for run in runs:
    assert run['source']=='SAVED_ACTUAL_BOARD_READBACK_NOT_NEW_HARDWARE_RUN'
    dc=sc=dm=sm=0
    for job in run['jobs']:
        a,b=job['a'],job['b'];expected=[[wrap(sum(a[r][k]*b[k][c] for k in range(4))) for c in range(4)] for r in range(4)]
        for output in job['outputs']:
            assert output==expected;checks+=16
        x,y,z,w=job['metrics'];dc+=x;sc+=y;dm+=z;sm+=w;tiles+=1
    assert (dc,sc,dm,sm)==(run['dense_cycles'],run['csr_cycles'],run['dense_macs'],run['csr_macs'])
assert len(runs)==6 and tiles==288 and checks==9216
print(json.dumps(dict(status='PASS_INDEPENDENT_CHECK_OF_SAVED_ACTUAL_BOARD_NUMBERS',runs=6,tiles=tiles,output_checks=checks,new_hardware_run=False,hardware_operations=0,power_measured=False)))
