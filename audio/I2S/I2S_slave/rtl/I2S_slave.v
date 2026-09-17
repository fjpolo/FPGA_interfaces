// =============================================================================
// File        : I2S_slave.v
// Author      : @fjpolo
// email       : fjpolo@gmail.com
// Description : Parameterized Philips I2S Digital Audio Transceiver (Slave Mode)
//               Configurable via IFDEFs for Full-Duplex, RX-Only, or TX-Only.
// License     : MIT License
//
// Copyright (c) 2026 | @fjpolo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// =============================================================================

`default_nettype none
`timescale 1ps/1ps

// -----------------------------------------------------------------------------
// Direction Configuration via IFDEFs
// By default, full-duplex operation (both RX and TX enabled) is synthesized.
// To optimize FPGA resource usage (LUTs/FFs) for unidirectional applications:
//   - Define `I2S_SLAVE_RX_ONLY to synthesize only the Receiver engine.
//   - Define `I2S_SLAVE_TX_ONLY to synthesize only the Transmitter engine.
// -----------------------------------------------------------------------------
`ifndef I2S_SLAVE_TX_ONLY
    `define I2S_SLAVE_ENABLE_RX
`endif

`ifndef I2S_SLAVE_RX_ONLY
    `define I2S_SLAVE_ENABLE_TX
`endif

module I2S_slave #(
    parameter integer DATA_WIDTH = 24  // Audio sample bit depth (16, 24, 32)
) (
    // Master system clock and active-low reset
    input  wire                  i_clk,
    input  wire                  i_reset_n,

    // External I2S bus from master
    input  wire                  i_sck,          // Continuous serial bit clock from master
    input  wire                  i_ws,           // Word select from master (0 = Left, 1 = Right)

`ifdef I2S_SLAVE_ENABLE_RX
    input  wire                  i_sd,           // Serial data in (Slave Receiver)
    output reg  [DATA_WIDTH-1:0] o_rx_data_l,
    output reg  [DATA_WIDTH-1:0] o_rx_data_r,
    output reg                   o_rx_valid,
`else
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire                  i_sd,
    /* verilator lint_on UNUSEDSIGNAL */
    output wire [DATA_WIDTH-1:0] o_rx_data_l,
    output wire [DATA_WIDTH-1:0] o_rx_data_r,
    output wire                  o_rx_valid,
`endif

`ifdef I2S_SLAVE_ENABLE_TX
    output reg                   o_sd,           // Serial data out (Slave Transmitter)
    input  wire [DATA_WIDTH-1:0] i_tx_data_l,
    input  wire [DATA_WIDTH-1:0] i_tx_data_r,
    input  wire                  i_tx_valid,
    output reg                   o_tx_ready,
`else
    output wire                  o_sd,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [DATA_WIDTH-1:0] i_tx_data_l,
    input  wire [DATA_WIDTH-1:0] i_tx_data_r,
    input  wire                  i_tx_valid,
    /* verilator lint_on UNUSEDSIGNAL */
    output wire                  o_tx_ready,
`endif

    // Status sync indicator
    output reg                   o_channel_sync  // Pulsed when WS transitions
);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    localparam integer CNT_WIDTH = 6;
    localparam [CNT_WIDTH-1:0] DATA_WIDTH_CONST = DATA_WIDTH[CNT_WIDTH-1:0];

    // -------------------------------------------------------------------------
    // Unused Output Tie-offs (When RX or TX disabled)
    // -------------------------------------------------------------------------
`ifndef I2S_SLAVE_ENABLE_RX
    assign o_rx_data_l = {DATA_WIDTH{1'b0}};
    assign o_rx_data_r = {DATA_WIDTH{1'b0}};
    assign o_rx_valid  = 1'b0;
`endif

`ifndef I2S_SLAVE_ENABLE_TX
    assign o_sd        = 1'b0;
    assign o_tx_ready  = 1'b0;
`endif

    // -------------------------------------------------------------------------
    // Block 1: Bus Synchronizers & Clock Edge Detectors
    // Synchronizes external asynchronous master signals into the i_clk domain
    // -------------------------------------------------------------------------
    reg [2:0] sck_sync;
    reg [2:0] ws_sync;
`ifdef I2S_SLAVE_ENABLE_RX
    reg [1:0] sd_sync;
    reg       cur_channel; // 0 = Left, 1 = Right (used by RX word routing)
`endif

    always @(posedge i_clk) begin
        if (!i_reset_n) begin
            sck_sync       <= 3'b000;
            ws_sync        <= 3'b000;
`ifdef I2S_SLAVE_ENABLE_RX
            sd_sync        <= 2'b00;
            cur_channel    <= 1'b0;
`endif
            o_channel_sync <= 1'b0;
        end else begin
            sck_sync       <= {sck_sync[1:0], i_sck};
            ws_sync        <= {ws_sync[1:0], i_ws};
`ifdef I2S_SLAVE_ENABLE_RX
            sd_sync        <= {sd_sync[0], i_sd};
            if (ws_sync[2] != ws_sync[1]) begin
                cur_channel <= ws_sync[1];
            end
`endif
            o_channel_sync <= (ws_sync[2] != ws_sync[1]);
        end
    end

`ifdef I2S_SLAVE_ENABLE_RX
    wire sck_rise = (sck_sync[2:1] == 2'b01);
`endif
`ifdef I2S_SLAVE_ENABLE_TX
    wire sck_fall = (sck_sync[2:1] == 2'b10);
`endif
    wire ws_edge  = (ws_sync[2] != ws_sync[1]);

