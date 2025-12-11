// `include "ALU.v"
// `include "Mux_2_1_32.v"
// `include "Mux_4_1_32.v"

module Execute_Cycle(
    clock, reset, 
    RegWriteE, ALUSrcE, MemWriteE, ResultSrcE, JumpE, BranchE, ALUControlE, 
    RD1_E, RD2_E, Imm_Ext_E, RD_E, PCE, PCPlus4E, 
    PCSrcE, PCTargetE, RegWriteM, MemWriteM, ResultSrcM, RD_M, PCPlus4M, WriteDataM, ALU_ResultM, 
    ResultW, ForwardA_E, ForwardB_E,
    ALUSrcE_A, PCTargetSrcE
);

    // Declaration I/Os
    input clock, reset, RegWriteE, ALUSrcE, MemWriteE, JumpE;
    input ALUSrcE_A, PCTargetSrcE; 
    input [2:0] BranchE;
    input [1:0] ResultSrcE;
    input [3:0] ALUControlE;
    input [31:0] RD1_E, RD2_E, Imm_Ext_E;
    input [4:0] RD_E;
    input [31:0] PCE, PCPlus4E;
    input [31:0] ResultW;
    input [1:0] ForwardA_E, ForwardB_E;

    // Outputs
    output PCSrcE, RegWriteM, MemWriteM; // PCSrcE is kept for compatibility but effectively unused
    output [1:0] ResultSrcM;
    output [4:0] RD_M; 
    output [31:0] PCPlus4M, WriteDataM, ALU_ResultM;
    output [31:0] PCTargetE;

    // Declaration of Interim Wires
    wire [31:0] Src_A_Forwarded, Src_A, Src_B_Forwarded, Src_B;
    wire [31:0] ResultE;
    wire ZeroE;

    // Declaration of Registers
    reg RegWriteE_r, MemWriteE_r;
    reg [1:0] ResultSrcE_r;
    reg [4:0] RD_E_r;
    reg [31:0] PCPlus4E_r, RD2_E_r, ResultE_r;

    // --- MODULES ---

    // 1. Forwarding Mux for Source A
    Mux_4_1_32 srca_forward_mux (
        .Input0(RD1_E),
        .Input1(ResultW),
        .Input2(ALU_ResultM), 
        .Input3(32'h00000000),
        .Selection(ForwardA_E),
        .Output(Src_A_Forwarded)
    );

    // 2. AUIPC Mux
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
        .Input2(ALU_ResultM), 
        .Input3(32'h00000000),
        .Selection(ForwardB_E),
        .Output(Src_B_Forwarded)
    );

    // 4. ALU Src Mux
    Mux_2_1_32 alu_src_mux (
        .Input0(Src_B_Forwarded),
        .Input1(Imm_Ext_E),
        .Selection(ALUSrcE),
        .Output(Src_B)
    );

    // 5. ALU Unit
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

    // --- REMOVED: Branch_Module (Moved to Decode) ---
    // --- REMOVED: PC_Adder for Branch Target (Moved to Decode) ---

    // JALR Target (Still calculated here as it uses ALU Result)
    // But since Fetch listens to Decode, this output is largely informational 
    // unless you implement specific JALR handling.
    assign PCTargetE = ResultE; 

    // PCSrcE is now 0 because the decision happens in Decode (PCSrcD)
    // We keep the port to avoid breaking the Top Module instantiation.
    assign PCSrcE = 1'b0; 

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
            RD2_E_r <= Src_B_Forwarded;
            ResultE_r <= ResultE;
        end
    end

    // Output Assignments
    assign RegWriteM = RegWriteE_r;
    assign MemWriteM = MemWriteE_r;
    assign ResultSrcM = ResultSrcE_r;
    assign RD_M = RD_E_r;
    assign PCPlus4M = PCPlus4E_r;
    assign WriteDataM = RD2_E_r;
    assign ALU_ResultM = ResultE_r;

endmodule