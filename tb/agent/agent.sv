class Agent #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, parameter int MAX_DEVICES = 10);

    typedef Transaction #(.PCKG_SZ(PCKG_SZ), .MAX_DEVICES(MAX_DEVICES)) transaction_t;
    typedef mailbox #(transaction_t) transaction_mbx_t;

    transaction_mbx_t gen_agent_mbx;
    transaction_mbx_t agent_drv_mbx[DRVRS];
    transaction_mbx_t agent_scb_mbx;

    function new(transaction_mbx_t gen_agent_mbx);
        this.gen_agent_mbx = gen_agent_mbx;

        for (int i = 0; i < DRVRS; i++) begin
            agent_drv_mbx[i] = new();
        end

        agent_scb_mbx = new();
    endfunction

    task run();
        transaction_t tr;
        transaction_t tr_drv;
        transaction_t tr_scb;

        forever begin
            gen_agent_mbx.get(tr);

            if (tr.source >= DRVRS) begin
                $fatal(1, "[Agent] Invalid source device %0d.", tr.source);
            end

            tr_drv = tr.copy();
            tr_scb = tr.copy();

            agent_scb_mbx.put(tr_scb);
            agent_drv_mbx[tr.source].put(tr_drv);
        end
    endtask

endclass