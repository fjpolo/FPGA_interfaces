# I2S_slave Module

Parameterized digital audio transceiver core implementing the **Philips / NXP I²S Bus Specification (UM11732)** in Target (Slave) mode.

---

## Features
- **Full-Duplex Operation**: Independent Slave Receiver (RX) and Slave Transmitter (TX).
- **Specification Compliant**: Strictly follows Philips I2S timing with the standard 1-SCK cycle delay between Word Select (`i_ws`) transitions and MSB transmission/reception.
- **Robust Synchronization**: Multi-stage flip-flop synchronizers and glitch-free edge detection on external `i_sck` and `i_ws` clock inputs from the master.
- **Parameterized Word Width**: Configurable `DATA_WIDTH` (16, 24, 32 bits, default 24).
- **Clean Linting**: Fully verified with Verilator (`--lint-only --Wall --cc`) with zero warnings.

For detailed specification compliance analysis and timing diagrams, see [SPECIFICATION.md](SPECIFICATION.md).

---

## Port Definitions

```verilog
module I2S_slave #(
    parameter integer DATA_WIDTH = 24  // Audio sample bit depth (16, 24, 32)
) (
    // Clock and active-low reset
    input  wire                  i_clk,
    input  wire                  i_reset_n,

    // External I2S bus from master
    input  wire                  i_sck,          // Continuous serial bit clock
    input  wire                  i_ws,           // Word select (0 = Left, 1 = Right)
    input  wire                  i_sd,           // Serial data in (Slave RX)
    output reg                   o_sd,           // Serial data out (Slave TX)

    // Parallel receiver interface (Slave RX)
    output reg  [DATA_WIDTH-1:0] o_rx_data_l,
    output reg  [DATA_WIDTH-1:0] o_rx_data_r,
    output reg                   o_rx_valid,

    // Parallel transmitter interface (Slave TX)
    input  wire [DATA_WIDTH-1:0] i_tx_data_l,
    input  wire [DATA_WIDTH-1:0] i_tx_data_r,
    input  wire                  i_tx_valid,
    output reg                   o_tx_ready,

    // Status sync indicator
    output reg                   o_channel_sync  // Pulsed on WS transitions
);
```

---

## FPGA Debugging with Manta Logic Analyzer

This module includes built-in configuration for the [Manta FPGA Logic Analyzer](https://github.com/fischermoseley/manta):
- `manta.yaml`: Logic analyzer core definition.
- `python/manta_test.py`: Host script for waveform capture over UART.