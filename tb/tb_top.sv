`timescale 1ns/1ps

// HDL sizes are fixed before simulation. Bash can override these macros
// during compilation; the defaults let us compile without extra defines.
`ifndef DRVRS
    `define DRVRS 4
`endif
`ifndef PCKG_SZ
    `define PCKG_SZ 16
`endif

// Declare the interface and transaction types before the classes that use
// them. Environment is last because it creates the other components.
`include "rtl/Library.sv"
`include "interface.sv"
`include "transaction.sv"
`include "test.sv"
`include "generator.sv"
`include "agent.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "checker.sv"
`include "environment.sv"

module tb_top;
    localparam int BITS = 1;
    localparam int DRVRS = `DRVRS;
    localparam int PCKG_SZ = `PCKG_SZ;
    // Even though it has a broadcast parameter, RTL is hardcoded FF
    localparam bit [7:0] BROADCAST_CODE = 8'hFF;
    localparam int RUN_CYCLES = 500000;

    
    logic clk = 0;
    logic reset = 1;
    always #5 clk = ~clk; // Starting clk 10 ns period

    initial begin
        // Hold reset across multiple clock edges to initialize DUT
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 0;
    end

    // One physical interface per device -- driver and monitor share its signals
    bus_if #(DRVRS, PCKG_SZ) bus_if_i[DRVRS](.clk(clk), .reset(reset));

    wire dut_pndng[BITS-1:0][DRVRS-1:0];
    wire [PCKG_SZ-1:0] dut_D_pop[BITS-1:0][DRVRS-1:0];
    wire dut_pop[BITS-1:0][DRVRS-1:0];
    wire dut_push[BITS-1:0][DRVRS-1:0];
    wire [PCKG_SZ-1:0] dut_D_push[BITS-1:0][DRVRS-1:0];

    // Modports for drivers and monitor
    typedef virtual bus_if #(.PCKG_SZ(PCKG_SZ)).driver driver_vif_t;
    typedef virtual bus_if #(DRVRS, PCKG_SZ).monitor monitor_vif_t;

    // Assigning 1 interface per driver/monitor
    driver_vif_t driver_vifs[DRVRS];
    monitor_vif_t monitor_vifs[DRVRS];
    int unsigned connected = 0;

    for (genvar i = 0; i < DRVRS; i++) begin : devices
        // Bus index 0 is fixed because in this case we are using only 1 bus
        assign dut_pndng[0][i] = bus_if_i[i].pndng;
        assign dut_D_pop[0][i] = bus_if_i[i].D_pop;
        assign bus_if_i[i].pop = dut_pop[0][i];
        assign bus_if_i[i].push = dut_push[0][i];
        assign bus_if_i[i].D_push = dut_D_push[0][i];

        // Verification of the successfull connections is in the env
        initial begin
            driver_vifs[i] = bus_if_i[i];
            monitor_vifs[i] = bus_if_i[i];
            connected++;
        end
    end

    // 
    bs_gnrtr_n_rbtr #(BITS, DRVRS, PCKG_SZ, BROADCAST_CODE) dut (
        .clk(clk), .reset(reset), .pndng(dut_pndng), .D_pop(dut_D_pop),
        .pop(dut_pop), .push(dut_push), .D_push(dut_D_push)
    );

    initial begin
        // Generate fsdb for Verdi debug
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_top);
    end

    initial begin
        environment #(DRVRS, PCKG_SZ, BROADCAST_CODE) env;
        test #(DRVRS) tst;

        // Defining timefortat so display %t values in ns
        $timeformat(-9, 1, " ns", 0);
        // Reject parameter values not intended in this verification
        if (DRVRS < 2 || DRVRS > 10)
            $fatal(1, "[Top] DRVRS must be between 2 and 10");
        if (PCKG_SZ != 16 && PCKG_SZ != 32 && PCKG_SZ != 64)
            $fatal(1, "[Top] PCKG_SZ must be 16, 32 or 64");

        // Wait for all handles before giving them to the environment constructor
        wait (connected == DRVRS);
        env = new(driver_vifs, monitor_vifs);
        // Give the test the mailboxes already created by the environment
        tst = new(env.test_gen_mbx, env.test_sb_mbx);
        // Test and environment execute in threads independently rather than sequentially
        fork
            env.run();
            tst.run();
        join_none

        // "Run phase"
        repeat (RUN_CYCLES) @(posedge clk);
        $display("[Top] Simulation finished");
        $finish;
    end
endmodule
