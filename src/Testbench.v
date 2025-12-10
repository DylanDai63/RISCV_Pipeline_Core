// module tb();

//     reg clock = 0, reset;
    
//     RISC_V_PIPELINED_TOP dut (.clock(clock), .reset(reset));
    
//     always begin
//         clock = ~clock;
//         #50;
//     end

//     initial begin
//         //clock <= 1'b0;
//         reset <= 1'b0;
//         #200;
//         reset <= 1'b1;
//         #400;
//         reset <= 1'b0;
//         #4000;
//         $finish;    
//     end

//     initial begin
//         $dumpfile("dump.vcd");
//       	$dumpvars(0);
//     end

// endmodule

module tb();

    reg clock = 1'b0; // Initialize clock to 0
    reg reset;
    
    // Performance Counters
    integer total_cycles = 0;
    integer instructions_completed = 0;
    integer total_branches = 0;
    integer branches_mispredicted = 0;
    integer mem_accesses = 0;
    integer mem_hits = 0;
    
    // Latency Timing
    real start_time;
    real end_time;
    
    // DUT Instantiation
    RISC_V_PIPELINED_TOP dut (.clock(clock), .reset(reset));
    
    // Clock Generation (Period = 100 units)
    always #50 clock = ~clock;

    // --- Main Simulation Block ---
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        // Reset Sequence
        reset = 1'b1; // Start in Reset
        #200;
        reset = 1'b0; // Release Reset (Start Execution)
        
        // Record Start Time
        start_time = $time;
        
        // Run Simulation
        #4000; 
        
        // Record End Time & Finish
        end_time = $time;
        
        // --- DISPLAY METRICS ---
        $display("\n==================================================");
        $display("           RISC-V PROCESSOR PERFORMANCE REPORT      ");
        $display("==================================================");
        
        $display("Total Cycles:            %0d", total_cycles);
        $display("Instructions Retired:    %0d", instructions_completed);
        
        // Avoid division by zero
        if (instructions_completed > 0)
            $display("CPI (Cycles Per Instr):  %0.4f", $itor(total_cycles) / $itor(instructions_completed));
        else
            $display("CPI:                     N/A (No instructions completed)");
            
        $display("--------------------------------------------------");
        
        $display("Total Branches:          %0d", total_branches);
        $display("Branches Mispredicted:   %0d", branches_mispredicted);
        
        if (total_branches > 0)
            $display("Prediction Accuracy:     %0.2f %%", 100.0 * (1.0 - $itor(branches_mispredicted)/$itor(total_branches)));
        else
            $display("Prediction Accuracy:     N/A (No branches)");
            
        $display("--------------------------------------------------");
        
        $display("Total Execution Time:    %0t ns", (end_time - start_time));
        
        // Since you are using Ideal Memory currently, Hit Rate is 100%
        // If you implement a Cache later, replace '100.0' with (hits/accesses)*100
        $display("Cache Hit Rate:          100.00 %% (Ideal Memory)");
        
        $display("==================================================\n");
        
        $finish;    
    end

    // --- Performance Counting Logic ---
    always @(posedge clock) begin
        if (!reset) begin // Only count when processor is running
            total_cycles = total_cycles + 1;

            // 1. Count Retired Instructions (Completed Writeback)
            // We check RegWriteW (ALU/Load) or MemWriteM (Store) to count completed ops
            // Note: MemWriteM is in Memory stage, but for counters it's close enough to "complete"
            // Ideally, pass a 'Valid' signal from Writeback. Here we use RegWriteW.
            if (dut.RegWriteW || dut.MemWriteM) begin
                instructions_completed = instructions_completed + 1;
            end
            
            // 2. Count Branch Statistics
            // Access signals inside DUT -> Execute Stage
            // BranchE != 0 means it is a branch instruction
            if (dut.Execute.BranchE != 3'b000) begin
                total_branches = total_branches + 1;
                
                // Static Prediction (Assume Not Taken)
                // If PCSrcE is High, we took the branch -> Misprediction
                if (dut.Execute.PCSrcE == 1'b1) begin
                    branches_mispredicted = branches_mispredicted + 1;
                end
            end
        end
    end

endmodule