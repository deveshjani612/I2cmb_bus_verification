
class wb_coverage extends ncsu_component #(.T(wb_transaction));

    covergroup wb_transaction_cg with function sample (wb_op_t op, cmd_t cmd, rsp_t rsp);

        option.per_instance = 1;
        option.name = get_full_name();
        
        // Testplan 2.11: Ensure that the DUT receives every possible byte-level command
        cmd: coverpoint cmd
        {
            bins valid_cmd[] = {CMD_START, CMD_STOP, CMD_READ_ACK, CMD_READ_NAK, CMD_WRITE, CMD_SET_BUS, CMD_WAIT};
        }

        // Testplan 2.12: Ensure that every legal command sequence is hit
        cmd_sequence: coverpoint cmd iff (op == WB_WRITE)
        {
            bins cmd_seq[] = 
                (CMD_START => CMD_START, CMD_STOP, CMD_WRITE),
                (CMD_STOP => CMD_START, CMD_WAIT, CMD_SET_BUS),
                (CMD_READ_ACK => CMD_READ_ACK, CMD_READ_NAK),
                (CMD_READ_NAK => CMD_START, CMD_STOP),
                (CMD_WRITE => CMD_START, CMD_STOP, CMD_WRITE, CMD_READ_ACK, CMD_READ_NAK),
                (CMD_SET_BUS => CMD_START, CMD_STOP, CMD_SET_BUS, CMD_WAIT),
                (CMD_WAIT => CMD_START, CMD_SET_BUS, CMD_WAIT);
        }

        // Testplan 2.13: Ensure that the DUT provides every possible response
        rsp: coverpoint rsp iff (op == WB_READ) // Only sample response when we read the CMDR
        {
            bins valid_rsp[] = {RSP_DON, RSP_NAK, RSP_ERR};
        }

    endgroup
    
   // Covergroup for DPR writes
    covergroup dpr_write_cg with function sample(bit [7:0] data);
        option.per_instance = 1;
        option.name = get_full_name();

        // Testplan: Check if user can write different values to DPR
        dpr_data: coverpoint data {
            bins full_range[] = {[8'h00:8'hFF]}; // Covers all 256 values
            // Or if you prefer functional bins:
            // bins zeros      = {8'h00};
            // bins edge_cases = {8'h00, 8'hFF};
            // bins mid_vals   = {[8'h10:8'hF0]};
        }
    endgroup
    // Covergroup declaration
    covergroup csr_cg with function sample(bit [7:0] csr_val);
        option.per_instance = 1;
        option.name = get_full_name();

        // Writable bits
        csr_e: coverpoint csr_val[7] {
            bins e_on  = {1'b1};
            bins e_off = {1'b0};
        }

        csr_ie: coverpoint csr_val[6] {
            bins ie_on  = {1'b1};
            bins ie_off = {1'b0};
        }

        // Read-only bits — now invalidating busy & captured states
        csr_bb: coverpoint csr_val[5] {
            bins bb_idle = {1'b0};
            illegal_bins bb_busy = {1'b1}; 
        }

        csr_bc: coverpoint csr_val[4] {
            bins bc_free = {1'b0};
            illegal_bins bc_taken = {1'b1}; 
        }

    endgroup


    function new (string name = "", ncsu_component_base parent = null);
        super.new (name, parent);
        wb_transaction_cg = new;
        dpr_write_cg = new;
        csr_cg = new;
    endfunction

    virtual function void nb_put (T trans);
        cmdr_u cmdr;
        cmd_t cmd;
        rsp_t rsp;
        wb_op_t op;
        if (trans.addr == CMDR_ADDR) begin
            cmdr.value = trans.data;
            cmd = cmdr.fields.cmd;
            rsp = rsp_t'({cmdr.fields.don, cmdr.fields.nak, cmdr.fields.al, cmdr.fields.err});
            op = wb_op_t'(trans.we);
            wb_transaction_cg.sample(op, cmd, rsp);
        end
        if (trans.addr == DPR_ADDR && trans.we == 1'b1) begin // Write to DPR
            dpr_write_cg.sample(trans.data);  // Sample the written value
        end
        if (trans.addr == CSR_ADDR && trans.we == 1'b0) begin // Read from CSR
            csr_cg.sample(trans.data); // Sample value on read
        end
    endfunction
endclass