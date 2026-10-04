
class generator #(parameter int DRVRS   = 4, parameter int PCKG_SZ = 16, parameter bit [7:0] BROADCAST_CODE = 8'hFF);

    mailbox #(trans_test #(DRVRS)) mbx_test_to_gen;
    mailbox #(trans_gen #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE))) mbx_gen_to_agent;

    function new(mailbox #(trans_test #(DRVRS)) mbx_test_to_gen, mailbox #(trans_gen #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE))) mbx_gen_to_agent);
        this.mbx_test_to_gen  = mbx_test_to_gen;
        this.mbx_gen_to_agent = mbx_gen_to_agent;
    endfunction

    task run();
        trans_test #(DRVRS) request;
        trans_gen #(.DRVRS(DRVRS), .PCKG_SZ(PCKG_SZ), .BROADCAST_CODE(BROADCAST_CODE)) trans;

        int unsigned min_gap;
        int unsigned max_gap;

        // Define the weight of broadcast/unicast transactions
        int unsigned broadcast_pct;
        int unsigned unicast_pct;

        if (DRVRS < 2 || DRVRS > 10 || (PCKG_SZ != 16) && (PCKG_SZ != 32) && (PCKG_SZ != 64))
            $fatal(1, "generator: invalid elaboration parameters");

        mbx_test_to_gen.get(request);
        request.validate();

        min_gap = request.min_gap;
        max_gap = request.max_gap;
        broadcast_pct = request.broadcast_weight;
        unicast_pct = 100 - broadcast_pct;

        // If config wrong, test will stop at sim time -- need to push wrong 
        // config to make sure the test can stop properly
        $info("[%0t] generator: test configuration received", $time);

        for (int unsigned i = 0; i < request.total_trans; i++) begin
            trans = new(i);

            if (!trans.randomize() with {
                gap inside {[local::min_gap:local::max_gap]};
                broadcast dist {1'b1 := local::broadcast_pct,
                                1'b0 := local::unicast_pct};
            })
                $fatal(1, "[%0t] generator: randomization failed for transaction %0d", $time, i);
                
            // The next section can be improved later -- check later // PAYLOAD_RANDOM is default
            if (request.payload_mode == PAYLOAD_SWITCHING) begin
                if (i % 4 == 0)
                    trans.payload = '0;
                else if (i % 4 == 1)
                    trans.payload = '1;
                else if (i % 4 == 2)
                    trans.payload = 64'hAAAA_AAAA_AAAA_AAAA;
                else
                    trans.payload = 64'h5555_5555_5555_5555;
            end
            else if (request.payload_mode != PAYLOAD_RANDOM) begin
                $fatal(1, "generator: invalid payload mode");
            end

            $info("[%0t] generator: transaction %0d generated - src=%0d dst=%0d broadcast=%0d gap=%0d payload=0x%0h",
                  $time, trans.id, trans.source, trans.destination, trans.broadcast, trans.gap, trans.payload);

            mbx_gen_to_agent.put(trans);
        end
    endtask

endclass
