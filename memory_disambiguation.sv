module memory_disambiguation 
    import lsu_types::*;
(
    input  logic clk,
    input  logic rst_n,
    
    // Instruction interface
    input  logic [ADDR_WIDTH-1:0] addr_in,
    input  logic                  is_load,
    output logic [7:0]           ssid_out,
    output logic                 predict_dependency,
    
    // Performance interface
    output perf_counters_t       disambiguation_stats
);

    // Store Set ID Table
    ssit_entry_t [NUM_STORE_SETS-1:0] ssit;
    
    // Bloom Filter
    logic [BLOOM_FILTER_SIZE-1:0] bloom_filter;
    logic [10:0] hash1, hash2;  // Bloom filter hash values
    
    // Hash functions for bloom filter
    function logic [10:0] compute_hash1(logic [ADDR_WIDTH-1:0] addr);
        return addr[10:0] ^ addr[21:11];
    endfunction
    
    function logic [10:0] compute_hash2(logic [ADDR_WIDTH-1:0] addr);
        return addr[21:11] ^ addr[31:21];
    endfunction

    // Bloom Filter Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bloom_filter <= '0;
        end else begin
            // Update bloom filter on stores
            if (!is_load) begin
                hash1 = compute_hash1(addr_in);
                hash2 = compute_hash2(addr_in);
                bloom_filter[hash1] <= 1;
                bloom_filter[hash2] <= 1;
            end
        end
    end

    // Store Set Predictor Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ssit <= '{default: '0};
        end else begin
            // Update store set prediction
            if (is_load) begin
                hash1 = compute_hash1(addr_in);
                hash2 = compute_hash2(addr_in);
                
                if (bloom_filter[hash1] && bloom_filter[hash2]) begin
                    disambiguation_stats.bloom_filter_hits++;
                    
                    // Update SSIT
                    if (!ssit[hash1[7:0]].valid) begin
                        ssit[hash1[7:0]].valid <= 1;
                        ssit[hash1[7:0]].ssid <= hash1[7:0];
                        ssit[hash1[7:0]].confidence <= 1;
                    end else begin
                        if (ssit[hash1[7:0]].confidence < 15)
                            ssit[hash1[7:0]].confidence <= ssit[hash1[7:0]].confidence + 1;
                    end
                end
            end
        end
    end

    // Prediction Logic
    always_comb begin
        ssid_out = ssit[addr_in[7:0]].ssid;
        predict_dependency = ssit[addr_in[7:0]].valid && 
                           (ssit[addr_in[7:0]].confidence >= 8);
                           
        if (predict_dependency)
            disambiguation_stats.store_set_predictions++;
    end

endmodule
