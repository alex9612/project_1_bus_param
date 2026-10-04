
class Agent #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, parameter bit [7:0] BROADCAST_CODE = 8'hFF);

    typedef trans_gen #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_gen_t;
    typedef trans_drv #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_drv_t;

    typedef mailbox #(trans_gen_t) gen_mbx_t;
    typedef mailbox #(trans_drv_t) drv_mbx_t;

    gen_mbx_t gen_agent_mbx;
    drv_mbx_t agent_drv_mbx[DRVRS];
    drv_mbx_t agent_scb_mbx; // Create a copy of the transaction to sb

    function new(transaction_mbx_t gen_agent_mbx);
        this.gen_agent_mbx = gen_agent_mbx;

        for (int i = 0; i < DRVRS; i++) begin
            agent_drv_mbx[i] = new();
        end

        agent_scb_mbx = new();
    endfunction

    task run();
        trans_gen_t tr;
        trans_drv_t tr_drv;
        trans_drv_t tr_scb;

        // Ideally an event is the way here
        forever begin
            gen_agent_mbx.get(tr);

            if (tr == null)
                $fatal(1, "[Agent] Null transaction received.");

            if (tr.source >= DRVRS) begin
                $fatal(1, "[Agent] Invalid source device %0d.", tr.source);
            end

            // This copy tells the scoreboard what was requested.
            tr_drv = new(tr);
            tr_scb = new(tr);

            agent_scb_mbx.put(tr_scb);
            agent_drv_mbx[tr.source].put(tr_drv);
        end
    endtask

endclass