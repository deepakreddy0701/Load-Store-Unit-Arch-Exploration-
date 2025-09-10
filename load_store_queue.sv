module load_store_queue 
    import lsu_types::*;
(
    input  logic clk,
    input  logic rst_n,
    
    // Instruction interface
    input  logic                    load_valid,
    input  logic                    store_valid,
    input  logic [ADDR_WIDTH-1:0]   addr_in,
    input  logic [DATA_WIDTH-1:0]   data_in,
    input  logic [7:0]              ssid_in,    // Store Set ID
    output logic                    lsq_full,
    output logic [DATA_WIDTH-1:0]   load_data_out,
    output logic                    load_complete,
    
    // Memory interface
    output logic                    mem_read,
    output logic                    mem_write,
    output logic [ADDR_WIDTH-1:0]   mem_addr,
    output logic [DATA_WIDTH-1:0]   mem_wdata,
    input  logic [DATA_WIDTH-1:0]   mem_rdata,
    input  logic                    mem_ready,
    
    // Performance counter interface
    output perf_counters_t          perf_counters
);

    // Load-Store Queue
    lsq_entry_t [LSQ_DEPTH-1:0] lsq;
    logic [$clog2(LSQ_DEPTH)-1:0] head, tail;
    logic [$clog2(LSQ_DEPTH):0] count;

    // Store-to-Load Forwarding Logic
    logic [LSQ_DEPTH-1:0] forward_match;
    logic [LSQ_DEPTH-1:0] age_mask;
    logic [$clog2(LSQ_DEPTH)-1:0] youngest_store;
    logic forward_valid;
    
    // Violation Detection
    logic violation_detected;
    logic [$clog2(LSQ_DEPTH)-1:0] violated_load;

    // Age-based selection logic
    always_comb begin
        // Find youngest store that matches load address
        forward_valid = 0;
        youngest_store = '0;
        for (int i = 0; i < LSQ_DEPTH; i++) begin
            forward_match[i] = lsq[i].valid && !lsq[i].is_load && 
                             (lsq[i].addr == addr_in);
            if (forward_match[i] && 
                (!forward_valid || lsq[i].age > lsq[youngest_store].age)) begin
                forward_valid = 1;
                youngest_store = i[$clog2(LSQ_DEPTH)-1:0];
            end
        end
    end

    // Store-to-Load Forwarding
    always_comb begin
        if (load_valid && forward_valid) begin
            load_data_out = lsq[youngest_store].data;
            perf_counters.forwarded_loads++;
        end else begin
            load_data_out = mem_rdata;
        end
    end

    // Violation Recovery Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            violation_detected <= 0;
            violated_load <= '0;
        end else begin
            // Check for ordering violations
            for (int i = 0; i < LSQ_DEPTH; i++) begin
                if (lsq[i].valid && lsq[i].is_load && 
                    store_valid && (addr_in == lsq[i].addr) &&
                    (lsq[i].age < tail)) begin // Store to earlier load
                    violation_detected <= 1;
                    violated_load <= i[$clog2(LSQ_DEPTH)-1:0];
                    perf_counters.violated_loads++;
                end
            end
        end
    end

    // Queue Management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lsq <= '{default: '0};
            head <= '0;
            tail <= '0;
            count <= '0;
        end else begin
            // Handle new entries
            if ((load_valid || store_valid) && !lsq_full) begin
                lsq[tail].valid <= 1;
                lsq[tail].is_load <= load_valid;
                lsq[tail].addr <= addr_in;
                lsq[tail].data <= data_in;
                lsq[tail].ssid <= ssid_in;
                lsq[tail].age <= tail;
                tail <= tail + 1;
                count <= count + 1;
                
                if (load_valid)
                    perf_counters.total_loads++;
                else
                    perf_counters.total_stores++;
            end

            // Handle completions
            if (mem_ready && !lsq[head].is_load) begin
                lsq[head].valid <= 0;
                head <= head + 1;
                count <= count - 1;
            end
        end
    end

    // Status signals
    assign lsq_full = (count >= LSQ_DEPTH-1);

endmodule
