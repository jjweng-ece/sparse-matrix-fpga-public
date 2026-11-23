# Public evidence: Gate 4 and teaching replay

This is the curated public evidence index, not a rewritten historical experiment.

- Complete Gate 4 RTL regression: [vsim.log](../evidence/gate4/vsim.log), [vlog.log](../evidence/gate4/vlog.log), [acceptance.json](../evidence/gate4/acceptance.json), [performance.csv](../evidence/gate4/performance.csv).
- Fixed small ModelSim teaching run: `learning/circuit_walkthrough/results/simulation_20261123T235832+0800/` contains actual CSV, VCD, log, golden input and source snapshots.
- Earlier teaching run retained for the standard-library exercise: `simulation_20261123T105513+0800/`.
- Saved actual-board arithmetic and counter audit: `python verify_saved_board.py`; input/readback numerical records in `evidence/board/readback.json`.

Public log copies redact machine paths only. PROVENANCE.json retains original and public-file hashes. Original private archives, failures and vendor reports are not replaced. The teaching example does not substitute for the full regression; no newly generated Python value is presented as hardware output. Power and formal JTAG signoff limitations remain as stated in README.
