# 01 - Basic: Single Write/Read (AXI4-Lite)

## Goal
Validate basic AXI4-Lite protocol understanding by performing single write and read transactions to a memory-backed slave.

## Block Design Topology & Waveform Analysis
- **Master VIP**: Generates READ/WRITE commands.
- **Passthrough VIP**: Monitors/passes signals.
- **Slave Memory VIP**: Acts as a memory-backed target (retains written data).

![waveform](https://iili.io/qn9HgqP.png)

The screenshot confirms that AXI4-Lite verification environment is functioning correctly, with the simulation successfully validating the data path through the master, passthrough, and slave IPs.

`WRITE_1` to `0x44a00000` with data `0xdeadbeef` (Response: 0/OKAY).

`WRITE_2` to `0x44a00004` with data `0xabcdef01` (Response: 0/OKAY).

`READ_1` from `0x44a00000` returns `0xdeadbeef`.

`READ_2` from `0x44a00004` returns `0xabcdef01`.

A logic confirms that `data_rd == data_wr` for both transactions, resulting in the **ALL TESTS PASSED** message.

## Key Signals
The testbench uses the following signals for waveform observation:
* **`aclk`**: Defined as a **100MHz** clock (`always #5ns aclk <= ~aclk;`). Every AXI signal transition occurs on the rising edge of this clock.
* **`aresetn`**: An **active-low** reset. The testbench ensures a clean state by pulling this low for 20ns (`#20`) before the transactions begin.
- `addr`, `addr2`: Target AXI addresses.
- `data_wr`, `data_wr2`: Data patterns to write.
- `data_rd`, `data_rd2`: Data read back from the slave.
- `resp`: AXI response status (OKAY/SLVERR/etc).


### Write Transaction Signals (Master → Slave)

When the code executes `mst_agent.AXI4LITE_WRITE_BURST(...)`, the following signal groups are toggled across the `axi_vip_master` and `axi_vip_passthrough` interfaces:

| Signal Group | Key Signals | Description from Code |
| --- | --- | --- |
| **Write Address** | `AWADDR`, `AWPROT`, `AWVALID` | Driven by `addr` (`32'h44A0_0000`) and `prot` (`0`). |
| **Write Data** | `WDATA`, `WSTRB`, `WVALID` | Driven by `data_wr` (`32'hDEADBEEF`). `WSTRB` is automatically set to `4'hF` for a full 32-bit word. |
| **Write Response** | `BREADY`, `BVALID`, `BRESP` | The Master waits for the Slave to pull `BVALID` high. The result is stored in the `resp` variable. |

### Read Transaction Signals (Slave → Master)

When the code executes `mst_agent.AXI4LITE_READ_BURST(...)`, it triggers the Read Address and Read Data channels:

| Signal Group | Key Signals | Description from Code |
| --- | --- | --- |
| **Read Address** | `ARADDR`, `ARPROT`, `ARVALID` | Master drives the address to the bus. |
| **Read Data** | `RDATA`, `RRESP`, `RVALID`, `RREADY` | Slave places the stored data (`32'hDEADBEEF`) onto `RDATA`. The testbench captures this into `data_rd`. |

### Pass-through & Monitoring Signals

The **`axi_vip_passthrough`** is the most critical part of block design. Even though it is in "pass-through" mode, it actively monitors these signals:

* **Protocol Compliance:** It checks that `VALID` and `READY` handshakes follow the AXI spec (e.g., `VALID` must not drop until `READY` is asserted).
* **Latency:** It observes the time delta between the Master's request and the Slave's response.
* **Visibility:** set `verbosity(400)`, the VIP internal monitor prints every signal transition of the `AW`, `W`, `B`, `AR`, and `R` channels to the simulation console.

### Verification Logic (Self-Check)

The final stage of the code performs a comparison between the software variables:

```systemverilog
if ((data_rd == data_wr) && (data_rd2 == data_wr2))
```

This ensures that the signal integrity was maintained through the **Master → Pass-through → Slave** path. If a single bit in the `WDATA` or `RDATA` signals had been corrupted by the passthrough or the slave memory, this check would fail.
