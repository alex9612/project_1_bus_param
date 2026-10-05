
class Checker #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, 
                parameter bit [7:0] BROADCAST_CODE = 8'hFF, parameter bit BCAST_TO_SOURCE = 0);

    typedef trans_mon #(.PCKG_SZ(PCKG_SZ)) trans_mon_t;
    typedef mailbox #(trans_mon_t) mon_mbx_t;
    typedef bit [PCKG_SZ-1:0] pkt_t;

    mon_mbx_t mon_chkr_mbx;
    pkt_t expected [DRVRS][$];

endclass
