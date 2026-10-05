
class monitor #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, parameter bit [7:0] BROADCAST_CODE = 8'hFF);
    virtual bus_if #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ)).monitor vif;

    typedef trans_mon #(.PCKG_SZ(PCKG_SZ)) trans_mon_t;
    typedef mailbox #(trans_mon_t) mon_mbx_t;

    mon_mbx_t mon_chkr_mbx;
    int unsigned monitor_id;

    function new(int unsigned monitor_id, mon_mbx_t mon_chkr_mbx);
        this.monitor_id   = monitor_id;
        this.mon_chkr_mbx = mon_chkr_mbx;
    endfunction

    task run();
        trans_mon_t tr;
        $display("[%0t] The Monitor [%0d] has been initialized", $time, monitor_id);
        forever begin
            @(negedge vif.clk); // Reading negedge for the stability of the signals
            if (vif.reset) begin
                tr = new(monitor_id, MON_RESET, '0); // Reset event detected
                mon_chkr_mbx.put(tr);
            end
            else begin
                if (vif.pop) begin
                    tr = new(monitor_id, MON_POP, vif.D_pop);
                    mon_chkr_mbx.put(tr);
                    $display("[%0t] Monitor [%0d]: POP observed, packet=0x%0h", $time, monitor_id, vif.D_pop);
                end
                if (vif.push) begin
                    tr = new(monitor_id, MON_PUSH, vif.D_push);
                    mon_chkr_mbx.put(tr);
                    $display("[%0t] Monitor [%0d]: PUSH observed, packet=0x%0h", $time, monitor_id, vif.D_push);
                end
            end
        end
    endtask
endclass