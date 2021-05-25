`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/26 08:45:57
// Design Name: 
// Module Name: icache
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

`include "defines.v"
module icache #(
    parameter ADDR_WIDTH = 32,
    parameter CACHE_LINE_SIZE = 8,
    parameter CACHE_WAY_SIZE = 1,
    parameter CACHE_LINE_NUM = 64
)(
    input wire clk,
    input wire rst, 
    //cpu
    input wire cpu_instr_ena,
    input wire [31:0] cpu_instr_addr,
    output wire [31:0] cpu_instr_data,
    output wire stall_all,
    //axi
    //aw   with out awcache awlock  awprot
    output wire [3:0]   awid,
    output wire [31:0]  awaddr,
    output wire [7:0]   awlen,
    output wire [2:0]   awsize,
    output wire [1:0]   awburst,
    output wire         awvalid,
    input  wire         awready,
    //w
    output wire [31 : 0] wdata,
    output wire [3 : 0] wstrb,//
    output wire wlast,
    output wire wvalid,
    input wire wready,
    //ar
    output wire [3 : 0] arid,
    output reg [31 : 0] araddr,
    output reg [7 : 0] arlen,
    output wire [2 : 0] arsize,
    output wire [1 : 0] arburst,
    output reg  arvalid,
    input wire arready,
    //r
    input wire [3 : 0] rid,
    input wire [31 : 0] rdata,
    input wire [1 : 0] rresp,
    input wire rlast,
    input wire rvalid,
    output wire  rready,
    //b
    input wire [3 : 0] bid,
    input wire [1 : 0] bresp,
    input wire bvalid,
    output wire bready
);
    assign awid  = 4'h0;
    assign awaddr  = 32'h0000_0000;
    assign awlen  = 8'h00;
    assign awsize  = 3'h0;
    assign awburst  = 2'h0;
    assign awvalid  = 1'b0;
    assign wdata  = 32'h0000_0000;
    assign wstrb  = 4'h0;
    assign wlast  = 1'b0;
    assign wvalid  = 1'b0;
    assign bready  = 1'b0;

    // default signals
    assign arid = 4'h0;  //not used so far.
    assign arsize = 3'b010;  //means 2^2  while 3'b011 means 2^3
    assign arburst = 2'b01; //means incre, which is used in ram.
    //2'b00 means fixed  2'b11 means wrap, which is mainly used in cache.

    //define constant
    assign rready = 1'b1;  //always accept data from ram(slaver) so far.
    localparam Byte_c = 2;
    localparam INDEX_WIDTH = $clog2(CACHE_LINE_NUM);
    localparam OFFSET_WIDTH =$clog2(CACHE_LINE_SIZE);
    localparam TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH - Byte_c;

    initial begin
        if(TAG_WIDTH <= 0) begin
            $error("Wrong Tag Width!");
            $finish;
        end
    end

    //initiate memory
    reg  i_valid_mem [CACHE_LINE_NUM -1:0];
    reg  [32 * CACHE_LINE_SIZE-1:0] i_data_mem [CACHE_LINE_NUM-1:0];
    reg  [TAG_WIDTH-1:0] i_tag_mem [CACHE_LINE_NUM-1:0];

    integer  i;
    initial begin
        for(i = 0; i < CACHE_LINE_NUM; i = i+1) begin
            i_data_mem[i]  = {(32 * CACHE_LINE_SIZE){1'b0}};
            i_tag_mem[i] = {(TAG_WIDTH){1'b0}};
            i_valid_mem[i] = 1'b0;
        end
    end

    //cpu value
    wire [TAG_WIDTH -1 :0]  tag_cpu = cpu_instr_addr [ADDR_WIDTH-1 : 2 + OFFSET_WIDTH + INDEX_WIDTH]; //ADDR_WIDTH - TAG_WIDTH +1
    wire [INDEX_WIDTH -1 :0] index_cpu = cpu_instr_addr [2+OFFSET_WIDTH+INDEX_WIDTH-1 : 2+OFFSET_WIDTH];
    wire [OFFSET_WIDTH-1:0] offset_cpu = cpu_instr_addr [2+OFFSET_WIDTH-1 : 2];

    //mem value
    wire [TAG_WIDTH -1 : 0] tag_mem = i_tag_mem [index_cpu];
    wire [31:0] data_mem =i_data_mem [index_cpu][offset_cpu*32+:32]; // means i_data_mem[index_cpu][offset_cpu*32+32 -1 :offset*32]
    wire valid_mem = i_valid_mem[index_cpu];

    wire miss;
    assign miss = cpu_instr_ena? (valid_mem ? tag_mem != tag_cpu : 1'b1) :1'b1;


    //AXI states
    localparam [1:0] READ_IDLE = 2'b00;
    localparam [1:0] READ_ADDR = 2'b01;
    localparam [1:0] READ_DATA = 2'b11;
    reg        [1:0] cur_state, next_state;
    reg        [7:0] cur_count, next_count;

    //cpu output
    reg [31:0] cpu_instr_data_t;
    wire [31:0] cpu_instr_data_t_next;
    wire cpu_instr_next_valid;
    
    assign cpu_instr_data_t_next = rst? 32'h0000_0000 : miss? 32'h0000_0000 : data_mem;
    assign cpu_instr_next_valid = rst? 1'b0 : (cur_state == READ_IDLE) ? ~miss :1'b0;  //如果有效 则不需要stall 故~cpu_instr_next_valid
    
    assign cpu_instr_data = cpu_instr_data_t;
    assign stall_all = ~cpu_instr_next_valid; 
    
    //update output signals
    always @(posedge clk) begin
        if(rst)begin
            cpu_instr_data_t <= 32'h0000_0000;
        end else begin
            cpu_instr_data_t <= cpu_instr_data_t_next;
        end
    end
    //miss = cpu_instr_ena? (valid_mem ? tag_mem != tag_cpu : 1'b1) :1'b1;
    wire axi_ena;  //axi  enable
    assign axi_ena = rst? 1'b0 : cpu_instr_ena && miss;  //miss and  cpu_instr_ena means axi to i-ram

    wire [31:0] cache_line_addr; //
    assign cache_line_addr = {cpu_instr_addr[ADDR_WIDTH-1 : OFFSET_WIDTH+2],{(OFFSET_WIDTH+2){1'b0}}};

    //AXI FSM NEXT STATE
    always @(*) begin
        if(rst)begin
            next_state = READ_IDLE;
            next_count = 8'b0000_0000;
        end else begin
            case(cur_state)
                READ_IDLE:begin
                    next_state = axi_ena? READ_ADDR:READ_IDLE;  //if hit -> READ_IDLE
                    next_count = 8'b0000_0000;                    
                end
                READ_ADDR:begin
                    next_state = arready? READ_DATA :READ_ADDR;
                    next_count = arready? CACHE_LINE_SIZE : next_count;
                end
                READ_DATA:begin
                    next_state = rlast? READ_IDLE :READ_DATA;
                    next_count = rlast? 8'b0000_0000 : cur_count - 1;
                end
                default :begin
                    next_state = READ_IDLE;
                    next_count = 8'b0000_0000;
                end
            endcase
        end
    end

    //update AXI FSM
    always @(posedge clk) begin
        if(rst)begin
            cur_state <= READ_IDLE;
            cur_count <= 8'b0000_0000;
        end else begin
            cur_state <= next_state;
            cur_count <= next_count;
        end
    end
/*
    output reg [31 : 0] araddr,
    output reg [7 : 0] arlen, //num of burst
    output reg  arvalid,
*/
    //cache ----> instruction ram  Combinational logic circuit

    always @(*) begin
        if(rst)begin
            araddr <= 32'h0000_0000;
            arlen <= 8'b0000_0000;
            arvalid <= 1'b0;
        end else begin
            case (cur_state)
                READ_IDLE:begin
                    araddr <= 32'h0000_0000;
                    arlen <= 8'b0000_0000;
                    arvalid <= 1'b0;
                end
                READ_ADDR:begin
                    araddr <= cache_line_addr;
                    arlen <= CACHE_LINE_SIZE-1;
                    arvalid <= 1'b1;
                end
                READ_DATA:begin
                    araddr <= 32'h0000_0000;
                    arlen <= 8'b0000_0000;
                    arvalid <= 1'b0;
                    if(cur_count > 0) begin
                    i_data_mem  [index_cpu][32*(CACHE_LINE_SIZE - cur_count )+:32] <= rdata;
                    i_tag_mem   [index_cpu]     <= tag_cpu;
                    i_valid_mem [index_cpu]     <= 1'b1;
                    end
                end
                default:begin
                    araddr <= 32'h0000_0000;
                    arlen <= 8'b0000_0000;
                    arvalid <= 1'b0;
                end
            endcase
        end
    end

endmodule