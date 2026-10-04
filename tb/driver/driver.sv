
class driver #(parameter int BITS = 1, parameter int DRVRS = 4, parameter int PCKG_SZ = 16);
    virtual bus_if #(.BITS(BITS), .DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ)).driver vif; // The modport has been defined .driver vif
    event drv_done;

    typedef trans_drv #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_agent_t;
    typedef mailbox #(trans_agent_t) agent_mbx_t;

    task run();
        $info("[%0t] The Driver [%0d] has been initialized", $time, );
        vif.reset = 1; // Reset first 2 cycles
        @(posedge vif.clk);
        vif.reset = 1;
        @(posedge vif.clk);
        forever begin
            trans_bus // Not implemented

        end

    endtask

endclass