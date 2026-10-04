
typedef enum {
    PAYLOAD_RANDOM,
    PAYLOAD_SWITCHING // Directed switching patterns defined in the test plan
} payload_mode_e;

// From the test to the generator
// In test, the handler for a trans_test will be called "request;"
class trans_test #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16);
    int unsigned total_trans;

    int unsigned max_pending; // Max value possible is = DRVRS (corner case: all drivers pndng)

    payload_mode_e payload_mode;

    // How many transactions, of total trans, are broadcast
    // Value between 0 and 100.
    int unsigned broadcast_weight;

    // Delay inserted between seq items in gaps
    int unsigned min_gap;
    int unsigned max_gap;

    function new(
        int unsigned total_trans, int unsigned max_pending, 
        payload_mode_e payload_mode, int unsigned broadcast_weight, 
        int unsigned min_gap, int unsigned max_gap);

        this.total_trans = total_trans;
        this.max_pending = max_pending;
        this.payload_mode = payload_mode;
        this.broadcast_weight = broadcast_weight;
        this.min_gap = min_gap;
        this.max_gap = max_gap;

    endfunction

    function void validate();
        if (min_gap > max_gap)
            $fatal(1, "[%0t] trans_test: min_gap exceds max_gap", $time);
        if (broadcast_weight == 100)
            $info("[%0t] trans_test: BROADCAST only mode configured", $time);
        if (broadcast_weight == 0)
            $info("[%0t] trans_test: UNICAST only mode configured", $time);
        if (max_gap == 0 && min_gap == 0)
            $info("[%0t] trans_test: BURST mode configured", $time);

        case (payload_mode)
            PAYLOAD_RANDOM:
                $info("[%0t] trans_test: RANDOM payload mode configured", $time);
            PAYLOAD_SWITCHING:
                $info("[%0t] trans_test: SWITCHING ACTIVITY pattern mode configured", $time);
            default:
                $fatal(1, "[%0t] trans_test: invalid payload mode", $time);
        endcase
    endfunction

endclass

// This transaction is comming from generator -> agent
class trans_gen #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16);
    int unsigned id; // ID of the transaction
    rand int unsigned source; // Metadata
    rand int unsigned destination;
    rand bit [PCKG_SZ-9:0] payload;
    rand int unsigned gap;
    rand bit broadcast;

    time generation_time;
    time issue_time;

    constraint c_source { source < DRVRS; }
    constraint c_destination { destination < DRVRS; }

    function new(int unsigned id);
        this.id = id;
        this.generation_time = $time;
        this.issue_time = 0;
    endfunction

endclass

class trans_drv #();



endclass

class trans_mon #();



endclass

class trans_sb #();



endclass

