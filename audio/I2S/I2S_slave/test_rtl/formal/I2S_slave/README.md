# Formal Verification Properties: `I2S_slave`

This document details the formal specification, property taxonomy, and SystemVerilog Assertions (SVA) for the **`I2S_slave`** core ([I2S_slave.v](file:///c:/Workspace/FPGA/FPGA_interfaces/audio/I2S/I2S_slave/rtl/I2S_slave.v)). 

Formal verification is executed using **SymbiYosys (`sby`)** with SMT solvers (e.g. Yices2, Z3, Boolector) to mathematically prove that the module adheres strictly to the **Philips I2S Bus Specification** under all valid environmental inputs, and that internal state registers cannot corrupt audio data or deadlock.

---

## 1. Verification Strategy & Objectives

The formal suite targets three primary goals:
1. **Bounded Model Checking (BMC)**: Prove absence of assertion violations, counter overflows, and protocol errors within $N$ cycles from reset.
2. **Temporal Induction (`prove`)**: Mathematically prove unbounded invariants and safety properties for all time ($t \to \infty$).
3. **Cover Reachability (`cover`)**: Prove that environmental constraints are not over-constraining the model and that real audio transactions (stereo RX, TX handshakes, continuous full-duplex streaming) are fully reachable.

### Supported Build Configurations
The properties honor the conditional compilation macros of `I2S_slave.v`:
- **Full-Duplex** (default): Both RX and TX properties active.
- **`I2S_SLAVE_RX_ONLY`**: TX logic pruned; verifies static tie-offs on `o_sd = 0`, `o_tx_ready = 0`.
- **`I2S_SLAVE_TX_ONLY`**: RX logic pruned; verifies static tie-offs on `o_rx_data_l = 0`, `o_rx_data_r = 0`, `o_rx_valid = 0`.

---

## 2. Property Taxonomy

```
                          ┌────────────────────────┐
                          │   Formal Properties    │
                          └───────────┬────────────┘
                                      │
       ┌──────────────┬───────────────┼───────────────┬──────────────┐
       │              │               │               │              │
┌──────┴──────┐┌──────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐┌──────┴──────┐
│ Environment ││ Reset State │ │   Control   │ │ Data Path & ││ Reachability│
│ Assumptions ││ Invariants  │ │  Protocols  │ │ Handshakes  ││   Covers    │
│  (assume)   ││  (assert)   │ │  (assert)   │ │  (assert)   ││   (cover)   │
└─────────────┘└─────────────┘ └─────────────┘ └─────────────┘└─────────────┘
```

### Summary Table

| Category | Target Signals | Mechanism | Failure Mode Prevented |
| :--- | :--- | :--- | :--- |
| **Environmental** | `i_sck`, `i_ws`, `i_tx_valid` | `assume` | False counterexamples caused by sub-Nyquist clock jitter or illegal asynchronous bus transitions. |
| **Reset State** | All registers & outputs | `assert` | Uninitialized outputs, `X`-propagation, or spurious valid strobes on reset deassertion. |
| **Strobe Purity** | `o_rx_valid`, `o_channel_sync` | `assert` | Multi-cycle strobe hangs or glitch pulses violating downstream synchronous processing. |
| **Counter Bounds** | `rx_bit_cnt`, `tx_bit_cnt` | `assert` | Shift counter overflow, infinite loops, or improper bit-slot termination. |
| **Philips Timing** | `o_sd`, `rx_shift_reg` | `assert` | Violating the 1-SCK delay rule or serializing LSB-first instead of MSB-first. |
| **Buffering** | `tx_r_active`, `tx_l_reg` | `assert` | Mid-transmission overwrites causing channel swapping or phase inversion between L and R. |
| **Reachability** | `o_rx_valid`, `o_tx_ready` | `cover` | Over-constrained environment assumptions locking up the core into deadlocks. |

---

## 3. Environment Assumptions (`assume`)

Formal solvers explore *every possible* input state transition per clock cycle. The assumptions below constrain the solver strictly to legal physical bus and host behavior.

### A. Reset Sequence
The reset is assumed active on the initial step and released cleanly:
```systemverilog
initial assume (!i_reset_n);
```

### B. SCK Oversampling & Pulse Width Stability
The system clock `i_clk` must oversample the serial bit clock `i_sck`. To allow reliable edge detection through the 3-stage synchronizer (`sck_sync`), `i_sck` must remain high for $\ge 2$ `i_clk` cycles and low for $\ge 2$ `i_clk` cycles:
```systemverilog
reg [3:0] f_sck_high_cnt, f_sck_low_cnt;

always @(posedge i_clk) begin
    if (!i_reset_n) begin
        f_sck_high_cnt <= 0;
        f_sck_low_cnt  <= 0;
    end else begin
        if (i_sck) begin
            f_sck_high_cnt <= (f_sck_high_cnt == 4'hF) ? 4'hF : f_sck_high_cnt + 1;
            f_sck_low_cnt  <= 0;
        end else begin
            f_sck_low_cnt  <= (f_sck_low_cnt == 4'hF) ? 4'hF : f_sck_low_cnt + 1;
            f_sck_high_cnt <= 0;
        end
    end
end

`ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    $fell(i_sck) |-> (f_sck_high_cnt >= 2));

`ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    $rose(i_sck) |-> (f_sck_low_cnt >= 2));
```

### C. Philips I2S Word Select (WS) Bus Timing
Per Philips I2S standard:
1. `i_ws` transitions only when `i_sck` is low (or on `i_sck` falling edge).
2. Each channel slot contains at least `DATA_WIDTH + 1` serial bit clock cycles (1 delay slot + `DATA_WIDTH` audio bits):
```systemverilog
`ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    $changed(i_ws) |-> (!i_sck));

