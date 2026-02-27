# AXI VIP Testbench Collection

A collection of Xilinx AXI Verification IP (VIP) testbenches for validating AXI4-Lite and AXI4 protocols. This project follows a tiered learning approach from basic protocol understanding to advanced multi-master arbitration and error handling.

## Roadmap & Status

| Level | Topic | Description | Status |
| :--- | :--- | :--- | :--- |
| **01** | **Basic** | Single Write/Read (AXI4-Lite) | ✅ Completed |
| **02** | **Intermediate** | Burst transfers, Multiple outstanding | 🚧 Planned |
| **03** | **Advanced** | Multi-master, Address decode, Errors | 🚧 Planned |

## Environment
- **Tool**: Vivado 2025.2
- **Device**: Zynq-7020 (xc7z020clg400-1)
- **Library**: Xilinx AXI VIP 1.1

## Folder Structure
- `01_basic/`: Single write/read AXI4-Lite validation.
- `02_intermediate/`: Burst and complexity validation (Coming Soon).
- `03_advanced/`: Complex topology and error validation (Coming Soon).

## Getting Started
1. Open Vivado 2025.2.
2. Create or open your project targeting the **xc7z020clg400-1**.
3. Add the RTL files from the desired level's `rtl/` folder to your simulation fileset.
4. Run the simulation using the provided TCL scripts in the `tcl/` folder.
