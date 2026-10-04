
typedef enum { 
    UNICAST,
    BROADCAST
} packet_type_e;

class Transaction #(parameter int PCKG_SZ = 16, parameter int MAX_DEVICES = 10);

    rand int unsigned source;
    rand bit [7:0] destination;
    rand bit [PCKG_SZ-9:0] payload;
    rand int unsigned delay;
    rand packet_type_e packet_type;

    // Testbench configuration information
    int unsigned num_devices;
    bit [7:0] broadcast_code;

    // Transaction tracking/statistics
    int unsigned id;
    time send_time;
    time receive_time;

    // Constraints
    constraint valid_num_devices_c {
        num_devices >= 1;
        num_devices <= MAX_DEVICES;
    }

    constraint valid_source {
        source < num_devices;
    }

    constraint valid_destination {
        if (packet_type == UNICAST) {
            destination < num_devices;
            destination != source;
        }
        if (packet_type == BROADCAST) {
            destination == broadcast_code;
        }
    }

    function new(int unsigned num_devices, bit [7:0] broadcast_code);
        this.num_devices    = num_devices; // If not declared, can lead an error due the default num_devices value is 0
        this.broadcast_code = broadcast_code;

        this.id           = 0;
        this.send_time    = 0;
        this.receive_time = 0;

    endfunction

    function bit [PCKG_SZ-1:0] get_packet();
        return {destination, payload};
    endfunction

    function Transaction #(.PCKG_SZ(PCKG_SZ), .MAX_DEVICES(MAX_DEVICES)) copy();
        Transaction #(.PCKG_SZ(PCKG_SZ), .MAX_DEVICES(MAX_DEVICES)) tr_copy;

        tr_copy = new(num_devices, broadcast_code);
        tr_copy.source = source;
        tr_copy.destination = destination;
        tr_copy.payload = payload;
        tr_copy.delay = delay;
        tr_copy.packet_type = packet_type;
        tr_copy.id = id;
        tr_copy.send_time = send_time;
        tr_copy.receive_time = receive_time;

        return tr_copy;
    endfunction

endclass

// From the test to the generator
// In test, the handler for a trans_test will be called "request;"
class trans_test;
    int packets_min;
    int packets_max;

    // How many transactions, of total trans, are broadcast
    // Value between 0 and 1.
    int broadcast_weight;

    // Delay inserted between seq items in gaps
    int min_gap;
    int max_gap;

    function void validate();
        if (packet_min > packets_max)
            $fatal(1, "[%0t] trans_test: packets_min exceds packets_max", $time);
        if (min_gap > max_gap)
            $fatal(1, "[%0t] trans_test: packets_min exceds packets_max", $time);
        if (broadcast_weight == 1)
            $info("[%0t] trans_test: BROADCAST only mode configured", $time);
        if (broadcast_weight == 0)
            $info("[%0t] trans_test: UNICAST only mode configured", $time);
        if (max_gap - min_gap == 0)
            $info("[%0t] trans_test: Burst mode configured", $time);
    endfunction

endclass

class trans_gen #();
    int id;
    int source;
    rand bit [7:0] destination;
    rand payload

endclass

class trans_drv #();



endclass

class trans_mon #();



endclass

class trans_gen #();



endclass

class trans_sb #();



endclass

