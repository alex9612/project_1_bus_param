
class Agent #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, parameter bit [7:0] BROADCAST_CODE = 8'hFF);

    typedef trans_gen #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_gen_t;
    typedef trans_drv #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_drv_t;

    typedef mailbox #(trans_gen_t) gen_mbx_t;
    typedef mailbox #(trans_drv_t) drv_mbx_t;

    gen_mbx_t gen_agent_mbx;
    drv_mbx_t agent_drv_mbx[DRVRS];
    drv_mbx_t agent_scb_mbx; // Create a copy of the transaction to sb

    function new(gen_mbx_t gen_agent_mbx, drv_mbx_t agent_drv_mbx[DRVRS], drv_mbx_t agent_scb_mbx);
        if (gen_agent_mbx == null || agent_scb_mbx == null)
            $fatal(1, "[Agent] A required mailbox was not created.");
        
        this.gen_agent_mbx = gen_agent_mbx;
        this.agent_drv_mbx[DRVRS] = agent_drv_mbx[DRVRS];
        this.agent_scb_mbx = agent_scb_mbx;

    endfunction







    task run();
        $info("[%0t] The Agent has been initialized", $time);

        trans_gen_t tr;
        trans_drv_t tr_drv;
        trans_drv_t tr_scb;

        forever begin
            gen_agent_mbx.get(tr);

            if (tr == null)
                $fatal(1, "[Agent] Null transaction received.");

            if (tr.source >= DRVRS) begin
                $fatal(1, "[Agent] Invalid source device %0d.", tr.source);
            end

            tr_drv = new(tr);
            tr_scb = new(tr); // This copy tells the scoreboard what was requested.

            agent_scb_mbx.put(tr_scb);
            $info("[%0t] [Agent] Transaction [%0d] sent to Scoreboard", $time, tr.id);
            agent_drv_mbx[tr.source].put(tr_drv);
            $info("[%0t] [Agent] Transaction [%0d] sent to Driver [%0d]", $time, tr_drv.id, tr_drv.destination);
        end
    endtask

endclass