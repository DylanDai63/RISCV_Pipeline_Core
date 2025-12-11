`include "Fetch_Cycle.v"
`include "Decode_Cycle.v"
`include "Execute_Cycle.v"
`include "Memory_Cycle.v"
`include "Writeback_Cycle.v"
`include "PC_Adder.v"
`include "PC_Module.v"
`include "Mux_2_1_32.v"
`include "Mux_4_1_32.v"
`include "Instruction_Memory.v"
`include "Control_Unit_1.v"
`include "Register_File.v"
`include "Sign_Extend.v"
`include "ALU.v"
`include "Data_Memory.v"
`include "Hazard_Unit.v"
`include "Branch_Module.v"

module RISC_V_PIPELINED_TOP(clock, reset);

    // Declaration of I/O
    input clock, reset;

    // Declaration of Interim Wires
    wire PCSrcE, RegWriteW, RegWriteE, ALUSrcE, MemWriteE, JumpE, RegWriteM, MemWriteM;
    wire [2:0] BranchE;
    wire [1:0] ResultSrcE, ResultSrcM, ResultSrcW;
    wire [3:0] ALUControlE;
    wire [4:0] RD_E, RD_M, RDW;
    wire [31:0] PCTargetE, InstrD, PCD, PCPlus4D, ResultW, RD1_E, RD2_E, Imm_Ext_E, PCE, PCPlus4E, PCPlus4M, WriteDataM, ALU_ResultM;
    wire [31:0] PCPlus4W, ALU_ResultW, ReadDataW;
    wire [4:0] RS1_D, RS2_D, RS1_E, RS2_E;
    wire [1:0] ForwardBE, ForwardAE;
    wire ForwardBD, ForwardAD;

    // --- NEW WIRES FOR JAL/JALR/AUIPC ---
    wire ALUSrcE_A, PCTargetSrcE; 

    // Module Initiation
    // Fetch Stage
    Fetch_Cycle Fetch (
                        .clock(clock), 
                        .reset(reset), 
                        .PCSrcE(PCSrcE), 
                        .PCTargetE(PCTargetE), 
                        .InstrD(InstrD), 
                        .PCD(PCD), 
                        .PCPlus4D(PCPlus4D)
                    );

    // Decode Stage
    Decode_Cycle Decode (
                        .clock(clock), 
                        .reset(reset), 
                        .InstrD(InstrD), 
                        .PCD(PCD), 
                        .PCPlus4D(PCPlus4D), 
                        .RegWriteW(RegWriteW), 
                        .RDW(RDW), 
                        .ResultW(ResultW), 
                        .RegWriteE(RegWriteE), 
                        .ALUSrcE(ALUSrcE), 
                        .MemWriteE(MemWriteE), 
                        .ResultSrcE(ResultSrcE),
                        .JumpE(JumpE),  
                        .BranchE(BranchE),  
                        .ALUControlE(ALUControlE), 
                        .RD1_E(RD1_E), 
                        .RD2_E(RD2_E), 
                        .Imm_Ext_E(Imm_Ext_E), 
                        .RD_E(RD_E), 
                        .PCE(PCE), 
                        .PCPlus4E(PCPlus4E),
                        .RS1_D(RS1_D),
                        .RS2_D(RS2_D),
                        .RS1_E(RS1_E),
                        .RS2_E(RS2_E),
                        .ForwardA_D(ForwardAD),
                        .ForwardB_D(ForwardBD),
                        // --- NEW OUTPUT CONNECTIONS ---
                        .ALUSrcE_A(ALUSrcE_A),      // Output from Decode
                        .PCTargetSrcE(PCTargetSrcE) // Output from Decode
                    );

    // Execute Stage
    Execute_Cycle Execute (
                        .clock(clock), 
                        .reset(reset), 
                        .RegWriteE(RegWriteE), 
                        .ALUSrcE(ALUSrcE), 
                        .MemWriteE(MemWriteE), 
                        .ResultSrcE(ResultSrcE), 
                        .JumpE(JumpE), 
                        .BranchE(BranchE), 
                        .ALUControlE(ALUControlE), 
                        .RD1_E(RD1_E), 
                        .RD2_E(RD2_E), 
                        .Imm_Ext_E(Imm_Ext_E), 
                        .RD_E(RD_E), 
                        .PCE(PCE), 
                        .PCPlus4E(PCPlus4E), 
                        .PCSrcE(PCSrcE), 
                        .PCTargetE(PCTargetE), 
                        .RegWriteM(RegWriteM), 
                        .MemWriteM(MemWriteM), 
                        .ResultSrcM(ResultSrcM), 
                        .RD_M(RD_M), 
                        .PCPlus4M(PCPlus4M), 
                        .WriteDataM(WriteDataM), 
                        .ALU_ResultM(ALU_ResultM),
                        .ResultW(ResultW),
                        .ForwardA_E(ForwardAE),
                        .ForwardB_E(ForwardBE),
                        // --- FIXED INPUT CONNECTIONS ---
                        .ALUSrcE_A(ALUSrcE_A),       // Input to Execute
                        .PCTargetSrcE(PCTargetSrcE) // Input to Execute
                    );
    
    // Memory Stage
    Memory_Cycle Memory (
                        .clock(clock), 
                        .reset(reset), 
                        .RegWriteM(RegWriteM), 
                        .MemWriteM(MemWriteM), 
                        .ResultSrcM(ResultSrcM), 
                        .RD_M(RD_M), 
                        .PCPlus4M(PCPlus4M), 
                        .WriteDataM(WriteDataM), 
                        .ALU_ResultM(ALU_ResultM), 
                        .RegWriteW(RegWriteW), 
                        .ResultSrcW(ResultSrcW), 
                        .RD_W(RDW), 
                        .PCPlus4W(PCPlus4W), 
                        .ALU_ResultW(ALU_ResultW), 
                        .ReadDataW(ReadDataW)
                    );

    // Write Back Stage
    Writeback_Cycle WriteBack (
                        .clock(clock), 
                        .reset(reset), 
                        .ResultSrcW(ResultSrcW), 
                        .PCPlus4W(PCPlus4W), 
                        .ALU_ResultW(ALU_ResultW), 
                        .ReadDataW(ReadDataW), 
                        .ResultW(ResultW)
                    );

    // Hazard Unit
    Hazard_Unit Forwarding_block (
                        .reset(reset), 
                        // FIXED: Check Hazard against instruction LEAVING the pipeline (W stage)
                        // Using RegWriteW/RDW ensures we forward from the valid committed instruction
                        .RegWriteM(RegWriteM), // Check against Execute-Memory Boundary
                        .RegWriteW(RegWriteW), // Check against Memory-Writeback Boundary
                        .RD_M(RD_M), 
                        .RD_W(RDW), 
                        .Rs1_D(RS1_D), 
                        .Rs2_D(RS2_D), 
                        .Rs1_E(RS1_E), 
                        .Rs2_E(RS2_E), 
                        .ForwardAE(ForwardAE),
                        .ForwardBE(ForwardBE),
                        .ForwardAD(ForwardAD), 
                        .ForwardBD(ForwardBD)
                        );
endmodule