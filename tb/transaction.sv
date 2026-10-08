
typedef enum {
    PAYLOAD_RANDOM,
    PAYLOAD_SWITCHING // Directed switching patterns defined in the test plan
} payload_mode_e;

// From the test to the generator
// In test, the handler for a trans_test will be called "request;"
class trans_test #(parameter int DRVRS = 4);
    int unsigned total_trans;
    int unsigned max_pending; // Max value possible is = DRVRS (corner case: all drivers pndng)
    payload_mode_e payload_mode;

    // How many transactions, of total trans, are broadcast
    // Value between 0 and 100.
    int unsigned broadcast_weight;

    // Delay inserted between seq items in gaps
    int unsigned min_gap;
    int unsigned max_gap;
    int unsigned source_weights[10];
    int unsigned destination_weights[10];
    bit per_source;
    int unsigned trans_min;
    int unsigned trans_max;
    int unsigned source_count[DRVRS];
    int unsigned invalid_weight;
    int unsigned invalid_min;
    int unsigned invalid_max;

    function new(int unsigned total_trans, int unsigned max_pending, 
                 payload_mode_e payload_mode, int unsigned broadcast_weight, 
                 int unsigned min_gap, int unsigned max_gap);

        this.total_trans = total_trans;
        this.max_pending = max_pending;
        this.payload_mode = payload_mode;
        this.broadcast_weight = broadcast_weight;
        this.min_gap = min_gap;
        this.max_gap = max_gap;
        invalid_weight = 0;
        invalid_min = DRVRS;
        invalid_max = 254; // FF remains the fixed broadcast code
        for (int i = 0; i < 10; i++) begin
            source_weights[i] = (i < DRVRS) ? 1000 : 0;
            destination_weights[i] = (i < DRVRS) ? 1000 : 0;
        end
    endfunction

    // Enter weights as 0..1, one value per device
    function void set_weights(string text, bit sources);
        real values[10];
        int count;
        int unsigned weight;
        count = $sscanf(text, "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f",
                        values[0], values[1], values[2], values[3], values[4],
                        values[5], values[6], values[7], values[8], values[9]);
        if (count != DRVRS)
            $fatal(1, "[Test] Weight list needs exactly %0d values", DRVRS);
        for (int i = 0; i < DRVRS; i++) begin
            if (values[i] < 0.0 || values[i] > 1.0)
                $fatal(1, "[Test] Weights must be between 0 and 1");
            weight = $rtoi(values[i] * 1000.0 + 0.5);
            if (values[i] > 0.0 && weight == 0)
                $fatal(1, "[Test] Smallest positive weight is 0.001");
            if (sources) source_weights[i] = weight;
            else destination_weights[i] = weight;
        end
    endfunction

    function void validate();
        int unsigned source_sum;
        bit valid_receiver;
        source_sum = 0;
        for (int s = 0; s < DRVRS; s++) begin
            source_sum += source_weights[s];
            if (source_weights[s] != 0 && (!per_source || source_count[s] != 0) &&
                broadcast_weight < 100 && invalid_weight < 100) begin
                valid_receiver = 0;
                for (int d = 0; d < DRVRS; d++)
                    if (d != s && destination_weights[d] != 0) valid_receiver = 1;
                if (!valid_receiver)
                    $fatal(1, "[Test] Source %0d has no eligible unicast destination", s);
            end
        end
        if (source_sum == 0) $fatal(1, "[Test] At least one source weight must be positive");
        if (total_trans == 0) $fatal(1, "[Test] Total transaction count must be positive");
        if (per_source && trans_min > trans_max)
            $fatal(1, "[Test] TRANS_MIN exceeds TRANS_MAX");
        if (invalid_weight > 100) $fatal(1, "[Test] INVALID_WEIGHT must be 0..100");
        if (invalid_weight != 0 && (invalid_min < DRVRS || invalid_max > 255 ||
            invalid_min > invalid_max || invalid_min == 255))
            $fatal(1, "[Test] Invalid destination range must be outside devices and contain a value other than FF");
        if (min_gap > max_gap)
            $fatal(1, "[%0t] trans_test: min_gap exceeds max_gap", $time);
        if (max_pending < 1 || max_pending > DRVRS)
            $fatal(1, "[%0t] trans_test: max_pending must be between 1 and %0d", $time, DRVRS);
        if (broadcast_weight > 100)
            $fatal(1, "[%0t] trans_test: broadcast_weight must be between 0 and 100", $time);
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

// This transaction is comming from generator -> agent. The eight-bit destination is the header.
class trans_gen #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, 
                  parameter bit [7:0] BROADCAST_CODE = 8'hFF);
    int unsigned id; // ID of the transaction
    rand int unsigned source; // Metadata
    rand bit [7:0] destination;
    rand bit [PCKG_SZ-9:0] payload;
    rand int unsigned gap;
    rand bit broadcast;
    rand bit invalid_destination;
    time generation_time;

    constraint c_source { source < DRVRS; }
    // There was an error that if broadcast mode was enabled, then the destination was uknown
    constraint c_destination {
        solve invalid_destination before broadcast;
        solve broadcast before destination;
        if (invalid_destination) {
            broadcast == 0;
            destination inside {[DRVRS:255]};
            destination != BROADCAST_CODE;
        }
        else if (broadcast)
            destination == BROADCAST_CODE;
        else {
            destination < DRVRS;
            destination != source;
        }
    }
    function new(int unsigned id);
        this.id = id;
        this.generation_time = $time;
    endfunction

    function bit [PCKG_SZ-1:0] get_packet();
        return {destination, payload};
    endfunction

endclass

// From the agent to drivers -- Agent sent a copy of trans_drv to scb
class trans_drv #(parameter int unsigned DRVRS = 4, parameter int unsigned PCKG_SZ = 16,
                  parameter bit [7:0] BROADCAST_CODE = 8'hFF);
    int unsigned id;
    int unsigned source; // Metadata
    bit [PCKG_SZ-1:0] packet;
    int unsigned gap;
    bit broadcast;
    time generation_time;

    function new(trans_gen #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) request);
        this.id = request.id;
        this.source = request.source;
        this.packet = request.get_packet();
        this.gap = request.gap;
        this.broadcast = request.broadcast;
        this.generation_time = request.generation_time;
    endfunction

endclass

typedef enum {
    MON_POP,
    MON_PUSH,
    MON_RESET
} monitor_event_e;

// From the monitor to checker
class trans_mon #(parameter int unsigned PCKG_SZ = 16);
    int unsigned device_id;
    monitor_event_e event_type;
    bit [PCKG_SZ-1:0] packet;
    time event_time;

    function new(int unsigned device_id, monitor_event_e event_type, bit [PCKG_SZ-1:0] packet = '0);
        this.device_id = device_id;
        this.event_type = event_type;
        this.packet = packet;
        this.event_time = $time;
    endfunction

endclass

typedef enum { SB_REPORT } sb_cmd_e;

// From the sb to checker
class trans_sb #(parameter int unsigned PCKG_SZ = 16);
    int unsigned id;
    int unsigned source;
    bit [PCKG_SZ-1:0] packet;
    bit broadcast;
    time generation_time;
    time pop_time; // This is filled by the checker when the DUT takes the packet -- latency calc
 
    function new(int unsigned id, int unsigned source, bit [PCKG_SZ-1:0] packet,
                 bit broadcast, time generation_time);
        this.id = id;
        this.source = source;
        this.packet = packet;
        this.broadcast = broadcast;
        this.generation_time = generation_time;
        this.pop_time = 0;
    endfunction
endclass

