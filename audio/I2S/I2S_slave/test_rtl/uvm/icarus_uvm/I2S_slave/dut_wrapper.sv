`timescale 1ps/1ps

module dut_wrapper(
    input wire i_clk,
    input wire i_reset_n,
    input wire [7:0] i_data,
    output wire [7:0] o_data
);

I2S_slave dut (
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    .i_data(i_data),
    .o_data(o_data)
);

endmodule