`timescale 1ns / 1ps

module RISCV_TB_Phase0;

    reg clock;
    reg reset;

    // Instantiate Phase 0 UUT
    RISC_V_PIPELINED_TOP uut (
        .clock(clock), 
        .reset(reset)
    );

    // Metric Counters
    integer total_cycles = 0;
    integer total_instructions = 0;
    integer total_branches = 0;
    integer branch_correct = 0;
    integer nop_counter = 0;
    
    // Cache Simulation Vars
    integer i_hits = 0, i_acc = 0;
    integer d_hits = 0, d_acc = 0;
    reg [31:0] i_tags [0:63]; reg i_v [0:63];
    reg [31:0] d_tags [0:63]; reg d_v [0:63];
    integer idx;

    always #5 clock = ~clock; 

    initial begin
        clock = 0; reset = 1;
        // Init Cache Arrays
        for(idx=0; idx<64; idx=idx+1) begin i_v[idx]=0; d_v[idx]=0; end
        
        $dumpfile("riscv_phase0.vcd");
        $dumpvars(0, RISCV_TB_Phase0);
        #20; reset = 0;
    end

    always @(posedge clock) begin
        if (!reset) begin
            // 1. AUTO-STOP LOGIC
            // Stop if Execute stage is idle for 5 cycles
            if (uut.Execute.RegWriteE == 0 && uut.Execute.MemWriteE == 0 && uut.Execute.BranchE == 0 && uut.Execute.JumpE == 0) begin
                nop_counter = nop_counter + 1;
                if (nop_counter >= 5) begin
                    print_report(total_cycles - 5); // Subtract idle cycles
                    $finish;
                end
            end else begin
                nop_counter = 0;
            end
            
            total_cycles = total_cycles + 1;

            // 2. INSTRUCTION & BRANCH COUNTING (Phase 0)
            if (uut.Execute.RegWriteE || uut.Execute.MemWriteE || uut.Execute.BranchE != 0 || uut.Execute.JumpE) begin
                total_instructions = total_instructions + 1;
            end

            if (uut.Execute.BranchE != 0) begin
                total_branches = total_branches + 1;
                // Static Prediction: Predict Not Taken.
                // If PCSrcE == 0, prediction was Correct. If 1, Incorrect.
                if (uut.Execute.PCSrcE == 0) branch_correct = branch_correct + 1;
            end

            // 3. REALISTIC CACHE SIMULATION
            // I-Cache
            i_acc = i_acc + 1;
            if (i_v[uut.Fetch.PCF[9:4]] && i_tags[uut.Fetch.PCF[9:4]] == uut.Fetch.PCF[31:10]) i_hits = i_hits + 1;
            else begin i_v[uut.Fetch.PCF[9:4]]=1; i_tags[uut.Fetch.PCF[9:4]]=uut.Fetch.PCF[31:10]; end

            // D-Cache
            if (uut.MemWriteM || uut.ResultSrcM == 1) begin
                d_acc = d_acc + 1;
                if (d_v[uut.ALU_ResultM[9:4]] && d_tags[uut.ALU_ResultM[9:4]] == uut.ALU_ResultM[31:10]) d_hits = d_hits + 1;
                else begin d_v[uut.ALU_ResultM[9:4]]=1; d_tags[uut.ALU_ResultM[9:4]]=uut.ALU_ResultM[31:10]; end
            end
        end
    end

    task print_report;
        input integer cycles;
        real cpi, ipc, spi, br_acc, i_rate, d_rate;
        begin
            cpi = cycles * 1.0 / total_instructions;
            ipc = 1.0 / cpi;
            spi = cpi - 1.0;
            if (total_branches > 0) br_acc = branch_correct * 100.0 / total_branches; else br_acc = 100;
            if (i_acc > 0) i_rate = i_hits * 100.0 / i_acc; else i_rate = 0;
            if (d_acc > 0) d_rate = d_hits * 100.0 / d_acc; else d_rate = 0;

            $display("\n=== PHASE 0 (ORIGINAL) REPORT ===");
            $display("Latency (Total Cycles) : %0d", cycles);
            $display("Throughput (IPC)       : %0.2f instr/cycle", ipc);
            $display("CPI                    : %0.2f cycles/instr", cpi);
            $display("Stalls Per Instruction : %0.2f", spi);
            $display("---------------------------------");
            $display("Branch Pred Accuracy   : %0.2f%%", br_acc);
            $display("I-Cache Hit Rate       : %0.2f%%", i_rate);
            $display("D-Cache Hit Rate       : %0.2f%%", d_rate);
            $display("=================================\n");
        end
    endtask
endmodule