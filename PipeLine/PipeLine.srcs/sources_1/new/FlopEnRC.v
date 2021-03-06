`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/27 14:26:05
// Design Name: 
// Module Name: FlopEnRC
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


module FlopEnRC #(parameter WIDTH = 32)(
        input wire clk,
        input wire rst,
        input wire en,
        input wire clear,
        input wire [WIDTH-1:0] in,
        output reg [WIDTH-1 :0] out
    );
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            out <= {WIDTH{1'b0}};
        end
        else if (!en && clear) begin   // change
            out <= out;
        end
        else if (en && clear) begin
            out <= {WIDTH{1'b0}};
        end else if (en) begin
            out <= in;
        end
    end
endmodule
