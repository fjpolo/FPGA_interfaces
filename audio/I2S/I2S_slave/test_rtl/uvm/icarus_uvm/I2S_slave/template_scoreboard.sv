class template_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(template_scoreboard)
    
    uvm_analysis_imp #(template_transaction, template_scoreboard) mon_imp;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_imp = new("mon_imp", this);
    endfunction
    
    virtual function void write(template_transaction trans);
        if(!trans.reset_n) begin
            if(trans.data_out !== 8'h00) begin
                `uvm_error("SCBD", $sformatf("Reset failed: expected 0x00, got 0x%02h", trans.data_out))
            end
        end else begin
            if(trans.data_out !== trans.data_in) begin
                `uvm_error("SCBD", $sformatf("Data mismatch: expected 0x%02h, got 0x%02h", 
                    trans.data_in, trans.data_out))
            end else begin
                `uvm_info("SCBD", $sformatf("Data match: 0x%02h", trans.data_out), UVM_HIGH)
            end
        end
    endfunction
endclass