
class Generator #(parameter int BITS = 1, parameter int DRVRS = 4, parameter int PCKG_SZ = 16, 
                    parameter bit [7:0] BROADCAST_CODE = 8'hFF, parameter int MAX_DEVICES = 10);

    typedef Transaction #(.PCKG_SZ(PCKG_SZ), .MAX_DEVICES(MAX_DEVICES)) transaction_t;
    typedef TbConfig #(.BITS(BITS), .DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE), .MAX_DEVICES(MAX_DEVICES)) config_t;
    typedef mailbox #(transaction_t) transaction_mbx_t;

    config_t cfg;
    transaction_mbx_t gen_agent_mbx;
    int unsigned next_id;

    function new(config_t cfg, mailbox #(transaction_t) gen_agent_mbx);
        this.cfg = cfg;
        this.gen_agent_mbx = gen_agent_mbx;
        this.next_id = 0;
    endfunction

    task generate_unicast(int unsigned source);
        transaction_t tr;

        tr = new(cfg.num_devices, cfg.broadcast_code);

        if (!tr.randomize() with {
            packet_type == UNICAST;
            source == local::source;
            delay inside {[cfg.min_delay:cfg.max_delay]};
        }) begin
            $fatal(1, "[Generator] Transaction randomization failed.");
        end

        tr.id = next_id++;
        gen_agent_mbx.put(tr);
    endtask

    task generate_broadcast(int unsigned source);
        transaction_t tr;

        tr = new(cfg.num_devices, cfg.broadcast_code);

        if (!tr.randomize() with {
            packet_type == BROADCAST;
            source == local::source;
            delay inside {[cfg.min_delay:cfg.max_delay]};
        }) begin
            $fatal(1, "[Generator] Transaction randomization failed.");
        end

        tr.id = next_id++;
        gen_agent_mbx.put(tr);
    endtask

endclass