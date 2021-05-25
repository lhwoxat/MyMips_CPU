`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/24 13:40:30
// Design Name: 
// Module Name: Soc_testsim
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


module Soc_testsim();
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
