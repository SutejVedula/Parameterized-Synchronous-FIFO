
# Parameterized Synchronous FIFO

A configurable synchronous First-In, First-Out (FIFO) buffer implemented in SystemVerilog and developed using Xilinx Vivado 2026.1.

The design supports configurable data width and storage depth, status monitoring, pointer wraparound, and simultaneous read/write operations.

## Project Overview

A FIFO stores data in arrival order and returns it in the same order. This design uses a single clock for both read and write operations.

### Features

- Parameterized data width and FIFO depth
- Synchronous reset
- Independent read and write enables
- Full and empty status flags
- Occupancy counter
- Read and write pointer wraparound
- Protection against writes when full and reads when empty
- Simultaneous read/write support, including when full
- SystemVerilog assertions for design invariants

## Architecture

The FIFO consists of:

- **Storage memory:** Holds the queued data.
- **Write pointer:** Identifies the next storage location to write.
- **Read pointer:** Identifies the next storage location to read.
- **Occupancy counter:** Tracks the number of stored entries.
- **Status logic:** Generates `full` and `empty`.
- **Control logic:** Determines whether read and write requests are accepted.

## Default Parameters

| Parameter | Default value | Description |
|---|---:|---|
| `DATA_WIDTH` | 8 | Bits per data entry |
| `FIFO_DEPTH` | 16 | Number of entries |
| `PTR_WIDTH` | 4 | Pointer width for depth 16 |
| `COUNT_WIDTH` | 5 | Width required to represent counts from 0 to 16 |

The pointer and count widths are derived from the configured FIFO depth. For non-power-of-two depths, the implementation should be validated for the intended parameter values.

## Interface

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | FIFO clock |
| `reset` | Input | Synchronous active-high reset |
| `wr_en` | Input | Write request |
| `rd_en` | Input | Read request |
| `data_in` | Input | Input data |
| `data_out` | Output | Most recently read data |
| `full` | Output | Indicates the FIFO is full |
| `empty` | Output | Indicates the FIFO is empty |
| `count` | Output | Current occupancy |

## Repository Structure

```text
Parameterized-Synchronous-FIFO/
├── rtl/
│   └── fifo.sv
├── tb/
│   ├── fifo_tb.sv
│   └── fifo_param_tb.sv
├── constraints/
│   └── fifo_constraints.xdc
├── docs/
│   ├── README.md
│   ├── fifo_basic_read_write_waveform.png
│   ├── fifo_verification_summary.png
│   ├── fifo_utilization_synth.png
│   ├── fifo_utilization_impl.png
│   └── fifo_timing_summary.png
├── LICENSE
└── README.md
```

## Verification

Two self-checking testbenches are included.

### Default configuration

- Data width: 8 bits
- FIFO depth: 16 entries
- Reported testbench result: 261 passed, 0 failed

### Alternate configuration

- Data width: 16 bits
- FIFO depth: 8 entries
- Reported testbench result: 149 passed, 0 failed

The tests cover reset, data ordering, underflow, overflow, capacity, pointer wraparound, occupancy, and simultaneous read/write behavior.

**Verification note:** Assertion errors were observed during startup in the alternate simulation. The reported functional testbench pass count does not establish that all assertions pass. Further assertion-clean verification remains outstanding.

## FPGA Implementation

Target device selected in Vivado:

`xc7a35tcpg236-1` (Artix-7)

### Post-implementation resource utilization

| Resource | Used |
|---|---:|
| Slice LUTs | 22 |
| Slice registers | 25 |
| LUTs used as distributed RAM | 6 |
| Block RAM tiles | 0 |
| DSPs | 0 |

These values are from the post-implementation utilization report.

### Timing

The routed timing summary reports:

- Clock period constraint: 10 ns
- Clock frequency: 100 MHz
- Worst negative slack (WNS): 6.118 ns
- Total negative slack (TNS): 0 ns
- Worst hold slack (WHS): 0.036 ns
- Total hold slack (THS): 0 ns

The report states that user-specified timing constraints are met. However, input and output delay constraints are missing, so these figures do not constitute complete interface-level timing signoff.

No physical FPGA board validation is claimed.

## Tools Used

- SystemVerilog
- Xilinx Vivado 2026.1
- Behavioral simulation
- FPGA synthesis and implementation
- Timing and utilization reports

## Future Improvements

- Resolve startup assertion behavior and obtain a clean assertion-enabled run.
- Add input and output timing constraints appropriate to a target board.
- Verify additional parameter combinations, including non-power-of-two depths.
- Add randomized verification and functional coverage.
- Validate on physical FPGA hardware when available.

## License

Distributed under the MIT License. See [LICENSE](LICENSE).
