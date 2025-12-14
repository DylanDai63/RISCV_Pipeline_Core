module Hazard_Unit(
    input reset,
    input RegWriteM, RegWriteW,
    input [4:0] RD_M, RD_W, Rs1_D, Rs2_D, Rs1_E, Rs2_E,
    
    // NEW INPUTS for Load-Use Detection
    input ResultSrcE0, // LSB of ResultSrcE (1 if instruction in Execute is a Load)
    input [4:0] RD_E,  // Destination register in Execute stage
    
    output [1:0] ForwardAE, ForwardBE,
    output ForwardAD, ForwardBD,
    
    // NEW OUTPUTS for Stalling and Flushing
    output StallF,
    output StallD,
    output FlushE
);

    // Forwarding Logic for Execute Stage
    assign ForwardAE = (reset == 1'b1) ? 2'b00 : 
                       ((RegWriteM == 1'b1) & (RD_M != 5'b0) & (RD_M == Rs1_E)) ? 2'b10 :
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs1_E)) ? 2'b01 : 2'b00;
                       
    assign ForwardBE = (reset == 1'b1) ? 2'b00 : 
                       ((RegWriteM == 1'b1) & (RD_M != 5'b0) & (RD_M == Rs2_E)) ? 2'b10 :
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs2_E)) ? 2'b01 : 2'b00;

    // Forwarding Logic for Decode Stage (Phase 2 Improvement)
    assign ForwardAD = (reset == 1'b1) ? 1'b0 : 
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs1_D)) ? 1'b1 : 1'b0;
                       
    assign ForwardBD = (reset == 1'b1) ? 1'b0 : 
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs2_D)) ? 1'b1 : 1'b0;

    // Load-Use Hazard Detection
    // Condition: Execute instr is Load (ResultSrcE0==1) AND Dest matches Source in Decode
    wire lwStall;
    assign lwStall = (ResultSrcE0 == 1'b1) & (RD_E != 5'b0) & 
                     ((RD_E == Rs1_D) | (RD_E == Rs2_D));

    // Stall Signals
    assign StallF = lwStall;
    assign StallD = lwStall;
    assign FlushE = lwStall;

endmodule