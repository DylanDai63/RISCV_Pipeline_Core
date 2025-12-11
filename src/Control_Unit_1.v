module Control_Unit_1(
    input [6:0] Op,
    input [6:0] funct7,
    input [2:0] funct3,
    output RegWrite,
    output ALUSrc,
    output MemWrite,
    output [1:0] ResultSrc,
    output Jump,
    output [2:0] Branch,   // 3-bit output to Decode Stage
    output [2:0] ImmSrc,
    output [3:0] ALUControl,
    output ALUSrcA,
    output PCTargetSrc
);

    wire [1:0] ALUOp;
    wire isBranch; // 1-bit internal wire connecting Main_Decoder to Branch_Decoder

    Main_Decoder md (
        .Op(Op),
        .RegWrite(RegWrite),
        .ImmSrc(ImmSrc),
        .ALUSrc(ALUSrc),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .Branch(isBranch), // Connects to the 1-bit wire
        .ALUOp(ALUOp),
        .Jump(Jump),
        .ALUSrcA(ALUSrcA),
        .PCTargetSrc(PCTargetSrc)
    );

    // Decodes the specific 3-bit branch type (BEQ, BNE, etc.)
    Branch_Decoder BranchOp(
        .isBranch(isBranch), // Input: 1-bit from Main Decoder
        .funct3(funct3), 
        .Branch_D(Branch)    // Output: 3-bit to Top Level
    );

    ALU_Decoder ad (
        .Op(Op),
        .funct3(funct3),
        .funct7(funct7),
        .ALUOp(ALUOp),
        .ALUControl(ALUControl)
    );

endmodule

module Main_Decoder(
    input [6:0] Op,
    output reg RegWrite,
    output reg [2:0] ImmSrc,
    output reg ALUSrc,
    output reg MemWrite,
    output reg [1:0] ResultSrc,
    output reg Branch,
    output reg [1:0] ALUOp,
    output reg Jump,
    output reg ALUSrcA,
    output reg PCTargetSrc
);

    always @(*) begin
        // Defaults
        RegWrite = 0; ImmSrc = 3'b000; ALUSrc = 0; MemWrite = 0;
        ResultSrc = 2'b00; Branch = 0; ALUOp = 2'b00; Jump = 0;
        ALUSrcA = 0; PCTargetSrc = 0; // 0 = PC_Adder, 1 = ALU

        case(Op)
            7'b0000011: begin // LW
                RegWrite = 1; ImmSrc = 3'b000; ALUSrc = 1; ResultSrc = 2'b01; ALUOp = 2'b00;
            end
            7'b0100011: begin // SW
                ImmSrc = 3'b001; ALUSrc = 1; MemWrite = 1; ALUOp = 2'b00;
            end
            7'b0110011: begin // R-Type
                RegWrite = 1; ALUOp = 2'b10;
            end
            7'b0010011: begin // I-Type ALU
                RegWrite = 1; ImmSrc = 3'b000; ALUSrc = 1; ALUOp = 2'b10;
            end
            7'b1100011: begin // BEQ/BNE (Branch)
                ImmSrc = 3'b010; ALUOp = 2'b01; Branch = 1;
            end
            7'b0110111: begin // LUI (U-Type)
                RegWrite = 1; ImmSrc = 3'b100; ALUSrc = 1; ALUOp = 2'b11; // Special Op
            end
            7'b0010111: begin // AUIPC (U-Type)
                RegWrite = 1; ImmSrc = 3'b100; ALUSrc = 1; ALUSrcA = 1; ALUOp = 2'b00; 
            end
            7'b1101111: begin // JAL (J-Type)
                RegWrite = 1; ImmSrc = 3'b011; Jump = 1; ResultSrc = 2'b10;
            end
            7'b1100111: begin // JALR (I-Type)
                RegWrite = 1; ImmSrc = 3'b000; ALUSrc = 1; Jump = 1; 
                ResultSrc = 2'b10; PCTargetSrc = 1; ALUOp = 2'b00;
            end
        endcase
    end
endmodule

module Branch_Decoder (isBranch, funct3, Branch_D);
    input isBranch;
    input [2:0] funct3;
    output [2:0] Branch_D;

    assign Branch_D = ((isBranch == 1'b1) & (funct3 == 3'b000)) ? 3'b001 :
                      ((isBranch == 1'b1) & (funct3 == 3'b001)) ? 3'b010 : 
                      ((isBranch == 1'b1) & (funct3 == 3'b100)) ? 3'b011 : 
                      ((isBranch == 1'b1) & (funct3 == 3'b101)) ? 3'b100 : 
                      ((isBranch == 1'b1) & (funct3 == 3'b110)) ? 3'b101 : 
                      ((isBranch == 1'b1) & (funct3 == 3'b111)) ? 3'b110 : 3'b000;
endmodule

module ALU_Decoder(
    input [6:0] Op,
    input [2:0] funct3,
    input [6:0] funct7,
    input [1:0] ALUOp,
    output reg [3:0] ALUControl
);
    always @(*) begin
        case(ALUOp)
            2'b00: ALUControl = 4'b0000; // ADD (LW, SW, AUIPC, JALR)
            2'b01: ALUControl = 4'b0001; // SUB (Branch)
            2'b11: ALUControl = 4'b1111; // LUI (Pass B)
            2'b10: begin // R-Type or I-Type
                case(funct3)
                    3'b000: begin
                         if (Op == 7'b0110011 && funct7[5]) ALUControl = 4'b0001; // SUB
                         else ALUControl = 4'b0000; // ADD
                    end
                    3'b001: ALUControl = 4'b0101; // SLL
                    3'b010: ALUControl = 4'b1000; // SLT
                    3'b011: ALUControl = 4'b1001; // SLTU
                    3'b100: ALUControl = 4'b0010; // XOR
                    3'b101: begin
                         if (funct7[5]) ALUControl = 4'b0111; // SRA
                         else ALUControl = 4'b0110; // SRL
                    end
                    3'b110: ALUControl = 4'b0011; // OR
                    3'b111: ALUControl = 4'b0100; // AND
                endcase
            end
        endcase
    end
endmodule