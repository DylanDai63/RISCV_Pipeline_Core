module Hazard_Unit(
    input reset,
    input RegWriteM, RegWriteW,
    input [4:0] RD_M, RD_W, Rs1_D, Rs2_D, Rs1_E, Rs2_E,
    input ResultSrcE0, 
    input [4:0] RD_E, 
    input PCSrcE,      // Ensure this port exists
    
    output [1:0] ForwardAE, ForwardBE,
    output ForwardAD, ForwardBD,
    output StallF,
    output StallD,
    output FlushD,     // Ensure this port exists
    output FlushE
);

    assign ForwardAE = (reset == 1'b1) ? 2'b00 : 
                       ((RegWriteM == 1'b1) & (RD_M != 5'b0) & (RD_M == Rs1_E)) ? 2'b10 :
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs1_E)) ? 2'b01 : 2'b00;
                        
    assign ForwardBE = (reset == 1'b1) ? 2'b00 : 
                       ((RegWriteM == 1'b1) & (RD_M != 5'b0) & (RD_M == Rs2_E)) ? 2'b10 :
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs2_E)) ? 2'b01 : 2'b00;

    assign ForwardAD = (reset == 1'b1) ? 1'b0 : 
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs1_D)) ? 1'b1 : 1'b0;
                        
    assign ForwardBD = (reset == 1'b1) ? 1'b0 : 
                       ((RegWriteW == 1'b1) & (RD_W != 5'b0) & (RD_W == Rs2_D)) ? 1'b1 : 1'b0;

    // Logic
    wire lwStall;
    assign lwStall = (ResultSrcE0 == 1'b1) & (RD_E != 5'b0) & 
                     ((RD_E == Rs1_D) | (RD_E == Rs2_D));

    assign StallF = lwStall;
    assign StallD = lwStall;
    assign FlushD = PCSrcE;
    assign FlushE = lwStall | PCSrcE;

endmodule