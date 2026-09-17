`timescale 1ps/1ps

interface template_if(input bit clk);
    logic reset_n;
    logic [7:0] data_in;
    logic [7:0] data_out;
    
    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output reset_n;
        output data_in;
        input data_out;
    endclocking
    
    clocking mon_cb @(posedge clk);
        default input #1 output #1;
        input reset_n;
        input data_in;
        input data_out;
    endclocking
    
    modport driver(clocking drv_cb);
    modport monitor(clocking mon_cb);
endinterface