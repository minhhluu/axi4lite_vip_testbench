# 01 - Basic: Single Write/Read (AXI4-Lite)

## Goal
Validate basic AXI4-Lite protocol understanding by performing single write and read transactions to a memory-backed slave.

## Block Design Topology
- **Master VIP**: Generates READ/WRITE commands.
- **Passthrough VIP**: Monitors/passes signals.
- **Slave Memory VIP**: Acts as a memory-backed target (retains written data).

## Key Signals
The testbench uses the following signals for waveform observation:
- `addr`, `addr2`: Target AXI addresses.
- `data_wr`, `data_wr2`: Data patterns to write.
- `data_rd`, `data_rd2`: Data read back from the slave.
- `resp`: AXI response status (OKAY/SLVERR/etc).

## How to Run
1. Open your Vivado project.
2. In the Tcl Console, source the run script:
   ```tcl
   source tcl/run_sim.tcl
   ```
3. Check the Tcl Console for the **PASS/FAIL** report.
