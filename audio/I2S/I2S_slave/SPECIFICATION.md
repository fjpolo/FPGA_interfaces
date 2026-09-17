# I2S Slave Specification Compliance & Architecture

This document details the architecture of the `I2S_slave` core and its strict compliance with the official **Philips / NXP I²S Bus Specification (UM11732 / Rev. 3.0)**.

---

## 1. Specification Compliance Matrix

| Requirement | Official Specification (UM11732) | `I2S_slave.v` Implementation | Status |
| :--- | :--- | :--- | :--- |
| **Bus Lines** *(Sec. 3)* | 3 lines: Continuous Serial Clock (`SCK`), Word Select (`WS`), Serial Data (`SD`). | Connects to `i_sck`, `i_ws`, `i_sd` (RX), and `o_sd` (TX). | **Compliant** |
| **Target / Slave Role** *(Sec. 2)* | Derives synchronous timing from external `SCK` and `WS`. | Employs multi-stage synchronizers with edge detectors (`sck_rise`, `sck_fall`, `ws_edge`). | **Compliant** |
| **Channel Polarity** *(Sec. 3.2)* | `WS = 0` is Channel 1 (Left),<br>`WS = 1` is Channel 2 (Right). | `cur_channel <= ws_sync[1];` (0 = Left, 1 = Right). | **Compliant** |
| **Bit Order** *(Sec. 3.1)* | Transmitted **MSB first** in two's complement. | Shift registers transmit and receive MSB (`DATA_WIDTH-1`) down to LSB (`0`). | **Compliant** |
| **Trailing Slot Bits** *(Sec. 3.1)* | If slot length > word length, remaining bits are padded with `0` (TX) or ignored (RX). | `o_sd <= 1'b0` when `tx_bit_cnt >= DATA_WIDTH`; RX ignores extra rising edges until next `ws_edge`. | **Compliant** |
| **Clock Edge Conventions** *(Sec. 3.1 & 3.2)* | Data is latched into the receiver on **SCK rising edge** (leading edge) and driven on **SCK falling edge** (trailing edge). | `sck_rise` drives RX sampling;<br>`sck_fall` drives TX output transitions. | **Compliant** |
| **The 1-Clock Delay Rule** *(Sec. 3.1 & 3.2)* | *"The transmitter always sends the MSB of the next word one clock period after the WS changes."* | **RX**: Skips 1st SCK rising edge after `ws_edge`, samples MSB on 2nd edge.<br>**TX**: Outputs MSB on the very first SCK falling edge after `ws_edge`. | **Compliant** |

---

## 2. Timing Diagram

```text
WS (from Master)   ───────\___________________________ (Left Channel, WS=0)
SCK (from Master)  ___/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
                   Edge:  0   1   2   3   ...
                          |
                          └── Delay Slot (1 SCK Period)
                                  |
SD Out (Slave TX)  ───────[ 0 ]───[  MSB  ]───[ MSB-1 ]─── (Driven on SCK falling edge)
SD In  (Slave RX)  ───────[ x ]───[  MSB  ]───[ MSB-1 ]─── (Sampled on SCK rising edge)
```

---

## 3. Signal Interface

### Clock & Reset
- `i_clk`: FPGA system master clock (recommended $\ge 4 \times f_{SCK}$).
- `i_reset_n`: Active-low asynchronous/synchronous reset.

### External I2S Bus (Connected to I2S Master)
- `i_sck`: Serial bit clock input.
- `i_ws`: Word select input (`0` = Left, `1` = Right).
- `i_sd`: Serial data input (Slave Receiver).
- `o_sd`: Serial data output (Slave Transmitter).

### Parallel User Interface
- **Slave Receiver**:
  - `o_rx_data_l [DATA_WIDTH-1:0]`: Left channel audio sample.
  - `o_rx_data_r [DATA_WIDTH-1:0]`: Right channel audio sample.
  - `o_rx_valid`: 1-cycle strobe indicating complete stereo sample reception.
- **Slave Transmitter**:
  - `i_tx_data_l [DATA_WIDTH-1:0]`: Left channel audio sample to transmit.
  - `i_tx_data_r [DATA_WIDTH-1:0]`: Right channel audio sample to transmit.
  - `i_tx_valid`: Sample valid strobe from host logic.
  - `o_tx_ready`: 1-cycle handshake pulse requesting next sample pair.
- **Status**:
  - `o_channel_sync`: Pulsed on every `WS` transition.

---

## 4. Reference Documents
- **Official Specification**: NXP Semiconductors User Manual **UM11732** (*I2S bus specification*, Rev. 3.0).
- **Local Spec Copies**:
  - [`audio/I2S/UM11732.pdf`](../UM11732.pdf)
  - [`audio/I2S/I2S_bus_specification.pdf`](../I2S_bus_specification.pdf)
