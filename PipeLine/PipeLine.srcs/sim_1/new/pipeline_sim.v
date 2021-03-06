`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/29 19:48:16
// Design Name: 
// Module Name: SOC_sim
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


module SOC_sim();
    reg clk;
    reg rst;

    SOC SOC_mips(
        clk,
        rst
    );

    initial begin
        clk = 1'b0;
        forever begin
            #50 clk = ~clk;
        end
    end

    initial begin
        #10 rst = 1'b0;
        #100 rst = 1'b1;
        #100 rst = 1'b0;
    end
endmodule
