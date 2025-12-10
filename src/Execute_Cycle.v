// `include "ALU.v"
// `include "Mux_2_1_32.v"
// `include "Mux_4_1_32.v"
// `include "PC_Adder.v"
// `include "Branch_Module.v"

module Execute_Cycle(
    clock, reset, 
    RegWriteE, ALUSrcE, MemWriteE, ResultSrcE, JumpE, BranchE, ALUControlE, 
    RD1_E, RD2_E, Imm_Ext_E, RD_E, PCE, PCPlus4E, 
    PCSrcE, PCTargetE, RegWriteM, MemWriteM, ResultSrcM, RD_M, PCPlus4M, WriteDataM, ALU_ResultM, 
    ResultW, ForwardA_E, ForwardB_E,
    // NEW INPUTS
    ALUSrcE_A, PCTargetSrcE
);

    // Declaration I/Os
    input clock, reset, RegWriteE, ALUSrcE, MemWriteE, JumpE;
    input ALUSrcE_A, PCTargetSrcE; // Control signals for AUIPC and JALR
    input [2:0] BranchE;
    input [1:0] ResultSrcE;
    input [3:0] ALUControlE;
    input [31:0] RD1_E, RD2_E, Imm_Ext_E;
    input [4:0] RD_E;
    input [31:0] PCE, PCPlus4E;
    input [31:0] ResultW;
    input [1:0] ForwardA_E, ForwardB_E;

    output PCSrcE, RegWriteM, MemWriteM;
    output [1:0] ResultSrcM;
    output [4:0] RD_M; 
    output [31:0] PCPlus4M, WriteDataM, ALU_ResultM;
    output [31:0] PCTargetE;

    // Declaration of Interim Wires
    wire [31:0] Src_A_Forwarded, Src_A, Src_B_Forwarded, Src_B;
    wire [31:0] ResultE;
    wire [31:0] BranchTarget, JALR_Target;
    wire ZeroE, isBranch;

    // Declaration of Register
    reg RegWriteE_r, MemWriteE_r;
    reg [1:0] ResultSrcE_r;
    reg [4:0] RD_E_r;
    reg [31:0] PCPlus4E_r, RD2_E_r, ResultE_r;

    // --- MODULES ---

    // 1. Forwarding Mux for Source A (Selects: Register, Writeback Result, or Memory Result)
    Mux_4_1_32 srca_forward_mux (
        .Input0(RD1_E),
        .Input1(ResultW),
      	.Input2(ALU_ResultM), // Critical: Using input from Top module
        .Input3(32'h00000000),
        .Selection(ForwardA_E),
        .Output(Src_A_Forwarded)
    );

    // 2. NEW: AUIPC Mux (Selects: Forwarded Register A or PC)
    Mux_2_1_32 auipc_mux (
        .Input0(Src_A_Forwarded),
        .Input1(PCE),
        .Selection(ALUSrcE_A),
        .Output(Src_A)
    );

    // 3. Forwarding Mux for Source B
    Mux_4_1_32 srcb_forward_mux (
        .Input0(RD2_E),
        .Input1(ResultW),
      .Input2(ALU_ResultM), // Critical: Using input from Top module
        .Input3(32'h00000000),
        .Selection(ForwardB_E),
        .Output(Src_B_Forwarded)
    );

    // 4. ALU Src Mux (Selects: Register B or Immediate)
    Mux_2_1_32 alu_src_mux (
        .Input0(Src_B_Forwarded),
        .Input1(Imm_Ext_E),
        .Selection(ALUSrcE),
        .Output(Src_B)
    );

    // 5. Branch Logic (Compares Forwarded Values)
    Branch_Module is_Branch(
        .A(Src_A_Forwarded), 
        .B(Src_B_Forwarded), 
        .A_Unsigned(Src_A_Forwarded), 
        .B_Unsigned(Src_B_Forwarded), 
        .BranchE(BranchE), 
        .isBranch(isBranch) 
    );

    // 6. ALU Unit
    ALU alu (
        .A(Src_A),
        .B(Src_B),
        .Result(ResultE),
        .ALUControl(ALUControlE),
        .OverFlow(),
        .Carry(),
        .Zero(ZeroE),
        .Negative()
    );

    // 7. PC Target Calculation
    // Adder for Branches and JAL
    PC_Adder branch_adder (
        .PC(PCE),
        .Amount(Imm_Ext_E),
        .Incremented_PC(BranchTarget)
    );

    // Mux for JALR (Selects: PC+Imm or ALU Result)
    assign JALR_Target = ResultE; // JALR uses the ALU result
    assign PCTargetE = (PCTargetSrcE == 1'b1) ? JALR_Target : BranchTarget;

    // --- PIPELINE REGISTER LOGIC ---
    always @(posedge clock or posedge reset) begin
        if(reset == 1'b1) begin
            RegWriteE_r <= 1'b0; 
            MemWriteE_r <= 1'b0; 
            ResultSrcE_r <= 2'b00;
            RD_E_r <= 5'h00;
            PCPlus4E_r <= 32'h00000000; 
            RD2_E_r <= 32'h00000000; 
            ResultE_r <= 32'h00000000;
        end
        else begin
            RegWriteE_r <= RegWriteE; 
            MemWriteE_r <= MemWriteE; 
            ResultSrcE_r <= ResultSrcE;
            RD_E_r <= RD_E;
            PCPlus4E_r <= PCPlus4E; 
            RD2_E_r <= Src_B_Forwarded; // We latch the Forwarded B for Store instructions
            ResultE_r <= ResultE;
        end
    end

    // Output Assignments
    assign PCSrcE = JumpE | (BranchE != 3'b000 & isBranch == 1'b1);
    
    // Outputs come from the Registers (_r)
    assign RegWriteM = RegWriteE_r;
    assign MemWriteM = MemWriteE_r;
    assign ResultSrcM = ResultSrcE_r;
    assign RD_M = RD_E_r;
    assign PCPlus4M = PCPlus4E_r;
    assign WriteDataM = RD2_E_r;
    assign ALU_ResultM = ResultE_r;

endmodule