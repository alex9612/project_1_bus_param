
class Checker #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, 
                parameter bit [7:0] BROADCAST_CODE = 8'hFF);

    typedef trans_mon #(.PCKG_SZ(PCKG_SZ)) trans_mon_t;
    typedef trans_sb #(.PCKG_SZ(PCKG_SZ)) trans_sb_t;

    typedef mailbox #(trans_mon_t) mon_mbx_t;
    typedef mailbox #(trans_sb_t) scb_mbx_t;

    mon_mbx_t mon_chkr_mbx;
    scb_mbx_t scb_chkr_mbx;

    // typedef bit [PCKG_SZ-1:0] pkt_t;

    // Sync packets received experiment
    trans_sb_t exp_q [DRVRS][$]; // Expected queue: Seq items -- from DUT POP but not PUSH yet
    trans_sb_t req_q [DRVRS][$]; // Requested queue: Seq items planned -- Send by Agent to scb

    // pkt_t expected [DRVRS][$];

    // Counters
    int unsigned n_req;
    int unsigned n_pop;
    int unsigned n_push;
    int unsigned n_ok;
    int unsigned n_error_trans; // Counts the errors related with the transactions generated
    int unsigned n_error_dut; // Counts the errors related with the DUT

    function new(mon_mbx_t mon_chkr_mbx, scb_mbx_t scb_chkr_mbx);
        this.mon_chkr_mbx = mon_chkr_mbx;
        this.scb_chkr_mbx = scb_chkr_mbx;
    endfunction

    task run();
        $display("[%0t] The Checker has been initialized", $time);
        fork 
            get_requests();
            get_monitor_events();
        join
    endtask

    // Manage seq items comming from Agent -> SCB -> Checker 
    // Those are errors related with the generator and not capture before, not the DUT. 
    // For example: Wrong source defined.
    task get_requests();
        trans_sb_t tr;
        forever begin
            scb_chckr_mbx.get(tr);
            if (tr.source >= DRVRS) begin
                $error("[%0t] [Checker] Invalid source %0d", $time, tr.source);
                n_error_trans++;
            end
            if (tr.broadcast && tr.packet[PCKG_SZ-1 -: 8] != BROADCAST_CODE) begin
                $error("[%0t] [Checker] Invalid trasaction %0d, wrong broadcast code %0d", $time, tr.id, tr.packet[PCKG_SZ-1 -: 8]);
                n_error_trans++;
            end
            if (if (tr.source == tr.packet[PCKG_SZ-1 -: 8])) begin
                $error("[%0t] [Checker] Invalid transaction %0d. Source %0d == Destination %0d", $time, tr.id, tr.source, tr.destination);
                n_error_trans++;
            end
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
            case (tr.event_type) // Event observed in monitor
                MON_POP:
                    trans_sb_t expected;
                    int unsigned src;
                    int unsigned dst;
                    src = tr.device_id;
                    n_pop++;
                    
                    // FIRST PART: POP from the DUT match? 
                    // The checker was not expecting that seq item from this source based on the golden ref
                    if (req_q[src].size() == 0) begin
                        $error("[%0t] [Checker] Unexpected POP from device %0d packet=0x%0h", $time, src, tr.packet);
                        n_error_dut++;
                        return;
                    end
                    // First transaction waiting for this source
                    expected = req_q[src].pop_front(); // POPs from the DUT are in order due the FIFO in the source device
                    // Verify that what entered in the DUT is what the Agent sent to the Driver and SCB
                    if (tr.packet !== expected.packet) begin
                        $error("[%0t] [Checker] POP mismatch source=%0d expected=0x%0h actual=0x%0h", $time, src, expected.packet, mon_tr.packet);
                        n_error_dut++;
                    end
                    else begin
                        $display("[%0t] [Checker] POP OK source=%0d packet=0x%0h", $time, src, mon_tr.packet);
                    end

                    // SECOND PART: PUSH from the DUT match? 
                    // In this part, the seq_items in the destination device are not in order, deppends on the DUT trafic and delay
                    if (expected.broadcast) begin // Ask if the transaction accepted by the DUT was broadcast
                        for (int i = 0; i < DRVRS; i++) begin
                            if (i != expected.source)
                                exp_q[i].push_back(expected); // Push the seq_item from broadcast in all queues for each device, excluding source
                        end
                    end
                    else begin // Is not broadcast, then, unicast
                        dst = expected.packet[PCKG_SZ-1:PCKG_SZ-9];
                        if (dst >= DRVRS) begin
                            $error("[%0t] [Checker] Invalid destination %0d", $time, dst);
                            n_error++;
                        end
                        else begin
                            exp_q[dst].push_back(expected);
                        end
                    end
                MON_PUSH:
                    
                MON_RESET:
                    
                default:
                    $warning("[%0t] [Checker] Unknown monitor event", $time);
            endcase
        end
    endtask
endclass
