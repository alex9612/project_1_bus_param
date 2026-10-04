
// class test #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16);
class test #(parameter int DRVRS = 4);

    mailbox #(trans_test #(DRVRS)) mbx_test_to_gen;

    function new(mailbox #(trans_test #(DRVRS)) mbx_test_to_gen);
        this.mbx_test_to_gen = mbx_test_to_gen;
    endfunction

    task run();
        trans_test #(DRVRS) request;

        int unsigned total_trans;
        int unsigned max_pending;
        payload_mode_e payload_mode;
        string payload_mode_arg;
        int unsigned broadcast_weight;
        int unsigned min_gap;
        int unsigned max_gap;

        // Default configuration
        total_trans = 100;
        max_pending = DRVRS;
        payload_mode = PAYLOAD_RANDOM;
        broadcast_weight = 50; // 50% of the transactions are broadcast
        min_gap = 0;
        max_gap = 5;

        // Plusargs override defaults
        if ($value$plusargs("TOTAL_TRANS=%d", total_trans))
            $info("[%0t] test: TOTAL_TRANS = %0d", $time, total_trans);

        if ($value$plusargs("MAX_PENDING=%d", max_pending))
            $info("[%0t] test: MAX_PENDING = %0d", $time, max_pending);

        if ($value$plusargs("BROADCAST_WEIGHT=%d", broadcast_weight))
            $info("[%0t] test: BROADCAST_WEIGHT = %0d", $time, broadcast_weight);

        if ($value$plusargs("MIN_GAP=%d", min_gap))
            $info("[%0t] test: MIN_GAP = %0d", $time, min_gap);

        if ($value$plusargs("MAX_GAP=%d", max_gap))
            $info("[%0t] test: MAX_GAP = %0d", $time, max_gap);

        if ($value$plusargs("PAYLOAD_MODE=%s", payload_mode_arg)) begin
            case (payload_mode_arg)
                "RANDOM":
                    payload_mode = PAYLOAD_RANDOM;
                "SWITCHING":
                    payload_mode = PAYLOAD_SWITCHING;
                default:
                    $fatal(1,"[%0t] test: invalid PAYLOAD_MODE = %s", $time, payload_mode_arg);
            endcase
        end

        request = new(
            total_trans,
            max_pending,
            payload_mode,
            broadcast_weight,
            min_gap,
            max_gap
        );

        request.validate();
        $info("[%0t] test: sending configuration to generator", $time);

        mbx_test_to_gen.put(request);
    endtask

endclass