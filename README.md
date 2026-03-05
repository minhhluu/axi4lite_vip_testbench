# AXI VIP Testbench Collection

A collection of Xilinx AXI Verification IP (VIP) testbenches for validating AXI4-Lite and AXI4 protocols. This project follows a testbench environment approach from basic protocol understanding to advanced multi-master arbitration and error handling.

## The AMBA Specification Overview

The AMBA specification defines 3 AXI4 protocols:

* **AXI4**: A high-performance memory-mapped data and address interface. Capable of Burst access to memory-mapped devices.
* **AXI4-Lite**: A subset of AXI, lacking burst access capability. Has a simpler interface than the full AXI4 interface.
* **AXI4-Stream**: A fast unidirectional protocol for transferring data from master to slave.

[![architecture_writes](https://iili.io/qCZ8uUl.md.png)](https://freeimage.host/i/qCZ8uUl)
[![architecture_reads](https://iili.io/qCZ8Iff.md.png)](https://freeimage.host/i/qCZ8Iff)


## Block Diagram Analysis

[![qCteMa2.md.png](https://iili.io/qCteMa2.png)](https://freeimage.host/i/qCteMa2)

The entire diagram is driven by a single global clock (`aclk`) and an active-low reset (`aresetn`), ensuring all components remain synchronous.

The hardware data path consists of three primary stages:

* **`axi_vip_master` (The Driver):** Acts as the system initiator (CPU/DMA), responsible for generating all read and write transactions.
* **`axi_vip_passthrough` (The Monitor/Bridge):** Acts as an interconnect node or Firewall. It sits in the middle, allowing the Master's `M_AXI` interface to connect to its `S_AXI` port, then passes those signals through its own `M_AXI` port to the next stage while monitoring traffic for protocol violations.
* **`axi_vip_slave` (The Memory):** Acts as the final endpoint (SRAM or Register space). It receives requests on its `S_AXI` interface and utilizes an internal memory model to store or retrieve data.

## 🏗️ Project structure

### [01 - Basic: Single Write/Read (AXI4-Lite)](https://github.com/minhhluu/axi4lite_vip_testbench/tree/master/01_basic)

**Focus:** Single Write/Read validation and the atomic unit of AXI communication.

#### The Five-Channel Split

The Advanced eXtensible Interface (AXI) protocol decouples address and data phases into five distinct paths, enabling full-duplex operation.

| Channel Name | Mnemonic | Primary Function | Direction |
| --- | --- | --- | --- |
| Write Address | AW | Issues address, burst type, and control for writes. | Master → Slave |
| Write Data | W | Transfers data beats; includes byte strobes for precision. | Master → Slave |
| Write Response | B | Slave confirms write completion and status. | Slave → Master |
| Read Address | AR | Issues address, burst type, and control for reads. | Master → Slave |
| Read Data | R | Transfers data and status back to the master. | Slave → Master |


#### The Handshake Mechanism

A transfer only occurs when both **VALID** and **READY** are asserted on a rising clock edge.

* **Source (VALID):** Must not be dependent on the destination’s READY. Once HIGH, it must remain HIGH until the handshake completes.
* **Destination (READY):** Can wait for VALID before asserting.

**Handshake Scenarios:**

* **VALID before READY:** Source waits for destination.
* **READY before VALID:** Destination is waiting for data (Optimal performance).
* **Simultaneous:** Instantaneous transfer; maximum efficiency.

---

### [02 - Intermediate: Burst Transfers & Outstanding Transactions](https://github.com/minhhluu/axi4lite_vip_testbench/tree/master/02_intermediate)

**Focus:** Back-to-back transactions, address sweeps, and maximizing bandwidth.

#### AXI Burst Types

The master issues a start address, and the slave calculates subsequent addresses for every "beat."

| Type | Addressing Logic | Architect's Use Case |
| --- | --- | --- |
| **FIXED** | Address remains constant. | High-speed FIFO access. |
| **INCR** | Address increments by size. | RAM/Flash transfers. (AXI4: up to 256 beats). |
| **WRAP** | Increments, then wraps at boundary. | Cache Line fills (Critical Word First). |

#### IDs and Out-of-Order (OoO) Completion

* **Multiple Outstanding Transactions:** Masters issue addresses without waiting for data.
* **OoO Completion:** Fast slaves (SRAM) can return data before slow slaves (DDR) using unique IDs, preventing system stalls.
* **LAST Signal:** `WLAST` and `RLAST` mark the end of a burst.

---

### [03 - Advanced: Topologies & Error Handling](https://github.com/minhhluu/axi4lite_vip_testbench/tree/master03_advanced)

**Focus:** Multi-master arbitration, address decoding, and system-level error handling.

#### Coordination and Response

* **Multi-Region Decoding:** Uses `ARREGION`/`AWREGION` to offload decoding from slave hardware.
* **ID Appending:** Interconnects append master port prefixes to IDs to ensure uniqueness at the slave interface.

**Response Signaling:**
| Response | Meaning | Architect's Warning |
| :--- | :--- | :--- |
| **OKAY** | Success | Standard response; also used for failed exclusive access. |
| **EXOKAY** | Exclusive Success | Atomic operation (semaphore) succeeded. |
| **SLVERR** | Slave Error | Slave reached, but operation failed (e.g., Read-Only write). |
| **DECERR** | Decode Error | Accessing an unmapped address (Interconnect-generated). |

---

## 🛠️ Environment & Setup

* **Tool**: Vivado 2025.2
* **Device**: Zynq-7020 (xc7z020clg400-1)
* **Library**: Xilinx AXI VIP 1.1

### Folder Structure
```
axi4lite_vip_testbench
│
├── 01_basic
│ ├── rtl
│ └── tcl
│
├── 02_intermediate
│ ├── rtl
│ └── tcl
│
├── 03_advanced
│ ├── rtl
│ └── tcl
│
└── README.md
```

* `01_basic/`: Single write/read AXI4-Lite validation.
axi4lite_vip_testbench
* `02_intermediate/`: Burst and complexity validation.
* `03_advanced/`: Complex topology and error validation.

### Getting Started

1. Open **Vivado 2025.2**.
2. Create or open your project targeting the specific chip.
3. Add the RTL files from the desired level's `rtl/` folder.
4. Run the simulation using the provided TCL scripts in the `tcl/` folder.
