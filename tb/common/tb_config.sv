
class TbConfig(parameter int BITS = 1, parameter int DRVRS = 4, parameter int PCKG_SZ = 16,
                parameter bit [7:0] BROADCAST_CODE = 8'hFF, parameter int MAX_DEVICES = 10);

    // --------------------------------------------------
    // DUT / elaboration configuration
    // Runtime copies of the parameters above
    // --------------------------------------------------

    int unsigned num_buses;
    int unsigned num_devices;
    int unsigned packet_size;

    bit [7:0] broadcast_code;

    // FIFO configuration
    rand int unsigned fifo_depth;

    int unsigned min_fifo_depth;
    int unsigned max_fifo_depth;

    // Traffic generation configuration
    int unsigned min_delay;
    int unsigned max_delay;

    int unsigned min_transactions;
    int unsigned max_transactions;

    // Simulation control
    int unsigned timeout_cycles;


    // Constraints
    constraint fifo_depth_c {
        fifo_depth >= min_fifo_depth;
        fifo_depth <= max_fifo_depth;
    }

    function new();

        // Copy elaboration-time parameters
        num_buses      = BITS;
        num_devices    = DRVRS;
        packet_size    = PCKG_SZ;
        broadcast_code = BROADCAST_CODE;

        // Default FIFO configuration
        //
        // By default min == max, so fifo_depth is effectively
        // fixed. A test can modify this range before randomizing
        // the configuration.
        min_fifo_depth = 16;
        max_fifo_depth = 16;
        fifo_depth     = 16;

        // Default transaction delay range
        min_delay = 0;
        max_delay = 20;

        // Default number of transactions generated per device
        min_transactions = 3;
        max_transactions = 100;

        // Maximum simulation time before declaring a timeout
        timeout_cycles = 100000;

    endfunction

    // Configuration validation
    function void validate();

        if (BITS < 1) begin
            $fatal(1,
                "[TbConfig] BITS must be greater than or equal to 1."
            );
        end

        if (DRVRS < 1) begin
            $fatal(1,
                "[TbConfig] DRVRS must be greater than or equal to 1."
            );
        end

        if (DRVRS > MAX_DEVICES) begin
            $fatal(1,
                "[TbConfig] DRVRS (%0d) exceeds MAX_DEVICES (%0d).",
                DRVRS,
                MAX_DEVICES
            );
        end

        if (PCKG_SZ < 9) begin
            $fatal(1,
                "[TbConfig] PCKG_SZ must be at least 9 bits."
            );
        end

        if (min_fifo_depth < 1) begin
            $fatal(1,
                "[TbConfig] min_fifo_depth must be greater than 0."
            );
        end

        if (min_fifo_depth > max_fifo_depth) begin
            $fatal(1,
                "[TbConfig] min_fifo_depth cannot be greater than max_fifo_depth."
            );
        end

        if (fifo_depth < min_fifo_depth ||
            fifo_depth > max_fifo_depth) begin

            $fatal(1,
                "[TbConfig] fifo_depth (%0d) is outside the allowed range [%0d:%0d].",
                fifo_depth,
                min_fifo_depth,
                max_fifo_depth
            );
        end

        if (min_delay > max_delay) begin
            $fatal(1,
                "[TbConfig] min_delay cannot be greater than max_delay."
            );
        end

        if (min_transactions > max_transactions) begin
            $fatal(1,
                "[TbConfig] min_transactions cannot be greater than max_transactions."
            );
        end

        if (timeout_cycles == 0) begin
            $fatal(1,
                "[TbConfig] timeout_cycles must be greater than 0."
            );
        end

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

        $display("Transaction delay     = [%0d:%0d] cycles",
                 min_delay, max_delay);

        $display("Transactions/device   = [%0d:%0d]",
                 min_transactions, max_transactions);

        $display("Timeout               = %0d cycles",
                 timeout_cycles);

        $display("----------------------------------------------------");
        $display("");

    endfunction

endclass