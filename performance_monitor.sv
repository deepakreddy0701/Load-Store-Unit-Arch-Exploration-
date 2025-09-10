module performance_monitor 
    import lsu_types::*;
(
    input  logic clk,
    input  logic rst_n,
    
    // Performance counter inputs
    input  perf_counters_t lsq_counters,
    input  perf_counters_t disambiguation_counters,
    
    // Control interface
    input  logic clear_counters,
    output logic [31:0] total_instructions,
    output logic [31:0] load_hit_rate,
    output logic [31:0] prediction_accuracy
);

    perf_counters_t combined_counters;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear_counters) begin
            combined_counters <= '{default: '0};
            total_instructions <= '0;
            load_hit_rate <= '0;
            prediction_accuracy <= '0;
        end else begin
            // Combine counters
            combined_counters.total_loads <= lsq_counters.total_loads;
            combined_counters.total_stores <= lsq_counters.total_stores;
            combined_counters.forwarded_loads <= lsq_counters.forwarded_loads;
            combined_counters.violated_loads <= lsq_counters.violated_loads;
            combined_counters.bloom_filter_hits <= disambiguation_counters.bloom_filter_hits;
            combined_counters.store_set_predictions <= disambiguation_counters.store_set_predictions;
            
            // Calculate metrics
            total_instructions <= combined_counters.total_loads + 
                                combined_counters.total_stores;
                                
            if (combined_counters.total_loads > 0) begin
                load_hit_rate <= (combined_counters.forwarded_loads * 100) / 
                                combined_counters.total_loads;
            end
            
            if (combined_counters.store_set_predictions > 0) begin
                prediction_accuracy <= 
                    ((combined_counters.store_set_predictions - 
                      combined_counters.false_positives -
                      combined_counters.false_negatives) * 100) /
                    combined_counters.store_set_predictions;
            end
        end
    end

endmodule
