`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2025 14:49:07
// Design Name: 
// Module Name: sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sim();
reg [31:0] a,b;
wire [31:0] product;
wire error, zero;
posit_multiplier uut(
.a(a), .b(b), .product(product), .error(error), .zero(zero));
initial begin
a = 32'b00110011001100110011001100110011 ;b=32'b00110101010101010101010101010101 ; #10;
$finish();
end
endmodule
    