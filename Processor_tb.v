`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Korea Univ. DIGITAL SYSTEM DESIGN AND LABORATORY
// Engineer: Jihyuk Park
// 
// Create Date: 2021/12/14 20:38:44
// Design Name: Processor_tb
// Module Name: Processor_tb
// Project Name: FISR_test
// Target Devices: HBE-Combo II-DLD
// Tool Versions: Vivado 2019
// Description: Specialized FPU for Fast Inverse Square Root Algorithm
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Processor_tb();

reg CLK = 0, RST = 1;
always #5 CLK = ~CLK;

reg [3:0] dot;
reg start_process;
reg [3:0] iDEC6, iDEC5, iDEC4, iDEC3, iDEC2, iDEC1, iDEC0;
wire [3:0] oDEC7, oDEC6, oDEC5, oDEC4, oDEC3, oDEC2, oDEC1, oDEC0;
wire DONE;
wire state;
wire [31:0] result_float32;

Processor P0(
    CLK, RST,
    dot,
    start_process,
    iDEC6, iDEC5, iDEC4, iDEC3, iDEC2, iDEC1, iDEC0,
    oDEC7, oDEC6, oDEC5, oDEC4, oDEC3, oDEC2, oDEC1, oDEC0,
    DONE,
    state,
    result_float32
);

initial begin
    #3 RST = 0;
    #3 RST = 1;
    // #5 iDEC6 <= 7; iDEC5 <= 6; iDEC4 <= 5; iDEC3 <= 10; iDEC2 <= 3; iDEC1 <= 2; iDEC0 <= 1;
    #5 iDEC6 <= 1; iDEC5 <= 2; iDEC4 <= 3; iDEC3 <= 10; iDEC2 <= 4; iDEC1 <=5; iDEC0 <= 6;
    dot <= 4'b1000;
    start_process <= 1;
end

endmodule
