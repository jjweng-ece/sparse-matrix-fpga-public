# Four-Stage Project Plan (scope cut by gate, not by optimism)

## Gate 0 — Specification, research and repo (first)
Deliverables: locked numerical/timing contract, module/block diagram, repo tree, tool discovery, literature notes w/ source/date, slide outline and demo storyboard.
Done when both a human and a testbench can unambiguously say what one transaction means.

## Gate 1 — Baseline + verification
Build signed 8x8->16 multiply, 32-bit accumulator and a fixed-latency valid pipeline, independent golden model, directed/random self-check TB and simulation script. Record actual sim result. Do not proceed while FAIL/uncompiled.
Fallback: complete technical report with Python numerics if HDL tool not installed locally; no false PASS claims.

## Gate 2 — Sparse-aware optimization + measurable tradeoff
Add zero detection / operand isolation; compare same input timing and output results. Generate workload suite, VCD, toggle CSV and plots. Quartus compile/synthesis with consistent settings. Record no-improvement results too.
Fallback: report control opportunity/toggle evidence, and label power unmeasured when Power Analyzer unavailable.

## Gate 3 — FPGA demo & portfolio
Confirm board revision, pin map and clock. Compile, program, switch between workload modes, confirm statuses on LEDs and record board demo. Photograph board or screen only after actual run. Publish README with build steps, results, limits, architecture and short demo clip.
Fallback: RTL simulation plus reproducible repo remains a valid student side project, but not a completed FPGA demo.

## Gate 4 — Real sparse matrix engine (stretch)
Implement 4x4 dense and CSR sparse hardware, match one-MAC budget, verify complete output matrices, include metadata overhead and measured latency. Scale to 8x8 / 16x16 only after 4x4 works.
If schedule is tight, preserve Gate 1–3 and postpone Gate 4 to post-course GitHub v0.2.

## Weekly example cadence
- Week 1: Gate 0 + Gate 1, slide story and foundational literature.
- Week 2: Gate 2, functional verification and first plots.
- Week 3: Gate 3, board prototype and reproducible results.
- Week 4: polish talk, slide design, rehearse and publish; Gate 4 if ahead of schedule.

## Success criteria
- Must: clearly explained talk, complete referenced slides, correct RTL MAC equivalence, reproducible simulation logs.
- Strong: synthesizable sparse-aware controller, activity comparison, timing/resource reports.
- Excellent: on-board demonstration, vendor power estimate with limitations, and/or 4x4 CSR sparse matrix engine with measured cycle tradeoffs.
