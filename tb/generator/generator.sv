
class generator #(parameter int DRVRS   = 4, parameter int PCKG_SZ = 16);

    mailbox #(trans_test #(DRVRS)) mbx_test_to_gen;
    mailbox #(trans_gen #(PCKG_SZ)) mbx_gen_to_agent;

    function new(mailbox #(trans_test #(DRVRS)) mbx_test_to_gen, mailbox #(trans_gen #(PCKG_SZ)) mbx_gen_to_agent);
        this.mbx_test_to_gen  = mbx_test_to_gen;
        this.mbx_gen_to_agent = mbx_gen_to_agent;
    endfunction

    task run();
        trans_test #(DRVRS) request;
        trans_gen #(PCKG_SZ) trans;

        // Wait for test configuration
        mbx_test_to_gen.get(request);
        $info("[%0t] generator: test configuration received", $time);

        for (int unsigned i = 0; i < request.total_trans; i++) begin
            trans = new(i);
            if (!trans.randomize() 
                // no sé que poner acá, sigo pensando
            )
                $fatal(1, "[%0t] generator: randomization failed for transaction %0d", $time,i);
            case (request.payload_mode)
                PAYLOAD_RANDOM: begin
                    
                end
                PAYLOAD_SWITCHING: begin
                    
                end
                default:
                    $fatal(1, "[%0t] generator: invalid payload mode", $time);
            endcase

            $info("[%0t] generator: transaction %0d generated - src=%0d dst=%0d broadcast=%0d gap=%0d payload=0x%0h",
                $time,trans.id, trans.source, trans.destination, trans.broadcast, trans.gap, trans.payload);

            mbx_gen_to_agent.put(trans);
        end
    endtask
endclass