
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
        int unsigned invalid_pct;
        int unsigned invalid_min;
        int unsigned invalid_max;
        int unsigned source_weights[10];
        int unsigned destination_weights[10];
        int unsigned remaining[10];
        int unsigned selected_source;
        bit selected_invalid;

        if (DRVRS < 2 || DRVRS > 10 || (PCKG_SZ != 16) && (PCKG_SZ != 32) && (PCKG_SZ != 64))
            $fatal(1, "generator: invalid elaboration parameters");

        mbx_test_to_gen.get(request);
        request.validate();

        min_gap = request.min_gap;
        max_gap = request.max_gap;
        broadcast_pct = request.broadcast_weight;
        unicast_pct = 100 - broadcast_pct;
        invalid_pct = request.invalid_weight;
        invalid_min = request.invalid_min;
        invalid_max = request.invalid_max;
        for (int s = 0; s < 10; s++) begin
            source_weights[s] = request.source_weights[s];
            destination_weights[s] = request.destination_weights[s];
            remaining[s] = 0;
        end
        if (request.per_source)
            for (int s = 0; s < DRVRS; s++) remaining[s] = request.source_count[s];

        // If config wrong, test will stop at sim time -- need to push wrong 
        // config to make sure the test can stop properly
        $info("[%0t] generator: test configuration received", $time);

        for (int unsigned i = 0; i < request.total_trans; i++) begin
            trans = new(i);

            // Pick the source first so destination restrictions cannot change
            // the requested source probabilities. Exhausted quotas get weight 0.
            if (request.per_source)
                for (int s = 0; s < DRVRS; s++)
                    if (remaining[s] == 0) source_weights[s] = 0;
            if (!std::randomize(selected_source) with {
                selected_source < DRVRS;
                selected_source dist {
                    0 := source_weights[0], 1 := source_weights[1],
                    2 := source_weights[2], 3 := source_weights[3],
                    4 := source_weights[4], 5 := source_weights[5],
                    6 := source_weights[6], 7 := source_weights[7],
                    8 := source_weights[8], 9 := source_weights[9]
                };
            }) $fatal(1, "[Generator] Cannot select a source with the configured weights");

            if (!std::randomize(selected_invalid) with {
                selected_invalid dist {1'b1 := invalid_pct, 1'b0 := (100-invalid_pct)};
            }) $fatal(1, "[Generator] Cannot randomize invalid destination selection");

            // delay is not being applied here, it will be inserted on drivers
            if (!trans.randomize() with {
                source == selected_source;
                invalid_destination == selected_invalid;
                gap inside {[min_gap:max_gap]};
                if (!invalid_destination)
                    broadcast dist {1'b1 := broadcast_pct,
                                    1'b0 := unicast_pct};
                if (invalid_destination)
                    destination inside {[invalid_min:invalid_max]};
                else if (!broadcast)
                    destination dist {
                        0 := destination_weights[0], 1 := destination_weights[1],
                        2 := destination_weights[2], 3 := destination_weights[3],
                        4 := destination_weights[4], 5 := destination_weights[5],
                        6 := destination_weights[6], 7 := destination_weights[7],
                        8 := destination_weights[8], 9 := destination_weights[9]
                    };
            })
                $fatal(1, "[%0t] generator: randomization failed for transaction %0d", $time, i);
            if (request.per_source) remaining[selected_source]--;

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

            mbx_gen_to_agent.put(trans); // This can be improve with an event - done listening from agent
        end
    endtask

endclass
