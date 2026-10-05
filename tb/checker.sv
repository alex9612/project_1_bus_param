
class Checker #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, 
                parameter bit [7:0] BROADCAST_CODE = 8'hFF, parameter bit BCAST_TO_SOURCE = 0);

    typedef trans_mon #(.PCKG_SZ(PCKG_SZ)) trans_mon_t;
    typedef trans_sb #(.PCKG_SZ(PCKG_SZ)) trans_sb_t;

    typedef mailbox #(trans_mon_t) mon_mbx_t;
    typedef mailbox #(trans_sb_t) scb_mbx_t;

    mon_mbx_t mon_chkr_mbx;
    scb_mbx_t scb_chkr_mbx;

    // typedef bit [PCKG_SZ-1:0] pkt_t;

    // Sync packets received experiment
    trans_sb_t exp_q [DRVRS][$]; // Seq items -- from DUT POP but not PUSH yet
    trans_sb_t req_q [DRVRS][$]; // Seq items planned -- Send by Agent to scb

    // pkt_t expected [DRVRS][$];

    // Counters
    int unsigned n_req;
    int unsigned n_pop;
    int unsigned n_push;
    int unsigned n_ok;
    int unsigned n_error;

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
                n_error++;
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

    endtask

endclass
