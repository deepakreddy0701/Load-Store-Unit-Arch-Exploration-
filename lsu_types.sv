package lsu_types;
    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 64;
    parameter LSQ_DEPTH = 32;    // Load-Store Queue depth
    parameter NUM_STORE_SETS = 256; // Number of store sets for memory disambiguation
    parameter BLOOM_FILTER_SIZE = 2048; // Size of bloom filter

    // Store Set ID Table entry
    typedef struct packed {
        logic valid;
        logic [7:0] ssid;  // Store Set ID
        logic [3:0] confidence;  // Confidence counter
    } ssit_entry_t;

    // Load-Store Queue entry
    typedef struct packed {
        logic valid;
        logic is_load;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] data;
        logic [7:0] ssid;     // Store Set ID
        logic speculative;    // Whether operation is speculative
        logic [5:0] age;      // Age for ordering policy
        logic violated;       // Memory ordering violation detected
    } lsq_entry_t;

    // Performance counters
    typedef struct packed {
        logic [31:0] total_loads;
        logic [31:0] total_stores;
        logic [31:0] forwarded_loads;
        logic [31:0] violated_loads;
        logic [31:0] bloom_filter_hits;
        logic [31:0] store_set_predictions;
        logic [31:0] false_positives;
        logic [31:0] false_negatives;
    } perf_counters_t;
endpackage
