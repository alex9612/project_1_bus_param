
class driver #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, parameter bit [7:0] BROADCAST_CODE = 8'hFF);
    virtual bus_if #(.PCKG_SZ(PCKG_SZ)).driver vif;
    event drv_done;

    typedef trans_drv #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_agent_t;
    typedef mailbox #(trans_agent_t) agent_mbx_t;

    agent_mbx_t agent_drv_mbx;
    int unsigned driver_id;

    function new(int unsigned driver_id, agent_mbx_t agent_drv_mbx);
        this.driver_id = driver_id;
        this.agent_drv_mbx = agent_drv_mbx;
    endfunction    

    task run();
        trans_agent_t seq_item;
        if (vif == null)
            $fatal(1, "[Driver %0d] Interface was not connected", driver_id);

        $info("[%0t] The Driver [%0d] has been initialized", $time, driver_id);
        vif.pndng = 0;
        vif.D_pop = '0;

        wait (!vif.reset); // Now the reset is being handled by the top

        forever begin
            @(posedge vif.clk);
            // Wating for a new transaction from the Agent
            // Try_get() instead of get() solves the waiting seq item problem
            if (agent_drv_mbx.try_get(seq_item)) begin
                $info("[%0t] Driver [%0d] received transaction %0d", $time, driver_id, seq_item.id);
                    
                    repeat(seq_item.gap) @(posedge vif.clk); // Delay of the seq item
                    vif.D_pop = seq_item.packet;
                    vif.pndng = 1;

                    do @(posedge vif.clk); // Hold seq_item.packet until the DUT takes it
                    while (!vif.pop);
                    vif.pndng = 0;
                    vif.D_pop = '0;
                    ->drv_done; // Top can count how many trans have been fetched
            end
            else begin
                $info("[%0t] Driver [%0d] waiting for a transaction", $time, driver_id);
                    vif.pndng = 0;
                    vif.D_pop = 0;
            end
        end
    endtask
endclass
