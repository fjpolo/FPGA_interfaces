class template_driver extends uvm_driver #(template_transaction);
    `uvm_component_utils(template_driver)
    
    virtual template_if vif;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            vif.drv_cb.reset_n <= req.reset_n;
            vif.drv_cb.data_in <= req.data_in;
            @(vif.drv_cb);
            seq_item_port.item_done();
        end
    endtask
endclass