
class Checker #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, 
                parameter bit [7:0] BROADCAST_CODE = 8'hFF);

    typedef trans_mon #(.PCKG_SZ(PCKG_SZ)) trans_mon_t;
    typedef trans_sb #(.PCKG_SZ(PCKG_SZ)) trans_sb_t;

    typedef mailbox #(trans_mon_t) mon_mbx_t;
    typedef mailbox #(trans_sb_t) scb_mbx_t;

    mon_mbx_t mon_chkr_mbx;
    scb_mbx_t scb_chkr_mbx;

    // Sync packets received experiment
    trans_sb_t exp_q [DRVRS][$]; // Expected queue: Seq items -- packets pending in device n
    trans_sb_t req_q [DRVRS][$]; // Requested queue: Seq items planned -- Send by Agent to scb

    // Counters
    int unsigned n_req;
    int unsigned n_pop;
    int unsigned n_push;
    int unsigned n_ok;
    int unsigned n_error_trans; // Counts the errors related with the transactions generated
    int unsigned n_error_dut; // Counts the errors related with the DUT
    int unsigned n_discard_expected = 0;

    // This is for a specific situation where 2 or more packets are exactly the same at the
    // same time, from dif sources. The checker cannot detect those situations but can flag them
    int unsigned n_duplicate_packets; 
    int unsigned n_latency = 0;
    time sum_latency = 0;
    time min_latency = 0;
    time max_latency = 0;

    function new(mon_mbx_t mon_chkr_mbx, scb_mbx_t scb_chkr_mbx);
        this.mon_chkr_mbx = mon_chkr_mbx;
        this.scb_chkr_mbx = scb_chkr_mbx;
    endfunction

    // Flag 2 or more seq_items at the same time with the same content
    function bit has_duplicate(int unsigned dst, trans_sb_t expected);
        for (int i = 0; i < exp_q[dst].size(); i++) begin
            if (exp_q[dst][i].packet === expected.packet)
                return 1; // Returns a 1 if there is 
        end
        return 0;
    endfunction

    task run();
        $display("[%0t] The Checker has been initialized", $time);
        fork 
            get_requests();
            get_monitor_events();
        join
    endtask

    // Manage seq items comming from Agent -> SCB -> Checker 
    // Those are errors related with the generator and not capture before, not the DUT
    // For example: Wrong source defined
    task get_requests();
        trans_sb_t tr;
        forever begin
            scb_chkr_mbx.get(tr);
            if (tr.source >= DRVRS) begin
                $error("[%0t] [Checker] Invalid source %0d", $time, tr.source);
                n_error_trans++;
            end
            else if (tr.broadcast && tr.packet[PCKG_SZ-1 -: 8] != BROADCAST_CODE) begin
                $error("[%0t] [Checker] Invalid trasaction %0d, wrong broadcast code %0d", $time, tr.id, tr.packet[PCKG_SZ-1 -: 8]);
                n_error_trans++;
            end
            // if (tr.source == tr.packet[PCKG_SZ-1 -: 8]) begin
            //     $error("[%0t] [Checker] Invalid transaction %0d. Source %0d == Destination %0d", $time, tr.id, tr.source, tr.destination); // tr.dest does not exit, check
            //     n_error_trans++;
            // end
            else begin
                req_q[tr.source].push_back(tr);
                n_req++;
                $display("[%0t] [Checker] Request received: source=%0d packet=0x%0h", $time, tr.source, tr.packet);
            end
        end
    endtask

    // Manage seq items observed by the monitors
    task get_monitor_events();
        trans_mon_t tr;
        forever begin
            mon_chkr_mbx.get(tr);
            case (tr.event_type)
                MON_POP: begin
                    // The DUT took a packet from this source. It may still be waiting for the bus
                    trans_sb_t expected;
                    int unsigned src;
                    int unsigned dst;
                    bit duplicate_found;

                    src = tr.device_id; // The monitored device is the source
                    n_pop++;
                    
                    // FIRST PART: Was there a request waiting for this source?
                    // req_q stores what the Agent requested, before the DUT takes it
                    if (req_q[src].size() == 0) begin
                        $error("[%0t] [Checker] Unexpected POP from device %0d packet=0x%0h", $time, src, tr.packet);
                        n_error_dut++;
                        continue; // Keep checking later traffic after this error
                    end
                    // Take and remove the oldest request
                    expected = req_q[src].pop_front();
                    expected.pop_time = tr.event_time; // Start latency at the observed POP
                    // Compare what the monitor saw with what the Agent sent to the Driver and SCB
                    if (tr.packet !== expected.packet) begin
                        $error("[%0t] [Checker] POP mismatch source=%0d expected=0x%0h actual=0x%0h", $time, src, expected.packet, tr.packet);
                        n_error_dut++;
                    end
                    else begin
                        $display("[%0t] [Checker] POP OK source=%0d packet=0x%0h", $time, src, tr.packet);
                    end

                    // SECOND PART: Register where this accepted packet must arrive
                    // exp_q (expected queue) stores pending deliveries, not the actual PUSH events
                    duplicate_found = 0; // Flag for this POP
                    if (expected.broadcast) begin
                        for (int i = 0; i < DRVRS; i++) begin
                            if (i != expected.source) begin
                                if (has_duplicate(i, expected))
                                    duplicate_found = 1; // Flags the previous seq_item was the same packet (same dest + payload)
                                // Store the same object handle in each receivers queue
                                exp_q[i].push_back(expected);
                            end
                        end
                    end
                    else begin // Unicast transaction
                        dst = expected.packet[PCKG_SZ-1-:8];
                        if (dst >= DRVRS) begin
                            // This is an intentional invalid address test
                            n_discard_expected++;
                            $display("[%0t] [Checker] DISCARD expected source=%0d destination=%0d",
                                     $time, src, dst);
                        end
                        else begin
                            if (has_duplicate(dst, expected))
                                duplicate_found = 1; // Flags the previous seq_item was the same packet (same dest + payload)
                            exp_q[dst].push_back(expected); // After the duplicate validation, proceed to push_back the new seq_item
                        end
                    end

                    // This notice reports ambiguous identity -- it does not count as a DUT error
                    if (duplicate_found) begin
                        n_duplicate_packets++; // Count how many times a sequence of two identical transactions was detected 
                        $display("[%0t] [Checker] NOTICE: tr=%0d source=%0d packet=0x%0h matches another pending packet -- individual copies cannot be distinguished. Count=%0d",
                            $time, expected.id, expected.source, expected.packet, n_duplicate_packets);
                    end
                end
                MON_PUSH: begin
                    trans_sb_t expected;
                    int unsigned dst;
                    int unsigned match_idx;
                    bit found;
                    time latency;

                    dst = tr.device_id;
                    n_push++;
                    found = 0;

                    // FIRST PART: Was the checker expecting a PUSH in this destination?
                    if (exp_q[dst].size() == 0) begin
                        $error("[%0t] [Checker] Unexpected PUSH in device %0d packet=0x%0h",
                               $time, dst, tr.packet);
                        n_error_dut++;
                    end
                    else begin
                        // Search the expected packet because transactions in the
                        // destination queue are not necessarily received in order
                        for (int i = 0; i < exp_q[dst].size(); i++) begin
                            if (exp_q[dst][i].packet === tr.packet) begin
                                match_idx = i;
                                found = 1;
                                break;
                            end
                        end
                        if (!found) begin 
                            $error("[%0t] [Checker] PUSH mismatch destination=%0d actual=0x%0h", $time, dst, tr.packet);
                            n_error_dut++;
                        end
                        else begin
                            expected = exp_q[dst][match_idx];
                            latency = tr.event_time - expected.pop_time;
                            if (n_latency == 0 || latency < min_latency) min_latency = latency;
                            if (n_latency == 0 || latency > max_latency) max_latency = latency;
                            n_latency++;
                            n_ok++;
                            sum_latency += latency;
                            exp_q[dst].delete(match_idx);
                            $display("[%0t] [Checker] PUSH OK destination=%0d packet=0x%0h latency=%0t", $time, dst, tr.packet, latency);
                        end
                    end
                end
                MON_RESET: begin
                    int unsigned discarded;

                    discarded = 0;
                    for (int i = 0; i < DRVRS; i++) begin
                        discarded += exp_q[i].size();
                        exp_q[i].delete();
                    end

                    // Reset erases packets accepted into the DUT. Requests
                    // not accepted yet remain in the drivers
                    if (discarded != 0)
                        $display("[%0t] [Checker] RESET: discarded %0d pending deliveries", $time, discarded);
                end
                default:
                    $warning("[%0t] [Checker] Unknown monitor event", $time);
            endcase
        end
    endtask

    // Ivoke from the test.sv
    function void report();
        int unsigned pending_requests;
        int unsigned pending_deliveries;
        int unsigned total_errors;

        pending_requests = 0;
        pending_deliveries = 0;

        // Requests that were registered, but no POP was observed
        foreach (req_q[s]) begin
            foreach (req_q[s][j]) begin
                pending_requests++;
                $error("[Checker] Transaction %0d from device %0d was never taken by the DUT", req_q[s][j].id, s);
            end
        end

        // Packets accepted by the DUT, but still waiting for delivery
        foreach (exp_q[d]) begin
            foreach (exp_q[d][j]) begin
                pending_deliveries++;
                $error("[Checker] Transaction %0d from device %0d never arrived at destination %0d", exp_q[d][j].id, exp_q[d][j].source, d);
            end
        end

        total_errors = n_error_trans + n_error_dut + pending_requests + pending_deliveries;

        $display("[Checker] Requests=%0d POPs=%0d PUSHs=%0d Matched=%0d", n_req, n_pop, n_push, n_ok);
        $display("[Checker] Transaction errors=%0d DUT errors=%0d", n_error_trans, n_error_dut);
        $display("[Checker] Pending requests=%0d Pending deliveries=%0d", pending_requests, pending_deliveries);
        $display("[Checker] Packets matching another pending packet=%0d", n_duplicate_packets);
        $display("[Checker] Total errors=%0d", total_errors);
        $display("[Checker] Invalid originals accepted, expecting no delivery=%0d", n_discard_expected);
        if (n_latency != 0)
            $display("[Checker] POP->PUSH latency: min=%0t avg=%0.2f ns max=%0t samples=%0d", min_latency, real'(sum_latency)/n_latency, max_latency, n_latency);
        $display("[Checker] Identical pending packets use the first matching request; individual latencies can be ambiguous");

        if (total_errors == 0)
            $display("[Checker] PASS");
        else
            $display("[Checker] FAIL");
    endfunction
endclass
