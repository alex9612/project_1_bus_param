
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
    trans_sb_t exp_q [DRVRS][$]; // Testing: Packets take it by the DUT but not arrived yet

    // pkt_t expected [DRVRS][$];

    // Counters
    int unsigned n_req;
    int unsigned n_pop;
    int unsigned n_push;

    function new(mon_mbx_t mon_chkr_mbx, scb_mbx_t scb_chkr_mbx);
        this.mon_chkr_mbx = mon_chkr_mbx;
        this.scb_chkr_mbx = scb_chkr_mbx;
    endfunction

    task run();
        $display("[%0t] The Checker has been initialized", $time);




        
    endtask

endclass
