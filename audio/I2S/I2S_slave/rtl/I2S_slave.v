// =============================================================================
// File        : I2S_slave.v
// Author      : @fjpolo
// email       : fjpolo@gmail.com
// Description : Parameterized Philips I2S Digital Audio Transceiver (Slave Mode)
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

module I2S_slave #(
    parameter integer DATA_WIDTH = 24  // Audio sample bit depth (16, 24, 32)
) (
    // Master system clock and active-low reset
    input  wire                  i_clk,
    input  wire                  i_reset_n,

    // External I2S bus from master
    input  wire                  i_sck,          // Continuous serial bit clock from master
    input  wire                  i_ws,           // Word select from master (0 = Left, 1 = Right)
    input  wire                  i_sd,           // Serial data in (Slave Receiver)
    output reg                   o_sd,           // Serial data out (Slave Transmitter)

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
    output reg                   o_channel_sync  // Pulsed when WS transitions
);

    // -------------------------------------------------------------------------
    // Synchronizers & Edge Detectors for External Master Signals
    // -------------------------------------------------------------------------
    reg [2:0] sck_sync;
    reg [2:0] ws_sync;
    reg [1:0] sd_sync;

    always @(posedge i_clk) begin
        if (!i_reset_n) begin
            sck_sync <= 3'b000;
            ws_sync  <= 3'b000;
            sd_sync  <= 2'b00;
        end else begin
            sck_sync <= {sck_sync[1:0], i_sck};
            ws_sync  <= {ws_sync[1:0], i_ws};
            sd_sync  <= {sd_sync[0], i_sd};
        end
    end

    wire sck_rise = (sck_sync[2:1] == 2'b01);
    wire sck_fall = (sck_sync[2:1] == 2'b10);
    wire ws_edge  = (ws_sync[2] != ws_sync[1]);

    // -------------------------------------------------------------------------
    // Bit Counter & Channel State
    // -------------------------------------------------------------------------
    localparam integer CNT_WIDTH = 6;
    localparam [CNT_WIDTH-1:0] DATA_WIDTH_CONST = DATA_WIDTH[CNT_WIDTH-1:0];

    reg [CNT_WIDTH-1:0] rx_bit_cnt;
    reg [CNT_WIDTH-1:0] tx_bit_cnt;
    reg                 cur_channel; // 0 = Left, 1 = Right

    // RX shift register holds (DATA_WIDTH-1) bits; last bit combined on output
    reg [DATA_WIDTH-2:0] rx_shift_reg;

    // TX shift and holding registers
    reg [DATA_WIDTH-1:0] tx_l_reg;
    reg [DATA_WIDTH-1:0] tx_r_reg;
    reg [DATA_WIDTH-1:0] tx_shift_reg;

    // -------------------------------------------------------------------------
    // Main Synchronous Logic
    // -------------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_reset_n) begin
            o_sd           <= 1'b0;
            o_rx_data_l    <= {DATA_WIDTH{1'b0}};
            o_rx_data_r    <= {DATA_WIDTH{1'b0}};
            o_rx_valid     <= 1'b0;
            o_tx_ready     <= 1'b0;
            o_channel_sync <= 1'b0;
            cur_channel    <= 1'b0;
            rx_bit_cnt     <= {CNT_WIDTH{1'b0}};
            tx_bit_cnt     <= {CNT_WIDTH{1'b0}};
            rx_shift_reg   <= {(DATA_WIDTH-1){1'b0}};
            tx_l_reg       <= {DATA_WIDTH{1'b0}};
            tx_r_reg       <= {DATA_WIDTH{1'b0}};
            tx_shift_reg   <= {DATA_WIDTH{1'b0}};
        end else begin
            // Default pulses
            o_rx_valid     <= 1'b0;
            o_channel_sync <= 1'b0;
            o_tx_ready     <= 1'b0;

            // Latch user TX samples when valid
            if (i_tx_valid && o_tx_ready) begin
                tx_l_reg <= i_tx_data_l;
                tx_r_reg <= i_tx_data_r;
            end

            // -----------------------------------------------------------------
            // Word Select Transition (New Audio Word Slot)
            // -----------------------------------------------------------------
            if (ws_edge) begin
                o_channel_sync <= 1'b1;
                cur_channel    <= ws_sync[1];
                rx_bit_cnt     <= {CNT_WIDTH{1'b0}};
                tx_bit_cnt     <= {CNT_WIDTH{1'b0}};

                // If transitioning to Left channel, Right channel just finished
                // Assert valid strobe for stereo pair
                if (ws_sync[1] == 1'b0) begin
                    o_rx_valid <= 1'b1;
                    o_tx_ready <= 1'b1; // Request next sample pair from host
                end

                // Load TX shift register for upcoming slot
                if (ws_sync[1] == 1'b0) begin
                    tx_shift_reg <= tx_l_reg;
                end else begin
                    tx_shift_reg <= tx_r_reg;
                end
            end

            // -----------------------------------------------------------------
            // Receiver (Sample on SCK Rising Edge)
            // Philips I2S: Bit 0 (first rising edge after WS edge) is delay slot.
            // Bits 1..DATA_WIDTH: MSB-first audio data bits.
            // -----------------------------------------------------------------
            if (sck_rise) begin
                if (rx_bit_cnt == {CNT_WIDTH{1'b0}}) begin
                    // First SCK cycle after WS transition: skip 1-cycle delay
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
                    // Sample final bit (LSB) and output complete sample
                    rx_bit_cnt <= rx_bit_cnt + {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                    if (cur_channel == 1'b0) begin
                        o_rx_data_l <= {rx_shift_reg, sd_sync[1]};
                    end else begin
                        o_rx_data_r <= {rx_shift_reg, sd_sync[1]};
                    end
                end
            end

            // -----------------------------------------------------------------
            // Transmitter (Shift on SCK Falling Edge)
            // Philips I2S: 1st SCK cycle after WS edge drives idle (0).
            // Starting 2nd SCK cycle, transmit MSB down to LSB.
            // -----------------------------------------------------------------
            if (sck_fall) begin
                if (tx_bit_cnt < DATA_WIDTH_CONST) begin
                    // Drive MSB of remaining shift register (1 SCK period after WS edge)
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

endmodule
