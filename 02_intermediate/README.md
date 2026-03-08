# 02 - Intermediate: Burst Transfers & Outstanding Transactions

## Goal
Validate intermediate AXI protocol understanding by performing burst transactions (INCR and WRAP) to maximize throughput. AXI maximizes throughput via Burst Transactions, where the master issues a single start address, and the slave is responsible for calculating subsequent addresses for every "beat" in the burst. This reduces address bus congestion and allows for overlapping bursts.

## Block Design Topology & Waveform Analysis
- **Master VIP**: Generates INCR and WRAP burst commands.
- **Passthrough VIP**: Monitors/passes signals.
- **Slave Memory VIP**: Acts as a memory-backed target for burst beats.

![waveform_2.png](https://iili.io/qTdznat.png)

### AXI Burst Types 
According to the AXI protocol specification:

| Type | Addressing Logic | Architect's Use Case |
| --- | --- | --- |
| **FIXED** | Address remains constant. | High-speed FIFO access. (Limited to 16 beats in AXI4) |
| **INCR** | Address increments by size. | RAM/Flash transfers. (AXI4 extends this to 256 beats). |
| **WRAP** | Increments, then wraps at boundary. | Cache Line fills. Supports "Critical Word First" delivery. (Limited to 16 beats in AXI4) |

### Waveform Analysis Overview
The testbench (`tb_axi4_lite_intermediate.sv`) generates operations to validate the burst behaviors:

1. **INCR Burst Write**:
   - Master issues a single start `base_addr` of `0x0000_1000`.
   - `len` is set to 3, resulting in 4 beats.
   - `size` is set to 4 bytes (`XIL_AXI_SIZE_4BYTE`).
   - Addresses increment by 4 per beat: `0x0000_1000`, `0x0000_1004`, `0x0000_1008`, `0x0000_100C`.
   - Data (`beat0` to `beat3`) written respectively: `0xAAAA_0001`, `0xBBBB_0002`, `0xCCCC_0003`, `0xDDDD_0004`.

2. **WRAP Burst Write**:
   - Master creates an INCR transaction and converts it into a WRAP transaction using `convert_incr_to_wrap()`.
   - The test bench computes a `wrap_boundary` calculated based on `base_addr` and the total transfer size (4 beats × 4 bytes = 16 bytes). 
   - The burst starts at an offset and address increments until hitting the wrap boundary, wrapping around to the lowest address of the boundary.

### Simulation Log
The following output from the testbench execution demonstrates the address increment and wrap behaviors:

```text
====== incr burst write ======
[60 ns] Beat[0] new_addr=0x00001000 data_beat=0xaaaa0001 | base_addr=0x00001000
[65 ns] Beat[1] new_addr=0x00001004 data_beat=0xbbbb0002 | base_addr=0x00001000
[75 ns] Beat[2] new_addr=0x00001008 data_beat=0xcccc0003 | base_addr=0x00001000
[85 ns] Beat[3] new_addr=0x0000100c data_beat=0xdddd0004 | base_addr=0x00001000
[95 ns] INCR write done
====== wrap burst write ======
[155 ns] Converted INCR to WRAP burst (wrap_offset=8)
[165 ns] Boundary = 0x00001010  (0x00001000 + 4 beats x 4 bytes)
[175 ns] WRAP write done
===============================
```

#### INCR Burst Explained
The reset de-asserts at **40 ns** (`aresetn` goes high after two 20 ns phases), so the first beat appears at **60 ns**.

| Time | Beat | Address | Data | How the address is calculated |
| --- | --- | --- | --- | --- |
| 60 ns | 0 | `0x0000_1000` | `0xAAAA_0001` | `base_addr + 0 × 4 = 0x1000` (start address) |
| 65 ns | 1 | `0x0000_1004` | `0xBBBB_0002` | `base_addr + 1 × 4 = 0x1004` |
| 75 ns | 2 | `0x0000_1008` | `0xCCCC_0003` | `base_addr + 2 × 4 = 0x1008` |
| 85 ns | 3 | `0x0000_100C` | `0xDDDD_0004` | `base_addr + 3 × 4 = 0x100C` |

- **Stride** = `2^size` = `2^2` = **4 bytes**, so each beat's address is the previous address **+ 4**.
- The address increments linearly from `0x1000` → `0x1004` → `0x1008` → `0x100C`, confirming correct INCR behavior.
- `INCR write done` at **95 ns** means the master's write driver successfully sent all 4 data beats and the slave acknowledged the burst with a `BRESP = OKAY`.

#### WRAP Burst Explained
| Time | Event | Detail |
| --- | --- | --- |
| 155 ns | `Converted INCR to WRAP` | The testbench builds an INCR transaction and then calls `convert_incr_to_wrap(11'd8)`. The `wrap_offset = 8` means the WRAP burst's effective start address is shifted by 8 bytes from `base_addr`, i.e. it begins transferring at `0x0000_1008`. |
| 165 ns | `Boundary = 0x0000_1010` | The wrap boundary is `base_addr + (len+1) × size_bytes` = `0x1000 + 4 × 4` = `0x1010`. This is the upper address limit; once the incrementing address reaches `0x1010`, it wraps back to `0x1000`. |
| 175 ns | `WRAP write done` | All 4 beats have been sent and acknowledged. |

The expected beat address sequence for this WRAP burst (starting at offset 8 from `base_addr`):

| Beat | Address | Reasoning |
| --- | --- | --- |
| 0 | `0x0000_1008` | Start address = `base_addr + wrap_offset` |
| 1 | `0x0000_100C` | Increment by 4 |
| 2 | `0x0000_1000` | Next would be `0x1010`, but that equals the boundary → **wraps** back to `0x1000` |
| 3 | `0x0000_1004` | Continues incrementing from the wrapped address |

This is the classic **"Critical Word First"** pattern: the cache controller requests the word it actually needs (`0x1008`) first, so the CPU can resume execution immediately while the remaining words (`0x100C`, `0x1000`, `0x1004`) fill in the rest of the cache line in the background.

## Key Signals
* **`aclk`**: Defined as a **100MHz** clock.
* **`aresetn`**: An **active-low** reset, pulled low for 20ns before the transactions begin.
* `base_addr`: Starting address (`32'h0000_1000`) for the bursts.
* `len`: Number of beats minus 1 (len=3 means 4 beats).
* `id`: Transaction ID (`0`) for the burst request.

### Write Transaction Signals (Master → Slave)

| Signal Group | Key Signals | Description from Code |
| --- | --- | --- |
| **Write Address** | `AWADDR`, `AWLEN`, `AWSIZE`, `AWBURST` | Carries the initial address, total burst length, size per beat, and burst type (`01` for INCR, `10` for WRAP). |
| **Write Data** | `WDATA`, `WSTRB`, `WLAST` | Drives the burst data patterns. `WLAST` is asserted on the 4th beat to mark the end of the burst. |
| **Write Response** | `BRESP`, `BVALID` | Slave signals the completion of the entire burst to the master. |

### Pass-through & Monitoring Signals
- `monitor_transaction()` watches the AW, W, and B channels on the `axi_vip_passthrough`.
- `check_handshake()` validates protocol compliance by tracking the `VALID` and `READY` channels to ensure the address, data, and response components of the burst are successful.
