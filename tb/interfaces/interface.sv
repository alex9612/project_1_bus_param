
interface bus_if #(parameter int BITS = 1, parameter int DRVRS = 4, parameter int PCKG_SZ = 16)(
    input logic clk
);

    logic reset;

    //Inputs driven by the verification environment
    logic pndng [BITS-1:0][DRVRS-1:0];
    logic [PCKG_SZ-1:0] D_pop [BITS-1:0][DRVRS-1:0];

    //Outputs driven by the DUT
    logic pop [BIS-1:0][DRVRS-1:0];
    logic push [BITS-1:0][DRVRS-1:0];
    logic [PCKG_SZ-1:0] D_push [BITS-1:0][DRVRS-1:0];

endinterface
