
interface bus_if #(parameter int BITS = 1, parameter int DRVRS = 4, parameter int PCKG_SZ = 16)(input logic clk);
    logic reset;

    //Inputs driven by the verification environment
    logic pndng [BITS-1:0][DRVRS-1:0];
    logic [PCKG_SZ-1:0] D_pop [BITS-1:0][DRVRS-1:0];

    //Outputs driven by the DUT
    logic pop [BITS-1:0][DRVRS-1:0];
    logic push [BITS-1:0][DRVRS-1:0];
    logic [PCKG_SZ-1:0] D_push [BITS-1:0][DRVRS-1:0];

    modport driver (input reset, output pndng, output D_pop, input pop, input push, input D_push, input clk);
    // Monitor is passive, therefore, all signals are inputs from the Monitor perstpective
    modport monitor (input reset, input pndng, input D_pop, input pop, input push, input D_push, input clk);     

endinterface