`ifdef I2S_SLAVE_ENABLE_TX
    // -------------------------------------------------------------------------
    // Block 2: Parallel Master Interface (Host TX Sample Ingest)
    // Manages host sample handshaking and double-buffered holding registers
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] tx_l_reg;
    reg [DATA_WIDTH-1:0] tx_r_reg;
    reg [DATA_WIDTH-1:0] tx_r_active;

    always @(posedge i_clk) begin
        if (!i_reset_n) begin
            tx_l_reg    <= {DATA_WIDTH{1'b0}};
            tx_r_reg    <= {DATA_WIDTH{1'b0}};
            tx_r_active <= {DATA_WIDTH{1'b0}};
            o_tx_ready  <= 1'b0;
        end else begin
            // Ready/Valid Handshake:
            // Assert o_tx_ready at the start of every frame (WS transition to Left channel)
            // and capture the Right channel sample for active transmission.
            if (ws_edge && (ws_sync[1] == 1'b0)) begin
                o_tx_ready  <= 1'b1;
                tx_r_active <= tx_r_reg;
            end else if (i_tx_valid && o_tx_ready) begin
                o_tx_ready  <= 1'b0;
            end

            // Latch new audio samples into holding registers when valid
            if (i_tx_valid && o_tx_ready) begin
                tx_l_reg <= i_tx_data_l;
                tx_r_reg <= i_tx_data_r;
            end
        end
    end
`endif

`ifdef I2S_SLAVE_ENABLE_RX
    // -------------------------------------------------------------------------
    // Internal Assembled Sample Buffers (from Serial RX Engine)
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] rx_l_data;
    reg [DATA_WIDTH-1:0] rx_r_data;

    // -------------------------------------------------------------------------
    // Block 3: Parallel Slave Interface (Host RX Sample Egress)
    // Presents received parallel stereo audio samples and validity to host
    // -------------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_reset_n) begin
            o_rx_data_l <= {DATA_WIDTH{1'b0}};
            o_rx_data_r <= {DATA_WIDTH{1'b0}};
            o_rx_valid  <= 1'b0;
        end else begin
            o_rx_valid <= 1'b0;

            // Complete stereo frame received when transitioning back to Left channel
            if (ws_edge && (ws_sync[1] == 1'b0)) begin
                o_rx_data_l <= rx_l_data;
                o_rx_data_r <= rx_r_data;
                o_rx_valid  <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Block 4: Serial Slave Receiver Engine (RX)
    // Samples i_sd on sck_rise following the Philips 1-SCK cycle delay
    // -------------------------------------------------------------------------
    reg [CNT_WIDTH-1:0]  rx_bit_cnt;
    reg [DATA_WIDTH-2:0] rx_shift_reg;

    always @(posedge i_clk) begin
        if (!i_reset_n) begin
            rx_bit_cnt   <= {CNT_WIDTH{1'b0}};
            rx_shift_reg <= {(DATA_WIDTH-1){1'b0}};
            rx_l_data    <= {DATA_WIDTH{1'b0}};
            rx_r_data    <= {DATA_WIDTH{1'b0}};
        end else begin
            if (ws_edge) begin
                rx_bit_cnt <= {CNT_WIDTH{1'b0}};
            end else if (sck_rise) begin
                if (rx_bit_cnt == {CNT_WIDTH{1'b0}}) begin
                    // First SCK cycle after WS edge: 1-cycle delay slot (skip)
                    rx_bit_cnt <= rx_bit_cnt + {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                end else if (rx_bit_cnt < DATA_WIDTH_CONST) begin
                    // Shift in data bits 1 to DATA_WIDTH-1
                    if (rx_bit_cnt == {{(CNT_WIDTH-1){1'b0}}, 1'b1}) begin
                        rx_shift_reg <= {{(DATA_WIDTH-2){1'b0}}, sd_sync[1]};
                    end else begin
                        rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-3:0], sd_sync[1]};
                    end
                    rx_bit_cnt <= rx_bit_cnt + {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                end else if (rx_bit_cnt == DATA_WIDTH_CONST) begin
                    // Final bit (LSB) sampled: store complete word into channel buffer
                    rx_bit_cnt <= rx_bit_cnt + {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                    if (cur_channel == 1'b0) begin
                        rx_l_data <= {rx_shift_reg, sd_sync[1]};
                    end else begin
                        rx_r_data <= {rx_shift_reg, sd_sync[1]};
                    end
                end
            end
        end
    end
`endif

`ifdef I2S_SLAVE_ENABLE_TX
    // -------------------------------------------------------------------------
    // Block 5: Serial Slave Transmitter Engine (TX)
    // Shifts out o_sd on sck_fall following the Philips 1-SCK cycle delay
    // -------------------------------------------------------------------------
    reg [CNT_WIDTH-1:0]  tx_bit_cnt;
    reg [DATA_WIDTH-1:0] tx_shift_reg;

    always @(posedge i_clk) begin
        if (!i_reset_n) begin
            o_sd         <= 1'b0;
            tx_bit_cnt   <= {CNT_WIDTH{1'b0}};
            tx_shift_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            if (ws_edge) begin
                // Reset counter and load shift register for upcoming channel slot
                tx_bit_cnt <= {CNT_WIDTH{1'b0}};
                if (ws_sync[1] == 1'b0) begin
                    tx_shift_reg <= tx_l_reg;
                end else begin
                    tx_shift_reg <= tx_r_active;
                end
            end else if (sck_fall) begin
                if (tx_bit_cnt < DATA_WIDTH_CONST) begin
                    // Transmit MSB on first SCK fall after WS edge, then shift remaining
                    o_sd         <= tx_shift_reg[DATA_WIDTH-1];
                    tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                    tx_bit_cnt   <= tx_bit_cnt + {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                end else begin
                    // Pad remaining slot cycles with 0
                    o_sd <= 1'b0;
                end
            end
        end
    end
`endif

endmodule
