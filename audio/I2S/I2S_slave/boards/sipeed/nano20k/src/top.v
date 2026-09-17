module led (
    input   wire            i_sys_clk,          // clk input
    input   wire            i_sys_rst_n,        // reset input
    output  wire     [5:0]   o_led    // 6 LEDS pin
);

// module I2S_slave(
//     input   wire    [0:0]   i_clk,
//     input   wire    [0:0]   i_reset_n,
//     input   wire    [7:0]   i_data,
//     output  reg     [7:0]   o_data
// );
wire [7:0] o_output;
I2S_slave DUT(
    .i_clk(i_sys_clk),
    .i_reset_n(i_sys_rst_n),
    .i_data('h00),  // Example input data, modify as needed
    .o_data(o_output)   // Connect output to LED pins
);
assign o_led = o_output[5:0]; // Assign the first 6 bits to the LED output    

/*
// Manta Logic Analyzer instantiation placeholder
// Note: To use this, add the generated manta_core.v to your project file list,
// and make sure to map the physical UART RX/TX pins to the top-level ports.
wire uart_rx; // Map to physical RX pin in physical constraints (.cst)
wire uart_tx; // Map to physical TX pin in physical constraints (.cst)

manta my_manta (
    .clk(i_sys_clk),
    .rx(uart_rx),
    .tx(uart_tx),
    .la_core_i_reset_n(i_sys_rst_n),
    .la_core_i_data(DUT.i_data),
    .la_core_o_data(o_output)
);
*/

endmodule
