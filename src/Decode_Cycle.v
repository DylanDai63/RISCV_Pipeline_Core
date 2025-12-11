// `include "Control_Unit_1.v"
// `include "Register_File.v"
// `include "Sign_Extend.v"
// `include "Mux_2_1_32.v"

module Decode_Cycle(
    clock, reset, InstrD, PCD, PCPlus4D, RegWriteW, RDW, ResultW, 
    RegWriteE, ALUSrcE, MemWriteE, ResultSrcE, JumpE, BranchE, ALUControlE, 
    RD1_E, RD2_E, Imm_Ext_E, RD_E, PCE, PCPlus4E, RS1_D, RS2_D, RS1_E, RS2_E, 
    ForwardA_D, ForwardB_D,
    // NEW OUTPUTS for JALR/AUIPC
    ALUSrcE_A, PCTargetSrcE
);

    // Declaring I/O
    input clock, reset, RegWriteW;
    input [4:0] RDW;
    input [31:0] InstrD, PCD, PCPlus4D, ResultW;
    input ForwardA_D, ForwardB_D;

    output RegWriteE, ALUSrcE, MemWriteE, JumpE;
    output [2:0] BranchE;
    output [1:0] ResultSrcE;
    output [3:0] ALUControlE;
    output [31:0] RD1_E, RD2_E, Imm_Ext_E;
    output [4:0] RS1_E, RS2_E, RD_E;
    output [31:0] PCE, PCPlus4E;
    output [4:0] RS1_D, RS2_D;
    
    // NEW OUTPUTS DECLARATION
    output ALUSrcE_A, PCTargetSrcE;

    // Internal Wires
    wire RegWriteD, ALUSrcD, MemWriteD, JumpD;
    wire [2:0] BranchD;
    wire [1:0] ResultSrcD;
    wire [3:0] ALUControlD;
    wire [2:0] ImmSrcD;
    wire [31:0] RD1_D, RD2_D, Imm_Ext_D;
    
    // NEW INTERNAL WIRES
    wire ALUSrcA_D, PCTargetSrcD;

    // Registers for Pipelining (D -> E)
    reg RegWriteD_r, ALUSrcD_r, MemWriteD_r, JumpD_r;
    reg [2:0] BranchD_r;
    reg [1:0] ResultSrcD_r;
    reg [3:0] ALUControlD_r;
    reg [31:0] RD1_D_r, RD2_D_r, Imm_Ext_D_r;
    reg [4:0] RD_D_r, RS1_D_r, RS2_D_r;
    reg [31:0] PCD_r, PCPlus4D_r;
    
    // NEW PIPELINE REGISTERS
    reg ALUSrcA_D_r, PCTargetSrcD_r;

    // Forwarding Mux Wires
    wire [31:0] RD1_D_mux, RD2_D_mux;

    // Assignments for Outputs
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
    assign RS1_D = InstrD[19:15];
    assign RS2_D = InstrD[24:20];
    
    // NEW OUTPUT ASSIGNMENTS
    assign ALUSrcE_A = ALUSrcA_D_r;
    assign PCTargetSrcE = PCTargetSrcD_r;

    // --- Modules Instantiation ---

    // Control Unit
    Control_Unit_1 control_unit (
        .Op(InstrD[6:0]),
        .funct3(InstrD[14:12]),
        .funct7(InstrD[31:25]),
        .RegWrite(RegWriteD),
        .ALUSrc(ALUSrcD),
        .MemWrite(MemWriteD),
        .ResultSrc(ResultSrcD),
        .Jump(JumpD),
        //.Branch(BranchD), // Note: Make sure your Control_Unit_1 has this port, or use Internal logic
        .ImmSrc(ImmSrcD),
        .ALUControl(ALUControlD),
        // NEW CONNECTIONS
        .ALUSrcA(ALUSrcA_D),
        .PCTargetSrc(PCTargetSrcD)
    );

    // Register File
    Register_File rf (
        .clock(clock),
        .reset(reset),
        .WE3(RegWriteW),
        .A1(InstrD[19:15]),
        .A2(InstrD[24:20]),
        .A3(RDW),
        .WD3(ResultW),
        .RD1(RD1_D),
        .RD2(RD2_D)
    );

    // Sign Extension
    Sign_Extend extension (
      .Input(InstrD[31:0]),
        .ImmSrc(ImmSrcD),
        .Output(Imm_Ext_D)
    );

    // Forwarding Muxes (Handling Data Hazards in Decode Stage)
    assign RD1_D_mux = (ForwardA_D == 1'b1) ? ResultW : RD1_D;
    assign RD2_D_mux = (ForwardB_D == 1'b1) ? ResultW : RD2_D;

    // --- Pipeline Registers (Synchronous Block) ---
    always @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            RegWriteD_r <= 1'b0;
            ALUSrcD_r <= 1'b0;
            MemWriteD_r <= 1'b0;
            ResultSrcD_r <= 2'b00;
            BranchD_r <= 3'b000;
            JumpD_r <= 1'b0;
            ALUControlD_r <= 4'b0000;
            RD1_D_r <= 32'h00000000;
            RD2_D_r <= 32'h00000000;
            Imm_Ext_D_r <= 32'h00000000;
            RD_D_r <= 5'h00;
            PCD_r <= 32'h00000000;
            PCPlus4D_r <= 32'h00000000;
            RS1_D_r <= 5'h00;
            RS2_D_r <= 5'h00;
            // Reset New Registers
            ALUSrcA_D_r <= 1'b0;
            PCTargetSrcD_r <= 1'b0;
        end
        else begin
            RegWriteD_r <= RegWriteD;
            ALUSrcD_r <= ALUSrcD;
            MemWriteD_r <= MemWriteD;
            ResultSrcD_r <= ResultSrcD;
            // Assuming Control Unit handles Branch decoding internally to output 3-bit BranchD
            // If Control Unit outputs 1-bit, you might need: BranchD_r <= {2'b0, BranchD};
            // Based on your previous Control_Unit_1, it outputs [2:0] Branch, so this is fine:
            // If connection is missing above, ensure Control_Unit_1 is updated.
            // For now assuming existing wires match.
             BranchD_r <= 3'b000; // Placeholder if Control Unit doesn't output Branch bus
            // NOTE: You must verify if your Control_Unit_1 has .Branch(BranchD) port.
            
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
            
            // Update New Registers
            ALUSrcA_D_r <= ALUSrcA_D;
            PCTargetSrcD_r <= PCTargetSrcD;
        end
    end

endmodule