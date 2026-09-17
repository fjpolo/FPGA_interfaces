class template_transaction extends uvm_sequence_item;
    rand bit [7:0] data_in;
    bit [7:0] data_out;
    bit reset_n;
    
    `uvm_object_utils_begin(template_transaction)
        `uvm_field_int(data_in, UVM_ALL_ON)
        `uvm_field_int(data_out, UVM_ALL_ON)
        `uvm_field_int(reset_n, UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new(string name = "template_transaction");
        super.new(name);
    endfunction
    
    constraint c_valid_data {
        data_in inside {[0:255]};
    }
endclass