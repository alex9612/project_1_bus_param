
class environment #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, parameter bit [7:0] BROADCAST_CODE = 8'hFF);

    // Transactions
    typedef trans_test #(DRVRS) trans_test_t;
    typedef trans_gen #(DRVRS, PCKG_SZ, BROADCAST_CODE) trans_gen_t;
    typedef trans_drv #(DRVRS, PCKG_SZ, BROADCAST_CODE) trans_drv_t;
    typedef trans_mon #(PCKG_SZ) trans_mon_t;
    typedef trans_sb #(PCKG_SZ) trans_sb_t;

    // Match the virtual interface types currently declared in each component
    typedef virtual bus_if #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ)).driver driver_vif_t;
    typedef virtual bus_if #(DRVRS, PCKG_SZ).monitor monitor_vif_t;

    typedef driver #(DRVRS, PCKG_SZ, BROADCAST_CODE) driver_t;
    typedef monitor #(DRVRS, PCKG_SZ, BROADCAST_CODE) monitor_t;

    // Definition of the mailboxes
    mailbox #(trans_test_t) test_gen_mbx;
    mailbox #(sb_cmd_e) test_sb_mbx;
    mailbox #(trans_gen_t) gen_agent_mbx;
    mailbox #(trans_drv_t) agent_drv_mbx[DRVRS];
    mailbox #(trans_drv_t) agent_scb_mbx;
    mailbox #(trans_sb_t) scb_chkr_mbx;
    mailbox #(trans_mon_t) mon_chkr_mbx;

    // Definition of the transactors
    generator #(DRVRS, PCKG_SZ, BROADCAST_CODE) gen;
    Agent #(DRVRS, PCKG_SZ, BROADCAST_CODE) agent;
    scoreboard #(DRVRS, PCKG_SZ, BROADCAST_CODE) scb;
    Checker #(DRVRS, PCKG_SZ, BROADCAST_CODE) chkr;
    // Explicit definition of 1 driver and monitor per device
    driver_t drivers[DRVRS];
    monitor_t monitors[DRVRS];

    function new(driver_vif_t driver_vifs[DRVRS], monitor_vif_t monitor_vifs[DRVRS]);
        // Create each mailbox once and give both endpoints the same handle
        test_gen_mbx = new();
        test_sb_mbx = new();
        gen_agent_mbx = new();
        agent_scb_mbx = new();
        scb_chkr_mbx = new();
        mon_chkr_mbx = new();

        for (int i = 0; i < DRVRS; i++) begin
            // If an interface is not properly connected, stop the simulation
            if (driver_vifs[i] == null)
                $fatal(1, "[Environment] Driver interface %0d was not connected", i);
            if (monitor_vifs[i] == null)
                $fatal(1, "[Environment] Monitor interface %0d was not connected", i);
            agent_drv_mbx[i] = new();
            // Driver constructor params: id, agen_mbx
            drivers[i] = new(i, agent_drv_mbx[i]);
            drivers[i].vif = driver_vifs[i];
            // Monitor constructor params: id, chckr_mbx
            monitors[i] = new(i, mon_chkr_mbx);
            monitors[i].vif = monitor_vifs[i];
        end

        // Create each transactor and assign mbxs
        gen = new(test_gen_mbx, gen_agent_mbx);
        agent = new(gen_agent_mbx, agent_drv_mbx, agent_scb_mbx);
        scb = new(agent_scb_mbx, scb_chkr_mbx, test_sb_mbx);
        chkr = new(mon_chkr_mbx, scb_chkr_mbx);
    endfunction

    task run();
        fork
            gen.run();
            agent.run();
            scb.run();
            chkr.run();
        join_none

        // Create a thread for each driver and monitor -- fixed
        for (int i = 0; i < DRVRS; i++) begin
            automatic int id = i;
            fork
                drivers[id].run();
                monitors[id].run();
            join_none
        end
    endtask

endclass
