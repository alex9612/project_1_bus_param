
class scoreboard #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16,
                   parameter bit [7:0] BROADCAST_CODE = 8'hFF);

    typedef trans_drv #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans_drv_t;
    typedef trans_sb #(.PCKG_SZ(PCKG_SZ)) trans_sb_t;

    typedef mailbox #(trans_drv_t) agent_mbx_t;
    typedef mailbox #(trans_sb_t) chkr_mbx_t;
    typedef mailbox #(sb_cmd_e) test_mbx_t;

    agent_mbx_t agent_scb_mbx; // Transactions from the agent
    chkr_mbx_t scb_chkr_mbx;  // Transactions for the checker
    test_mbx_t test_scb_mbx;  // Commands from the test

    trans_sb_t historial[$];   // Every transaction received
    int unsigned n_unicast;
    int unsigned n_broadcast;
    int unsigned n_per_source[DRVRS];

    function new(agent_mbx_t agent_scb_mbx, chkr_mbx_t scb_chkr_mbx, test_mbx_t test_scb_mbx);
        this.agent_scb_mbx = agent_scb_mbx;
        this.scb_chkr_mbx = scb_chkr_mbx;
        this.test_scb_mbx = test_scb_mbx;
    endfunction

    task run();
        // trans_drv_t tr;
        // trans_sb_t sb_tr;
        // sb_cmd_e cmd;
        $display("[%0t] The Scoreboard has been initialized", $time);

        fork
            get_transactions();
            get_commands();
        join
    endtask
    
    task get_transactions();
        trans_drv_t tr;
        trans_sb_t sb_tr;
        sb_cmd_e cmd;

        forever begin
            agent_scb_mbx.get(tr);
            sb_tr = new(tr.id, tr.source, tr.packet, tr.broadcast, tr.generation_time);
            historial.push_back(sb_tr);

            if (tr.broadcast) 
                n_broadcast++;
            else
                n_unicast++;
            
            n_per_source //










            if (agent_scb_mbx.num() > 0) begin
                agent_scb_mbx.get(tr);
                sb_tr = new(tr.id, tr.source, tr.packet, tr.broadcast, tr.generation_time);
                historial.push_back(sb_tr);
                if (tr.broadcast)
                    n_broadcast++;
                else
                    n_unicast++;
                n_per_source[tr.source]++;
                scb_chkr_mbx.put(sb_tr);
            end
            if (test_scb_mbx.num() > 0) begin
                test_scb_mbx.get(cmd);
                case (cmd)
                    SB_REPORT: begin
                        $display("[%0t] [Scoreboard] Total=%0d Unicast=%0d Broadcast=%0d", $time, 
                                historial.size(), n_unicast, n_broadcast);
                        foreach (n_per_source[i])
                            $display("[Scoreboard] Device %0d sent %0d transactions", i, n_per_source[i]);
                    end
                    default:
                        $warning("[%0t] [Scoreboard] Unknown command received", $time);
                endcase
            end
            #1;
        end
    endtask
endclass