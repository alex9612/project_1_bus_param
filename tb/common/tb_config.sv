
class TbConfig(parameter int BITS = 1, parameter int DRVRS = 4, parameter int PCKG_SZ = 16,
                parameter bit [7:0] BROADCAST_CODE = 8'hFF, parameter int MAX_DEVICES = 10);

    // DUT elaboration config
    int unsigned num_buses;
    int unsigned num_devices;
    int unsigned packet_size;
    bit [7:0] broadcast_code;

    // FIFO configuration
    rand int unsigned fifo_depth;
    int unsigned min_fifo_depth;
    int unsigned max_fifo_depth;

    // Simulation control
    int unsigned timeout_cycles;

    // Constraints
    constraint fifo_depth_c {
        fifo_depth >= min_fifo_depth;
        fifo_depth <= max_fifo_depth;
    }

    function new();
        num_buses      = BITS;
        num_devices    = DRVRS;
        packet_size    = PCKG_SZ;
        broadcast_code = BROADCAST_CODE;

        // Equal limits keep the depth fixed until a test changes them.
        min_fifo_depth = 16;
        max_fifo_depth = 16;
        fifo_depth     = 16;

        timeout_cycles = 100000;

    endfunction

    // Configuration validation
    function void validate();

        if (BITS != 1)
            $fatal(1, "[TbConfig] This environment uses exactly one bus.");

        if (DRVRS < 2)
            $fatal(1, "[TbConfig] DRVRS must be at least 2 for unicast traffic.");

        if (DRVRS > MAX_DEVICES)
            $fatal(1, "[TbConfig] DRVRS (%0d) exceeds MAX_DEVICES (%0d).", DRVRS, MAX_DEVICES);

        if ((PCKG_SZ != 16) && (PCKG_SZ != 32) && (PCKG_SZ != 64))
            $fatal(1, "[TbConfig] PCKG_SZ must be 16, 32 or 64 bits.");

        if (PCKG_SZ < 9)
            $fatal(1, "[TbConfig] PCKG_SZ must be at least 9 bits.");

        if (min_fifo_depth < 1)
            $fatal(1, "[TbConfig] min_fifo_depth must be greater than 0.");

        if (min_fifo_depth > max_fifo_depth)
            $fatal(1, "[TbConfig] min_fifo_depth cannot be greater than max_fifo_depth.");
        
        if (fifo_depth < min_fifo_depth || fifo_depth > max_fifo_depth) 
            $fatal(1, "[TbConfig] fifo_depth (%0d) is outside the allowed range [%0d:%0d].", fifo_depth, min_fifo_depth, max_fifo_depth);

        if (timeout_cycles == 0) 
            $fatal(1, "[TbConfig] timeout_cycles must be greater than 0.");
        
    endfunction

    function void print();
        $display("");
        $display("------------- TESTBENCH CONFIGURATION -------------");
        $display("BITS                  = %0d", num_buses);
        $display("DRVRS                 = %0d", num_devices);
        $display("PCKG_SZ               = %0d", packet_size);
        $display("BROADCAST_CODE        = 0x%02h", broadcast_code);

        $display("FIFO depth            = %0d", fifo_depth);
        $display("FIFO depth range      = [%0d:%0d]",
                 min_fifo_depth, max_fifo_depth);
        $display("Timeout               = %0d cycles",
                 timeout_cycles);

        $display("----------------------------------------------------");
        $display("");
    endfunction

endclass