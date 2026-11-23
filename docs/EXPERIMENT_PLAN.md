# Experiment Matrix & Evidence Plan

## Experiment 0 — Correctness
- Both MAC variants vs independent Python reference, also back-to-back cross-comparison.
- Directed patterns: reset, idle, nonzero, one/both zero, signed -128 and 127, wraparound, repeated values, valid gaps, flush, clear priority.
- Randomized patterns with fixed seeds e.g. 0x1234, 0x4567, 0x89AB; one documented reproducible command generates all test data.
- For matrix stretch: compare every C[i,j] to a Python int64 reference reduced modulo 2^32; include all-zero, dense, diagonal, clustered, random sparse, and sparse irregular patterns.

## Experiment 1 — Activity vs zero-content
- Controlled zero-valued *valid multiplication* transaction rates: 0%, 25%, 50%, 75%, 90%. Keep transaction timing, nonzero-value distribution, total cycles and seed family fixed, and record actual realized percentages.
- Additional temporal distributions: zeros randomly distributed vs bursty/clustered with same fraction. Compare activity on selected multiplier input registers, operand nets and accumulator; avoid using a cherry-picked signal as whole-chip power.
- Capture VCD after reset warm-up. Bit-toggle metric and signal scope/width must be recorded. Distinguish logical transitions from clock pin capacitance and FPGA power.

## Experiment 2 — Implementation cost
- Target the same exact Quartus version, target FPGA device, synthesis settings, period constraints and seed where possible. Capture ALMs/LEs, registers, DSPs, Fmax, warnings, and implementation tool versions. If gate-level differences vanish due to optimization, report that.
- Power estimate: if supported, feed credible signal activity VCD into vendor Power Analyzer. Keep voltage, frequency, cooling assumptions, placement settings, I/O and use-case fixed. Report total, static and dynamic separately when available. Estimation is NOT board measurement.
- Optional gate-level ASIC proof: an actual compatible std-cell Liberty + ICG + mapped netlist; do not claim ASIC power from toggles alone.

## Experiment 3 — Actual sparse matrix scheduling (stretch)
- N=4, one-multiplier dense and CSR sparse designs with matched clock and numerical semantics.
- Sparsity: 0%, 25%, 50%, 75%, 90%, 100%; randomized positions as well as contiguous patterns.
- Required metrics: arithmetic MAC count, total cycles, kernel cycles, CSR metadata bytes, input load/preprocessing cost (disclosed), mapped resources, Fmax and power-estimation category when feasible.
- Derived cycle speedup = `cycles_dense / cycles_sparse` ONLY using like-for-like start/stop definitions, not `N^3/(N*nnz)` unless experimentally equal.

## Evidence policy
- Each plot has: title, metric definition, units, tool name/version, target, seed(s), workload parameters, source CSV filename and limitations.
- Save raw logs in `results/logs/`, summary CSV in `results/`, charts in `results/figures/`.
- A negative or null result is welcome if reproducible. Never replace measured outcomes with invented positive results.
