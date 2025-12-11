// --- Decode_Cycle.v ---

// `include "Control_Unit_1.v"
// `include "Register_File.v"
// `include "Sign_Extend.v"
// `include "Mux_2_1_32.v"

module Decode_Cycle(
    // Input Ports with CORRECT Bit Widths
    input clock, reset, 
    input [31:0] InstrD, PCD, PCPlus4D, ResultW, // 32-bit data inputs
    input RegWriteW,
    input [4:0] RDW,                              // 5-bit register address
    
    // Forwarding Inputs
    input ForwardA_D, ForwardB_D,
    
    // NEW INPUTS for Hazard Handling
    input StallD,
    input FlushE, 
    input FlushD, 
    
    // Outputs to Execute Stage (Sized correctly)
    output RegWriteE, ALUSrcE, MemWriteE, JumpE,
    output [2:0] BranchE,
    output [1:0] ResultSrcE,
    output [3:0] ALUControlE,
    output [31:0] RD1_E, RD2_E, Imm_Ext_E,
    output [4:0] RS1_E, RS2_E, RD_E,
    output [31:0] PCE, PCPlus4E,
    
    // Outputs for Hazard Unit (Register Addresses)
    output [4:0] RS1_D, RS2_D,
    output ALUSrcE_A, PCTargetSrcE
);

    // Internal Wires (Control Unit Outputs)
    wire RegWriteD, ALUSrcD, MemWriteD, JumpD;
    wire [2:0] BranchD;
    wire [1:0] ResultSrcD;
    wire [3:0] ALUControlD;
    wire [2:0] ImmSrcD;
    wire [31:0] RD1_D, RD2_D, Imm_Ext_D;
    wire ALUSrcA_D, PCTargetSrcD;
    
    // Registers for Pipelining (D -> E) - These are the variables the errors were about
    reg RegWriteD_r, ALUSrcD_r, MemWriteD_r, JumpD_r;
    reg [2:0] BranchD_r;
    reg [1:0] ResultSrcD_r;
    reg [3:0] ALUControlD_r;
    reg [31:0] RD1_D_r, RD2_D_r, Imm_Ext_D_r;
    reg [4:0] RD_D_r, RS1_D_r, RS2_D_r;
    reg [31:0] PCD_r, PCPlus4D_r;
    reg ALUSrcA_D_r, PCTargetSrcD_r;
    
    // Forwarding Mux Wires
    wire [31:0] RD1_D_mux, RD2_D_mux;

    // --- Output Assignments (Connect Register Outputs to External Ports) ---
    assign RegWriteE = RegWriteD_r;
    assign ALUSrcE = ALUSrcD_r;
    assign MemWriteE = MemWriteD_r;
    assign ResultSrcE = ResultSrcD_r;
    assign JumpE = JumpD_r;
    assign BranchE = BranchD_r;
    assign ALUControlE = ALUControlD_r;
    assign RD1_E = RD1_D_r;
    assign RD2_E = RD2_D_r;
    assign Imm_Ext_E = Imm_Ext_D_r;
    assign RD_E = RD_D_r;
    assign PCE = PCD_r;
    assign PCPlus4E = PCPlus4D_r;
    assign RS1_E = RS1_D_r;
    assign RS2_E = RS2_D_r;
    
    // Outputs for Hazard Unit
    assign RS1_D = InstrD[19:15];
    assign RS2_D = InstrD[24:20];
    assign ALUSrcE_A = ALUSrcA_D_r;
    assign PCTargetSrcE = PCTargetSrcD_r;


    // --- Module Instantiations ---

    // Control Unit
    Control_Unit_1 control_unit (
        .Op(InstrD[6:0]), .funct3(InstrD[14:12]), .funct7(InstrD[31:25]),
        .RegWrite(RegWriteD), .ALUSrc(ALUSrcD), .MemWrite(MemWriteD),
        .ResultSrc(ResultSrcD), .Jump(JumpD), .ImmSrc(ImmSrcD),
        .ALUControl(ALUControlD), .ALUSrcA(ALUSrcA_D), .PCTargetSrc(PCTargetSrcD)
    );

    // Register File
    Register_File rf (
        .clock(clock), .reset(reset), .WE3(RegWriteW), .A1(InstrD[19:15]),
        .A2(InstrD[24:20]), .A3(RDW), .WD3(ResultW), .RD1(RD1_D), .RD2(RD2_D)
    );

    // Sign Extension
    Sign_Extend extension (
      .Input(InstrD[31:0]), .ImmSrc(ImmSrcD), .Output(Imm_Ext_D)
    );

    // Forwarding Muxes
    assign RD1_D_mux = (ForwardA_D == 1'b1) ? ResultW : RD1_D;
    assign RD2_D_mux = (ForwardB_D == 1'b1) ? ResultW : RD2_D;

    // --- PIPELINE REGISTERS (Synchronous Block) ---
    always @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            // Reset all registers to 0
            RegWriteD_r <= 1'b0; ALUSrcD_r <= 1'b0; MemWriteD_r <= 1'b0;
            ResultSrcD_r <= 2'b00; BranchD_r <= 3'b000; JumpD_r <= 1'b0;
            ALUControlD_r <= 4'b0000;
            RD1_D_r <= 32'h0; RD2_D_r <= 32'h0; Imm_Ext_D_r <= 32'h0;
            RD_D_r <= 5'h0; PCD_r <= 32'h0; PCPlus4D_r <= 32'h0;
            RS1_D_r <= 5'h0; RS2_D_r <= 5'h0;
            ALUSrcA_D_r <= 1'b0; PCTargetSrcD_r <= 1'b0;
        end
        
        // NEW: FLUSH LOGIC (Bubble Insertion for Branch or Load Stall)
        else if (FlushE == 1'b1 || FlushD == 1'b1) begin
            // Clear Control Signals (Bubble/NOP)
            RegWriteD_r <= 1'b0; ALUSrcD_r <= 1'b0; MemWriteD_r <= 1'b0;
            ResultSrcD_r <= 2'b00; BranchD_r <= 3'b000; JumpD_r <= 1'b0;
            ALUControlD_r <= 4'b0000;
            ALUSrcA_D_r <= 1'b0;
            
            // Note: Data signals (RD1_D_r, etc.) are often ignored during a flush
            // but for completeness, we keep them cleared in reset only.
        end
        
        // NEW: STALL LOGIC (Hold values for Load-Use)
        else if (StallD == 1'b1) begin
             // Hold previous values (do nothing)
        end
        
        // NORMAL OPERATION
        else begin
            RegWriteD_r <= RegWriteD;
            ALUSrcD_r <= ALUSrcD;
            MemWriteD_r <= MemWriteD;
            ResultSrcD_r <= ResultSrcD;
            BranchD_r <= 3'b000;
            JumpD_r <= JumpD;
            ALUControlD_r <= ALUControlD;
            RD1_D_r <= RD1_D_mux;
            RD2_D_r <= RD2_D_mux;
            Imm_Ext_D_r <= Imm_Ext_D;
            RD_D_r <= InstrD[11:7];
            PCD_r <= PCD;
            PCPlus4D_r <= PCPlus4D;
            RS1_D_r <= InstrD[19:15];
            RS2_D_r <= InstrD[24:20];
            ALUSrcA_D_r <= ALUSrcA_D;
            PCTargetSrcD_r <= PCTargetSrcD;
        end
    end

endmodule