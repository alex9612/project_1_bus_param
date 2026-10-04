
interface bus_if #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16)(
    input logic clk, 
    logic reset
    );
    
    //Inputs driven by Driver
    logic pndng;
    logic [PCKG_SZ-1:0] D_pop;

    //Outputs driven by the DUT
    logic pop;
    logic push;
    logic [PCKG_SZ-1:0] D_push;

    modport driver (input reset, output pndng, output D_pop, input pop, input clk);
    // Monitor is passive, therefore, all signals are inputs from the Monitor perstpective
    modport monitor (input reset, input pndng, input D_pop, input pop, input push, input D_push, input clk);     

endinterface