reg [6:0] f_sck_pulses_in_slot;
always @(posedge i_clk) begin
    if (!i_reset_n || ws_edge)
        f_sck_pulses_in_slot <= 0;
    else if (sck_rise)
        f_sck_pulses_in_slot <= f_sck_pulses_in_slot + 1;
end

`ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    ws_edge |-> (f_sck_pulses_in_slot >= (DATA_WIDTH + 1)));
```

### D. Host TX Ready/Valid Handshake
The host logic is assumed to maintain stable data inputs (`i_tx_data_l`, `i_tx_data_r`) while `i_tx_valid` is asserted until `o_tx_ready` accepts the sample pair:
```systemverilog
`ifdef I2S_SLAVE_ENABLE_TX
`ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    (i_tx_valid && !o_tx_ready) |=> (i_tx_valid && $stable(i_tx_data_l) && $stable(i_tx_data_r)));
`endif
```

---

## 4. Safety & Protocol Invariants (`assert`)

### A. Reset & Default State Verification
All state registers and outputs must enter known, quiescent states upon reset:
```systemverilog
`ASSERT property (@(posedge i_clk)
    !i_reset_n |-> (o_channel_sync == 1'b0));

`ifdef I2S_SLAVE_ENABLE_RX
`ASSERT property (@(posedge i_clk)
    !i_reset_n |-> (o_rx_valid == 1'b0 && o_rx_data_l == '0 && o_rx_data_r == '0 && rx_bit_cnt == '0));
`else
`ASSERT property (@(posedge i_clk)
    (o_rx_valid == 1'b0 && o_rx_data_l == '0 && o_rx_data_r == '0));
`endif

`ifdef I2S_SLAVE_ENABLE_TX
`ASSERT property (@(posedge i_clk)
    !i_reset_n |-> (o_sd == 1'b0 && o_tx_ready == 1'b0 && tx_bit_cnt == '0));
`else
`ASSERT property (@(posedge i_clk)
    (o_sd == 1'b0 && o_tx_ready == 1'b0));
`endif
```

### B. Channel Sync Pulse Purity
`o_channel_sync` must fire if and only if a synchronized WS transition occurs, and it must never assert for more than 1 cycle:
```systemverilog
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    o_channel_sync == (ws_sync[2] != ws_sync[1]));

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    o_channel_sync |=> !o_channel_sync);
```

### C. Counter Bounds & Slot Padding
Counters must never overflow their bit width or count beyond the allocated slot boundary:
```systemverilog
`ifdef I2S_SLAVE_ENABLE_RX
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    rx_bit_cnt <= (DATA_WIDTH + 1));
`endif

`ifdef I2S_SLAVE_ENABLE_TX
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    tx_bit_cnt <= DATA_WIDTH);

