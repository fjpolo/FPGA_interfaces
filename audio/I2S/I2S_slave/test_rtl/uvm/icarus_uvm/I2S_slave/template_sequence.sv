class template_sequence extends uvm_sequence #(template_transaction);
    `uvm_object_utils(template_sequence)
    
    function new(string name = "template_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        template_transaction trans;
        
        // Apply reset
        trans = template_transaction::type_id::create("trans");
        trans.reset_n = 0;
        start_item(trans);
        finish_item(trans);
        
        // Release reset and send random data
        repeat(10) begin
            trans = template_transaction::type_id::create("trans");
            trans.reset_n = 1;
            assert(trans.randomize());
            start_item(trans);
            finish_item(trans);
        end
    endtask
endclass