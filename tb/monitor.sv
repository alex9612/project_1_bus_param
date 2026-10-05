
class monitor #(parameter int DRVRS = 4, parameter int PCKG_SZ = 16, parameter bit [7:0] BROADCAST_CODE = 8'hFF);
    virtual bus_if #(.PCKG_SZ(PCKG_SZ)).monitor vif;




    task run();
        $display("[%0t] The monitor has been initialized", $time);
        @(negedge vif.reset); 
        forever begin
            




        end
    endtask

endclass