// Slot padding: when tx_bit_cnt reaches DATA_WIDTH, o_sd must remain 0
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (tx_bit_cnt == DATA_WIDTH) |-> (o_sd == 1'b0));
`endif
```

### D. RX Valid Strobe Rules
`o_rx_valid` indicates the completion of a full stereo frame (Left + Right channels) and must only assert on the transition back into the Left channel (`ws_edge && ws_sync[1] == 0`):
```systemverilog
`ifdef I2S_SLAVE_ENABLE_RX
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    o_rx_valid |=> !o_rx_valid);

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    o_rx_valid |-> (ws_edge && (ws_sync[1] == 1'b0)));

// Output samples remain stable between valid pulses
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    !o_rx_valid |=> ($stable(o_rx_data_l) && $stable(o_rx_data_r)));
`endif
```

### E. TX Ready Handshake & Double-Buffering
Ensures outgoing Left/Right sample pairs are latched cleanly without race conditions:
```systemverilog
`ifdef I2S_SLAVE_ENABLE_TX
// Ready requests next sample pair at frame start
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (ws_edge && (ws_sync[1] == 1'b0)) |=> o_tx_ready);

// Handshake deasserts when accepted
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (i_tx_valid && o_tx_ready) |=> !o_tx_ready);

// Right channel sample captured into tx_r_active to prevent mid-frame corruption
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (ws_edge && (ws_sync[1] == 1'b0)) |=> (tx_r_active == $past(tx_r_reg)));

// Holding registers update only on active handshake
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (i_tx_valid && o_tx_ready) |=> (tx_l_reg == $past(i_tx_data_l) && tx_r_reg == $past(i_tx_data_r)));

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    !(i_tx_valid && o_tx_ready) |=> ($stable(tx_l_reg) && $stable(tx_r_reg)));
`endif
```

---

## 5. Data Path & Protocol Timing Contracts (`assert`)

### A. TX Serial Stream & Philips 1-SCK Delay Rule
Data serialization must strictly adhere to the Philips 1-SCK delay slot:
1. When `ws_edge` occurs, `tx_shift_reg` reloads, and `tx_bit_cnt` resets to 0.
2. During the period between `ws_edge` and the first `sck_fall`, `tx_bit_cnt` remains 0.
3. On the first `sck_fall`, `o_sd` drives the MSB (`tx_shift_reg[DATA_WIDTH-1]`), and `tx_bit_cnt` increments.
```systemverilog
`ifdef I2S_SLAVE_ENABLE_TX
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (ws_edge && (ws_sync[1] == 1'b0)) |=> (tx_shift_reg == $past(tx_l_reg)));

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (ws_edge && (ws_sync[1] == 1'b1)) |=> (tx_shift_reg == $past(tx_r_active)));

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    ws_edge |=> (tx_bit_cnt == 0) until sck_fall);

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (sck_fall && (tx_bit_cnt == 0)) |=> (o_sd == $past(tx_shift_reg[DATA_WIDTH-1])));
`endif
```

### B. RX Sampling & 1-SCK Delay Rule
1. On `ws_edge`, `rx_bit_cnt` resets to 0.
2. On the first `sck_rise`, `rx_bit_cnt` increments to 1 without shifting data (the 1-SCK delay slot).
3. On subsequent `sck_rise` events, bits are shifted in MSB-first.
4. When the LSB arrives (`rx_bit_cnt == DATA_WIDTH`), the complete word is transferred to `rx_l_data` or `rx_r_data`:
```systemverilog
`ifdef I2S_SLAVE_ENABLE_RX
`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    ws_edge |=> (rx_bit_cnt == 0));

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (sck_rise && (rx_bit_cnt == 0)) |=> (rx_bit_cnt == 1 && $stable(rx_shift_reg)));

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (sck_rise && (rx_bit_cnt == DATA_WIDTH) && (cur_channel == 1'b0)) 
    |=> (rx_l_data == {$past(rx_shift_reg), $past(sd_sync[1])}));

`ASSERT property (@(posedge i_clk) disable iff (!i_reset_n)
    (sck_rise && (rx_bit_cnt == DATA_WIDTH) && (cur_channel == 1'b1)) 
    |=> (rx_r_data == {$past(rx_shift_reg), $past(sd_sync[1])}));
`endif
```

---

## 6. Functional Reachability (`cover`)

Cover properties prove that real audio traffic sequences can be completed without artificial deadlock:

```systemverilog
// Cover 1: Complete reception of a non-zero stereo audio frame
`ifdef I2S_SLAVE_ENABLE_RX
`COVER property (@(posedge i_clk) disable iff (!i_reset_n)
    o_rx_valid && (o_rx_data_l != '0) && (o_rx_data_r != '0));

// Cover 2: Back-to-back consecutive stereo frames
`COVER property (@(posedge i_clk) disable iff (!i_reset_n)
    o_rx_valid ##[1:$] o_rx_valid);
`endif

// Cover 3: Successful host TX handshake
`ifdef I2S_SLAVE_ENABLE_TX
`COVER property (@(posedge i_clk) disable iff (!i_reset_n)
    o_tx_ready && i_tx_valid);

// Cover 4: Serial bit transmission activity
`COVER property (@(posedge i_clk) disable iff (!i_reset_n)
    (sck_fall && o_sd == 1'b1));
`endif

// Cover 5: Full-duplex simultaneous active streaming
`if defined(I2S_SLAVE_ENABLE_RX) && defined(I2S_SLAVE_ENABLE_TX)
`COVER property (@(posedge i_clk) disable iff (!i_reset_n)
    o_rx_valid && o_tx_ready && i_tx_valid);
`endif
```

---

## 7. Execution Guide

### Running SymbiYosys
Formal verification can be run using the preconfigured [run.sh](file:///c:/Workspace/FPGA/FPGA_interfaces/audio/I2S/I2S_slave/test_rtl/formal/I2S_slave/run.sh) script or directly via `sby`:

```bash
# Sourcing OSS CAD Suite (in WSL / Linux)
source ~/oss-cad-suite/environment

# Run formal suite via run.sh
cd audio/I2S/I2S_slave/test_rtl/formal/I2S_slave
./run.sh

# Or invoke SymbiYosys directly
sby -f I2S_slave.sby
```

### Inspecting Counterexamples & Traces
If a property fails or when viewing cover traces:
- Bounded Model Check failure trace: `I2S_slave_bound/engine_0/trace.vcd`
- Proof failure trace: `I2S_slave_prf/engine_0/trace.vcd`
- Cover trace: `I2S_slave_cvr/engine_0/trace0.vcd`
- Open any trace in **Surfer** or **GTKWave**:
  ```bash
  surfer I2S_slave_cvr/engine_0/trace0.vcd
  ```
