// Temporary top for checking the stimulus path.
// The interface and driver each see one device; only this top maps DUT array indices.

`timescale 1ns/1ps

`include "rtl/Library.sv"
`include "interface.sv"
`include "transaction.sv"
`include "test.sv"
`include "driver.sv"
`include "generator.sv"
`include "agent.sv"

module tb_top;
    localparam int BITS = 1;
    localparam int DRVRS = 8;
    localparam int PCKG_SZ = 16;
    localparam bit [7:0] BROADCAST_CODE = 8'hFF;
    localparam int TIMEOUT_CYCLES = 20000;

    logic clk = 0;
    logic reset;

    always #5 clk = ~clk;

    initial begin
        reset = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
    end

    // One scalar interface for each device.
    bus_if #(.PCKG_SZ(PCKG_SZ)) bus_if_i[DRVRS] (
        .clk(clk),
        .reset(reset)
    );

    // The DUT still uses [bus][device] arrays. Only this top knows that layout.
    logic dut_pndng[BITS-1:0][DRVRS-1:0];
    logic [PCKG_SZ-1:0] dut_D_pop[BITS-1:0][DRVRS-1:0];
    logic dut_pop[BITS-1:0][DRVRS-1:0];
    logic dut_push[BITS-1:0][DRVRS-1:0];
    logic [PCKG_SZ-1:0] dut_D_push[BITS-1:0][DRVRS-1:0];

    typedef virtual bus_if #(.PCKG_SZ(PCKG_SZ)).driver driver_vif_t;
    driver_vif_t driver_vifs[DRVRS];
    int vifs_set = 0;

    for (genvar g = 0; g < DRVRS; g++) begin : g_device
        assign dut_pndng[0][g] = bus_if_i[g].pndng;
        assign dut_D_pop[0][g] = bus_if_i[g].D_pop;

        assign bus_if_i[g].pop = dut_pop[0][g];
        assign bus_if_i[g].push = dut_push[0][g];
        assign bus_if_i[g].D_push = dut_D_push[0][g];

        // A class cannot index an interface instance array with a runtime int.
        initial begin
            driver_vifs[g] = bus_if_i[g];
            vifs_set++;
        end
    end

    bs_gnrtr_n_rbtr #(
        .bits(BITS),
        .drvrs(DRVRS),
        .pckg_sz(PCKG_SZ),
        .broadcast(BROADCAST_CODE)
    ) dut (
        .clk(clk),
        .reset(reset),
        .pndng(dut_pndng),
        .push(dut_push),
        .pop(dut_pop),
        .D_pop(dut_D_pop),
        .D_push(dut_D_push)
    );

    typedef trans_test #(DRVRS) trans_test_t;
    typedef trans_gen #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ),
                        .BROADCAST_CODE(BROADCAST_CODE)) trans_gen_t;
    typedef trans_drv #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ),
                        .BROADCAST_CODE(BROADCAST_CODE)) trans_drv_t;

    typedef test #(DRVRS) test_t;
    typedef generator #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ),
                        .BROADCAST_CODE(BROADCAST_CODE)) generator_t;
    typedef Agent #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ),
                    .BROADCAST_CODE(BROADCAST_CODE)) agent_t;
    typedef driver #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ),
                     .BROADCAST_CODE(BROADCAST_CODE)) driver_t;

    initial begin
`ifdef FSDB
        $fsdbDumpfile("smoke.fsdb");
        $fsdbDumpvars(0, tb_top, "+all");
`elsif VCD
        $dumpfile("smoke.vcd");
        $dumpvars(0, tb_top);
`endif
    end

    initial begin
        test_t tst;
        generator_t gen;
        agent_t agent;
        driver_t drivers[DRVRS];

        mailbox #(trans_test_t) test_gen_mbx;
        mailbox #(trans_test_t) test_sb_mbx;
        mailbox #(trans_gen_t) gen_agent_mbx;
        mailbox #(trans_drv_t) agent_drv_mbx[DRVRS];
        mailbox #(trans_drv_t) agent_scb_mbx;

        trans_test_t request;
        trans_drv_t expected;
        int unsigned completed = 0;

        wait (vifs_set == DRVRS);

        test_gen_mbx = new();
        test_sb_mbx = new();
        gen_agent_mbx = new();
        agent_scb_mbx = new();

        for (int i = 0; i < DRVRS; i++)
            agent_drv_mbx[i] = new();

        tst = new(test_gen_mbx, test_sb_mbx);
        gen = new(test_gen_mbx, gen_agent_mbx);
        agent = new(gen_agent_mbx, agent_drv_mbx, agent_scb_mbx);

        for (int i = 0; i < DRVRS; i++) begin
            drivers[i] = new(i, agent_drv_mbx[i]);
            drivers[i].vif = driver_vifs[i];
            drivers[i].drv_done = agent.drv_done[i];
        end

        // Completions can arrive in any device order, so count them independently.
        for (int i = 0; i < DRVRS; i++) begin
            automatic int id = i;
            fork
                forever begin
                    @(agent.drv_done[id]);
                    completed++;
                end
            join_none
        end

        #0; // Let all completion listeners start before traffic is generated.

        fork
            tst.run();
            gen.run();
            agent.run();
        join_none

        for (int i = 0; i < DRVRS; i++) begin
            automatic int id = i;
            fork
                drivers[id].run();
            join_none
        end

        test_sb_mbx.get(request);

        // Planned transactions may complete out of order across devices.
        for (int unsigned i = 0; i < request.total_trans; i++)
            agent_scb_mbx.get(expected);

        wait (completed == request.total_trans);

        $display("[%0t] Stimulus handoff completed for %0d transactions",
                 $time, request.total_trans);
        $finish;
    end

    initial begin
        repeat (TIMEOUT_CYCLES) @(posedge clk);
        $fatal(1, "Smoke test timed out");
    end
endmodule
