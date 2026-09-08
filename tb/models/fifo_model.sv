
class FifoModel #(parameter int PCKG_SZ = 16);
    typedef bit [PCKG_SZ-1:0] packet_t;
    packet_t queue[$];
    int unsigned depth;

    function new(int unsigned depth);
        if (depth == 0) begin
            $fatal(1, "[FifoModel] FIFO depth must be greater than 0.");
        end
        this.depth = depth;
    endfunction

    function bit push(packet_t packet);
        if (full()) begin
            $warning("[FifoModel] Attempted to push a packet into a full FIFO.");
            return 0;
        end
        queue.push_back(packet);
        return 1;
    endfunction

    function bit pop(output packet_t packet);
        if (empty()) begin
            $warning("[FifoModel] Attempted to pop a packet from an empty FIFO.");
            packet = '0;
            return 0;
        end
        packet = queue.pop_front();
        return 1;
    endfunction

    function bit peek(output packet_t packet);
        if (empty()) begin
            packet = '0;
            return 0;
        end
        packet = queue[0];
        return 1;
    endfunction

    function bit empty();
        return (queue.size() == 0);
    endfunction

    function bit full();
        return (queue.size() >= depth);
    endfunction

    function int unsigned size();
        return queue.size();
    endfunction

    function void clear();
        queue.delete();
    endfunction

    function void print();
        $display("[FifoModel] size = %0d / %0d", queue.size(), depth);
    endfunction

endclass