
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

        // Default configuration
        total_trans = 100;
        max_pending = DRVRS;
        payload_mode = PAYLOAD_RANDOM;
        broadcast_weight = 50; // 50% of the transactions are broadcast
        min_gap = 0;
        max_gap = 5;

        // Plusargs override defaults
        if ($value$plusargs("TOTAL_TRANS=%d", arg_value)) begin
            total_trans = $unsigned(arg_value);
            $info("[%0t] test: TOTAL_TRANS = %0d", $time, total_trans);
        end
        if ($value$plusargs("MAX_PENDING=%d", arg_value)) begin
            max_pending = $unsigned(arg_value);
            $info("[%0t] test: MAX_PENDING = %0d", $time, max_pending);
        end
        if ($value$plusargs("BROADCAST_WEIGHT=%d", arg_value)) begin
            broadcast_weight = $unsigned(arg_value);
            $info("[%0t] test: BROADCAST_WEIGHT = %0d", $time, broadcast_weight);
        end
        if ($value$plusargs("MIN_GAP=%d", arg_value)) begin
            min_gap = $unsigned(arg_value);
            $info("[%0t] test: MIN_GAP = %0d", $time, min_gap);
        end
        if ($value$plusargs("MAX_GAP=%d", arg_value)) begin
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
        request = new(total_trans, max_pending, payload_mode, broadcast_weight, min_gap, max_gap);
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
 