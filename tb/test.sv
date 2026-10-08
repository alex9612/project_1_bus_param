
class test #(parameter int DRVRS = 4);
    mailbox #(trans_test #(DRVRS)) mbx_test_to_gen;
    mailbox #(sb_cmd_e) mbx_test_to_sb;

    int unsigned total_trans; // The top uses it to know how many transactions to wait for

    function new(mailbox #(trans_test #(DRVRS)) mbx_test_to_gen, mailbox #(sb_cmd_e) mbx_test_to_sb);
        if (mbx_test_to_gen == null || mbx_test_to_sb == null)
            $fatal(1, "[Test] A required mailbox was not created.");

        this.mbx_test_to_gen = mbx_test_to_gen;
        this.mbx_test_to_sb = mbx_test_to_sb;
    endfunction

    task run();
        trans_test #(DRVRS) request;

        int unsigned max_pending;
        payload_mode_e payload_mode;
        string payload_mode_arg;
        int unsigned broadcast_weight;
        int unsigned min_gap;
        int unsigned max_gap;
        int signed arg_value;
        int signed trans_min_arg;
        int signed trans_max_arg;
        int signed total_min_arg;
        int signed total_max_arg;
        int signed invalid_weight_arg;
        int signed invalid_min_arg;
        int signed invalid_max_arg;
        bit has_min;
        bit has_max;
        bit has_total_min;
        bit has_total_max;
        string source_weights_arg;
        string destination_weights_arg;

        // Default configuration
        total_trans = 100;
        max_pending = DRVRS;
        payload_mode = PAYLOAD_RANDOM;
        broadcast_weight = 50; // 50% of the transactions are broadcast
        min_gap = 0;
        max_gap = 5;

        // Plusargs override defaults
        if ($value$plusargs("TOTAL_TRANS=%d", arg_value)) begin
            if (arg_value < 1) $fatal(1, "[Test] TOTAL_TRANS must be positive");
            total_trans = $unsigned(arg_value);
            $info("[%0t] test: TOTAL_TRANS = %0d", $time, total_trans);
        end
        if ($value$plusargs("MAX_PENDING=%d", arg_value)) begin
            if (arg_value < 1) $fatal(1, "[Test] MAX_PENDING must be positive");
            max_pending = $unsigned(arg_value);
            $info("[%0t] test: MAX_PENDING = %0d", $time, max_pending);
        end
        if ($value$plusargs("BROADCAST_WEIGHT=%d", arg_value)) begin
            if (arg_value < 0) $fatal(1, "[Test] BROADCAST_WEIGHT cannot be negative");
            broadcast_weight = $unsigned(arg_value);
            $info("[%0t] test: BROADCAST_WEIGHT = %0d", $time, broadcast_weight);
        end
        if ($value$plusargs("MIN_GAP=%d", arg_value)) begin
            if (arg_value < 0) $fatal(1, "[Test] MIN_GAP cannot be negative");
            min_gap = $unsigned(arg_value);
            $info("[%0t] test: MIN_GAP = %0d", $time, min_gap);
        end
        if ($value$plusargs("MAX_GAP=%d", arg_value)) begin
            if (arg_value < 0) $fatal(1, "[Test] MAX_GAP cannot be negative");
            max_gap = $unsigned(arg_value);
            $info("[%0t] test: MAX_GAP = %0d", $time, max_gap);
        end
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
        has_min = $value$plusargs("TRANS_MIN=%d", trans_min_arg);
        has_max = $value$plusargs("TRANS_MAX=%d", trans_max_arg);
        has_total_min = $value$plusargs("TOTAL_TRANS_MIN=%d", total_min_arg);
        has_total_max = $value$plusargs("TOTAL_TRANS_MAX=%d", total_max_arg);
        if (has_total_min != has_total_max)
            $fatal(1, "[Test] Provide both TOTAL_TRANS_MIN and TOTAL_TRANS_MAX");
        if (has_total_min) begin
            if (has_min || has_max)
                $fatal(1, "[Test] Choose a global total range OR a per-source range");
            if (total_min_arg < 1 || total_max_arg < total_min_arg)
                $fatal(1, "[Test] Invalid global transaction range");
            // Choose the total once -- the generator receives that chosen count and avoid missmatch totals
            if (!std::randomize(total_trans) with {
                total_trans inside {[total_min_arg:total_max_arg]};
            }) $fatal(1, "[Test] Cannot randomize the global transaction count");
            $display("[Test] TOTAL_TRANS range overrides the fixed count; selected=%0d", total_trans);
        end

        request = new(total_trans, max_pending, payload_mode, broadcast_weight, min_gap, max_gap);
        if ($value$plusargs("SOURCE_WEIGHTS=%s", source_weights_arg))
            request.set_weights(source_weights_arg, 1);
        if ($value$plusargs("DESTINATION_WEIGHTS=%s", destination_weights_arg))
            request.set_weights(destination_weights_arg, 0);

        invalid_weight_arg = 0;
        invalid_min_arg = DRVRS;
        invalid_max_arg = 254;
        void'($value$plusargs("INVALID_WEIGHT=%d", invalid_weight_arg));
        void'($value$plusargs("INVALID_MIN=%d", invalid_min_arg));
        void'($value$plusargs("INVALID_MAX=%d", invalid_max_arg));
        if (invalid_weight_arg < 0 || invalid_min_arg < 0 || invalid_max_arg < 0)
            $fatal(1, "[Test] Invalid destination controls cannot be negative");
        request.invalid_weight = invalid_weight_arg;
        request.invalid_min = invalid_min_arg;
        request.invalid_max = invalid_max_arg;

        if (has_min != has_max) $fatal(1, "[Test] Provide both TRANS_MIN and TRANS_MAX");
        if (has_min) begin
            if (trans_min_arg < 0 || trans_max_arg < trans_min_arg)
                $fatal(1, "[Test] Invalid per-source transaction range");
            request.per_source = 1;
            request.trans_min = trans_min_arg;
            request.trans_max = trans_max_arg;
            total_trans = 0;
            for (int s = 0; s < DRVRS; s++) begin
                request.source_count[s] = 0;
                if (request.source_weights[s] != 0)
                    request.source_count[s] = $urandom_range(trans_max_arg, trans_min_arg);
                total_trans += request.source_count[s];
                $display("[Test] Source %0d will send %0d originals", s, request.source_count[s]);
            end
            request.total_trans = total_trans;
            $display("[Test] Per-source ranges override TOTAL_TRANS; total=%0d", total_trans);
        end
        request.validate();

        $info("[%0t] test: sending configuration to generator", $time);
        mbx_test_to_gen.put(request);
    endtask
 
    // Called by the top when the test is over, asks the scoreboard for its report
    task finish();
        $info("[%0t] Test: asking the scoreboard for the report", $time);
        mbx_test_to_sb.put(SB_REPORT);
    endtask
endclass
