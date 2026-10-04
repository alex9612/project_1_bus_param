
class driver #(parameter int BITS = 1, parameter int DRVRS = 4, parameter int PCKG_SZ = 16);
    virtual bus_if #(.BITS(BITS), .DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ)).driver vif; // The modport has been defined .driver vif
    event drv_done;

    typedef trans_drv #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_agent_t;
    typedef mailbox #(trans_agent_t) agent_mbx_t;

    int unsigned driver_id;

    function new(int unsigned driver_id, agent_mbx_t agent_drv_mbx);
        this.driver_id = driver_id;
        this.agent_drv_mbx = agent_drv_mbx;
    endfunction

    task run();
        trans_agent_t tr;
        $info("[%0t] The Driver [%0d] has been initialized", $time, );
        vif.reset = 1; // Reset first 2 cycles
        @(posedge vif.clk);
        vif.reset = 1;
        @(posedge vif.clk);
        forever begin
            // Wating for a new transaction from the Agent
            agent_drv_mbx.get(tr);
            $info("[%0t] Driver [%0d] received transaction %0d", $time, driver_id, tr.id);

        end

    endtask

endclass