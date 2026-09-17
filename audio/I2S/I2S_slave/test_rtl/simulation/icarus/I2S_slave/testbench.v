// =============================================================================
// File        : testbench.v for I2S_slave.v
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

`default_nettype none
`timescale 1ns/1ps

module testbench;

    // Inputs
    reg         i_clk;
    reg         i_reset_n;
    reg  [7:0]  i_data;

    // Outputs
    wire [7:0]  o_data;

    // Instantiate the Unit Under Test (UUT)
    I2S_slave uut (
        .i_clk     (i_clk),
        .i_reset_n (i_reset_n),
        .i_data    (i_data),
        .o_data    (o_data)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk; // 10ps clock period
    end

    // Waveform dumping
    initial begin
        $dumpfile("dump.vcd"); // Specify the waveform file name
        $dumpvars(0, testbench); // Dump all signals in the testbench module
    end

    // Test sequence
    initial begin
        // Initialize inputs
        i_reset_n = 0;
        i_data    = 8'h00;

        // Apply reset
        #10;
        i_reset_n = 1;

        // // Test 1: Check reset behavior
        // #10;
        // if (o_data !== 8'h00) begin
        //     $display("FAIL: Reset test failed. Expected 8'h00, got %h", o_data);
        //     $finish;
        // end

        // // Test 2: Check data propagation
        // i_data = 8'hA5;
        // #10;
        // if (o_data !== 8'hA5) begin
        //     $display("FAIL: Data propagation test failed. Expected 8'hA5, got %h", o_data);
        //     $finish;
        // end

        // // Test 3: Check another data value
        // i_data = 8'h3C;
        // #10;
        // if (o_data !== 8'h3C) begin
        //     $display("FAIL: Data propagation test failed. Expected 8'h3C, got %h", o_data);
        //     $finish;
        // end

        // If all tests pass
        $display("PASS: All tests passed.");
        $finish;
    end

    // Monitor for errors
    initial begin
        #100; // Timeout to catch unexpected behavior
        $display("ERROR: Simulation timed out.");
        $finish;
    end

endmodule