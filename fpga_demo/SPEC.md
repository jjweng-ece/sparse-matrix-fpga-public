# Gate 5A / 5B contract

Scope: executable board-independent demo, actual RTL simulation, and reference
synthesis. Board release/programming is a separate gate. Gate4 commit 09fddda
is immutable. Reuse its three RTL files without editing them.

Board evidence: user confirms Rev C / ES. Previous self-attention QSF and local
SoCKit v1.0.3 System CD golden top agree on 5CSXFC6D6F31C8ES. Check the matching
RevC schematic/manual before publishing any board constraint. Physical complete
chip marking, current clock configuration and USB connection remain unobserved.

Logical top: `demo_top(clk,reset_n_async,start_n_async,sw_async[3:0],
debug_addr[3:0],led[3:0],busy,done,pass,fail,done_pulse,selected_mode[1:0],
dense_cycles[31:0],csr_cycles[31:0],dense_macs[15:0],csr_macs[15:0],
dense_loads[15:0],csr_loads[15:0],total_cycles[31:0],dense_data[31:0],csr_data[31:0])`.
debug_addr/read outputs are observability ports, not physical board pins.
`demo_sockit_top(OSC_50_B5B,KEY[1:0],SW[3:0],LED[3:0])` ties debug read address
to zero internally. Its LED outputs are checked against demo_top each normal
simulation cycle; it has no pin assignments or released board constraints.

Single clock; async reset assertion / two-flop synchronous release. Gate4 cores
still receive synchronous active-low reset. Button press is logical active-low,
two-flop synchronized, stable-time debounced (supported parameter>=4; default 1,000,000 samples at
provisional 50MHz =20ms). Require a qualified release before arming a press.
One pulse per press; held start never repeats. Switches use two synchronizer
stages; mode sw[1:0] latches only at accepted idle start. User must settle switches
before pressing start; synchronizers alone do not guarantee atomic multi-bit CDC.
sw[3:2] selects a display page independently of computation.

Modes: 0 all-zero A; 1 identity A; 2 irregular sparse A including one empty row
and negative values; 3 fully dense signed A. Same dense B for both engines.
ROM generator uses the independent Gate4 Python model, canonical CSR encoder
and full expected C. No seed extension used: C=A*B. ROM values and Python expected
results are archived; TB checks every output independently of on-chip comparator.

FSM IDLE -> CLEAR -> LOAD -> START -> WAIT -> COMPARE -> FINISH -> IDLE.
CLEAR resets both engines for one cycle on every job. LOAD advances independent
indices only on valid && ready, so both loaders run concurrently and finish at
different times. Dense writes 32 words; CSR writes 22+2nnz words. START is one
cycle. WAIT latches each engine's done/counters independently; no requirement
that both done pulses coincide. Watchdog 1024 cycles produces FAIL if an engine
does not complete. COMPARE reads all16 results and compares Dense vs CSR vs ROM
Golden. FINISH publishes sticky done/pass/fail and one done_pulse. Busy requests
are ignored. New start clears previous status; Reset aborts and clears status.

Counters: core cycles/MACs are unchanged Gate4 counters, captured at each done;
loader counters count accepted 32-bit writes; total_cycles counts controller
cycles from accepted start edge excluded to published done edge included. It
includes clear, parallel load, launch, wait and 16-word compare. It excludes
button filtering, offline CSR compression/ROM generation and human I/O delay.
No counter is a physical power/activity measurement.

LED page0: bit0 busy, bit1 sticky done, bit2 PASS, bit3 FAIL. Page1 dense cycles,
page2 CSR cycles, page3 concatenated CSR/Dense MAC counts, shown as a rotating
32-bit hexadecimal nibble (one nibble/second at CLOCK_HZ). Phase resets when
page changes so a viewer starts at the least-significant nibble. All counter
bits feed the display; they must not be claimed retained on a board until its
actual mapped netlist is checked. Status page is the recording default.

Simulation: reduced debounce/display periods only; check all4 modes/repeats,
button bounce and held/reset-held press, busy mode/start interference, independent
loader indices/word counts, all16 outputs vs Python, counters from independently
observed engine start/done edges, reset in load/compute/compare, LED pages and a
simulation-only comparator fault. Preserve every failed and successful run.
No physical board PASS, final QSF/SDC, SOF or programming until board release.
