// =============================================================================
// File        : Formal Properties for I2S_slave.v
// Author      : @fjpolo
// email       : fjpolo@gmail.com
// Description : <Brief description of the module or file>
// License     : MIT License
//
// Copyright (c) 2025 | @fjpolo
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
`ifdef	FORMAL
// Change direction of assumes
`define	ASSERT	assert
`ifdef	I2S_SLAVE
`define	ASSUME	assume
`else
`define	ASSUME	assert
`endif

    ////////////////////////////////////////////////////
	//
	// f_past_valid register
	//
	////////////////////////////////////////////////////
	reg	f_past_valid;
	initial	f_past_valid = 0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;



    ////////////////////////////////////////////////////
	//
	// Reset
	//
	////////////////////////////////////////////////////
	initial assume (!i_reset_n);

	always @(posedge i_clk) begin
		if (!f_past_valid) begin
			`ASSUME(!i_reset_n);
		end
	end

	// assert property (@(posedge i_clk)
    // 		!i_reset_n |-> (o_channel_sync == 1'b0));
	always @(posedge i_clk) begin
		if(f_past_valid && !$past(i_reset_n)) begin
			assert(o_channel_sync == 1'b0);
		end
	end

	// All state registers and outputs must enter known, quiescent states upon reset:
`ifdef I2S_SLAVE_ENABLE_RX
	// assert property (@(posedge i_clk)
	// 		!i_reset_n |-> (o_rx_valid == 1'b0 && o_rx_data_l == '0 && o_rx_data_r == '0 && rx_bit_cnt == '0));
	always @(posedge i_clk) begin
		if(f_past_valid && !$past(i_reset_n)) begin
			assert(o_rx_valid == 1'b0);
			assert(o_rx_data_l == 0);
			assert(o_rx_data_r == 0);
			assert(rx_bit_cnt == 0);
		end
	end
`else
	// assert property (@(posedge i_clk)
	// 		(o_rx_valid == 1'b0 && o_rx_data_l == '0 && o_rx_data_r == '0));
	always @(posedge i_clk) begin
		if(f_past_valid && $past(i_reset_n)) begin
			assert(o_rx_valid == 1'b0);
			assert(o_rx_data_l == 0);
			assert(o_rx_data_r == 0);
		end
	end
`endif

	// o_channel_sync must fire if and only if a synchronized WS transition occurs, and 
	// it must never assert for more than 1 cycle
	// assert property (@(posedge i_clk) disable iff (!i_reset_n)
    // 		o_channel_sync == (ws_sync[2] != ws_sync[1]));
	always @(posedge i_clk) begin
		if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
			assert(o_channel_sync == $past(ws_sync[2] != ws_sync[1]));
		end
	end

	// assert property (@(posedge i_clk) disable iff (!i_reset_n)
	// 		o_channel_sync |=> !o_channel_sync);
	always @(posedge i_clk) begin
		if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
			if($past(o_channel_sync)) begin
				assert(!o_channel_sync);
			end
		end
	end

    ////////////////////////////////////////////////////
	//
	// BMC
	//
	////////////////////////////////////////////////////

	// Clocks
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

	// `ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    //     $fell(i_sck) |-> (f_sck_high_cnt >= 2));
	always @(posedge i_clk) begin
		if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
			if($fell(i_sck)) begin
				`ASSUME(f_sck_high_cnt >= 2);
			end
		end
	end

	// `ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    //     $rose(i_sck) |-> (f_sck_low_cnt >= 2));
	always @(posedge i_clk) begin
		if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
			if($rose(i_sck)) begin
				`ASSUME(f_sck_low_cnt >= 2);
			end
		end
	end


    ////////////////////////////////////////////////////
	//
	// Contract
	//
	////////////////////////////////////////////////////   

	//
	// INPUT ASSMPTIONS/ASSERTIONS
	//

	// i_ws transitions only when i_sck is low (or on i_sck falling edge).
	// `ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    // 		$changed(i_ws) |-> (!i_sck));
	always @(posedge i_clk) begin
		if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
			if($changed(i_ws)) begin
				`ASSUME(!i_sck);
			end
		end
	end

	// Each channel slot contains at least DATA_WIDTH + 1 serial bit clock cycles (1 delay slot + DATA_WIDTH audio bits)
	reg [6:0] f_sck_pulses_in_slot;
	always @(posedge i_clk) begin
		if (!i_reset_n || ws_edge)
			f_sck_pulses_in_slot <= 0;
		else if (sck_rise)
			f_sck_pulses_in_slot <= f_sck_pulses_in_slot + 1;
	end
	// `ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
    // 		ws_edge |-> (f_sck_pulses_in_slot >= (DATA_WIDTH + 1)));
	always @(posedge i_clk) begin
		if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
			if(ws_edge || $rose(i_ws)) begin
				`ASSUME(f_sck_pulses_in_slot >= (DATA_WIDTH + 1));
			end
		end
	end

	// The host logic is assumed to maintain stable data inputs (i_tx_data_l, i_tx_data_r) while i_tx_valid 
	// is asserted until o_tx_ready accepts the sample pair
	`ifdef I2S_SLAVE_ENABLE_TX
	// `ASSUME property (@(posedge i_clk) disable iff (!i_reset_n)
	// 	(i_tx_valid && !o_tx_ready) |=> (i_tx_valid && $stable(i_tx_data_l) && $stable(i_tx_data_r)));
	always @(posedge i_clk) begin
		if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
			if(i_tx_valid && !o_tx_ready) begin
				`ASSUME(i_tx_valid);
				`ASSUME($stable(i_tx_data_l));
				`ASSUME($stable(i_tx_data_r));
			end
		end
	end
	`endif

	//
	// ASSERTIONS
	//


	

    ////////////////////////////////////////////////////
	//
	// Induction
	//
	////////////////////////////////////////////////////
    
	////////////////////////////////////////////////////
	//
	// Cover
	//
	////////////////////////////////////////////////////     
           
`endif

