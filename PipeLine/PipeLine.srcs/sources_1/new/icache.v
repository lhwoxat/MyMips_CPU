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



/*
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
/*
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

endmodule*/
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/25 21:30:12
// Design Name: 
// Module Name: i_cache1
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
module i_cache1 #(
    parameter ADDR_WIDTH = 32,
    parameter CACHE_LINE_SIZE = 8,
    parameter CACHE_WAY_SIZE = 1,
    parameter CACHE_LINE_NUM = 128
)(
    input wire clk,
    input wire rst, 
    //cpu
    input wire cpu_instr_ena,  //~rst
    input wire [31:0] cpu_instr_addr,
    //input wire cpu_stall_control

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
    localparam INDEX_WIDTH = $clog2(CACHE_LINE_NUM);  //index_width = 7
    localparam OFFSET_WIDTH =$clog2(CACHE_LINE_SIZE);  //offset width = 3
    localparam TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH - Byte_c;  //tag width = 20

    initial begin
        if(TAG_WIDTH <= 0) begin
            $error("Wrong Tag Width!");
            $finish;
        end
    end
/*
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
*/

    //cpu value
    wire [TAG_WIDTH -1 :0]  tag_cpu = cpu_instr_addr [ADDR_WIDTH-1 : 2 + OFFSET_WIDTH + INDEX_WIDTH]; //ADDR_WIDTH - TAG_WIDTH +1
    wire [INDEX_WIDTH -1 :0] index_cpu = cpu_instr_addr [2+OFFSET_WIDTH+INDEX_WIDTH-1 : 2+OFFSET_WIDTH];
    wire [OFFSET_WIDTH-1:0] offset_cpu = cpu_instr_addr [2+OFFSET_WIDTH-1 : 2];



    reg [7:0]count_stall ;

/********* initial cache **************/
//tag_width = 20
    wire [INDEX_WIDTH -1 : 0] instr_ram_addr;  //index = 7
    assign instr_ram_addr = index_cpu;
    wire [31 : 0] cache_block_out;
    wire [31 : 0] cache_block_in;
    wire [23:0] cache_tag_out;
    wire [23:0] cache_tag_in;
    assign cache_tag_in = {4'b0001,tag_cpu};
    assign cache_block_in = rdata;
    reg [2:0]  write_tag_en;
    reg [3:0]  write_data_en;

    //assign write_tag_en = rst? 3'b000: (cache_tag_out[19:0] != tag_cpu)? 3'b111 :3'b000;
    //cache_tag_out[19:0] == tag_cpu;
    
    instr_ram_tag_Part instr_ram_tag_p (
    .clka(clk),    // input wire clka
    .ena(~rst),      // input wire ena
    .wea(write_tag_en),      // input wire [2 : 0] wea
    .addra(instr_ram_addr),  // input wire [6 : 0] addra
    .dina(cache_tag_in),    // input wire [23 : 0] dina
    .douta(cache_tag_out)  // output wire [23 : 0] douta
    );

    reg k;
    always @(posedge clk) begin
        if(rst) begin
            k <= 1'b0;
        end else begin
            k <= 1'b1;
        end
    end
    wire miss;
    assign miss = cpu_instr_ena? (cache_tag_out[20] ? cache_tag_out[19:0] != tag_cpu : 1'b1) :1'b1;

    wire [9:0] instr_ram_data_index;
    reg [2:0] next_offset_set;
    reg [2:0] offset_set;
    //assign offset_set = (cur_state == )
    reg [2:0]  final_offset;
    
    localparam [1:0] READ_IDLE = 2'b00;
    localparam [1:0] READ_ADDR = 2'b01;
    localparam [1:0] READ_DATA = 2'b11;
    reg        [1:0] cur_state, next_state;
    reg        [7:0] cur_count, next_count;

    always @(*) begin
        if(rst)begin
            final_offset = 3'b000;
        end else if (cur_state == 2'b11)begin
            if (next_offset_set == 3'b000) begin
                final_offset = 3'b111;
            end else begin
                final_offset = next_offset_set -1'b1;
            end
        end  else begin
            final_offset = next_offset_set;
        end
    end

    //assign final_offset= cur_state == 2'b11? next_offset_set ==0?3'b111 : next_offset_set-1 :next_offset_set; 
    assign instr_ram_data_index = {index_cpu,final_offset};

    instr_ram_data_Part instr_ram_data_p (
    .clka(clk),    // input wire clka
    .ena(cpu_instr_ena),      // input wire ena
    .wea(write_data_en),      // input wire [3 : 0] wea
    .addra(instr_ram_data_index),  // input wire [9 : 0] addra
    .dina(cache_block_in),    // input wire [31 : 0] dina
    .douta(cache_block_out)  // output wire [31 : 0] douta
    );


    always @(posedge clk) begin
        if (rst) begin
            count_stall <= 8'b0000_0000;
        end else begin
            count_stall <= cur_count;
        end
    end
/*
    //mem value
    wire [TAG_WIDTH -1 : 0] tag_mem = i_tag_mem [index_cpu];
    wire [31:0] data_mem =i_data_mem [index_cpu][offset_cpu*32+:32]; // means i_data_mem[index_cpu][offset_cpu*32+32 -1 :offset*32]
    wire valid_mem = i_valid_mem[index_cpu];
*/



    //AXI states
/*   
    localparam [1:0] READ_IDLE = 2'b00;
    localparam [1:0] READ_ADDR = 2'b01;
    localparam [1:0] READ_DATA = 2'b11;
    reg        [1:0] cur_state, next_state;
    reg        [7:0] cur_count, next_count;
*/
    //cpu output
    reg [31:0] cpu_instr_data_t;
    wire [31:0] cpu_instr_data_t_next;
    wire cpu_instr_next_valid;
    
    assign cpu_instr_data_t_next = rst? 32'h0000_0000 : miss? 32'h0000_0000 : cache_block_out;
    assign cpu_instr_next_valid = rst? 1'b0 : (cur_state == READ_IDLE) ? ~miss :1'b0;  //如果有效 则不需要stall 故~cpu_instr_next_valid
    
    assign cpu_instr_data = cpu_instr_data_t_next;
    assign stall_all = (~cpu_instr_next_valid); 
    // || count_stall == 8'h01
    
    //update output signals
    always @(posedge clk) begin  //not clk control
        if(rst)begin
            cpu_instr_data_t <= 32'h0000_0000;
        end else begin
            cpu_instr_data_t <= cpu_instr_data_t_next;
        end
    end
    //   miss = cpu_instr_ena? (cache_tag_out[20] ? cache_tag_out[19:0] != tag_cpu : 1'b1) :1'b1;
    wire axi_ena;  //axi  enable
    assign axi_ena = rst? 1'b0 : cpu_instr_ena && miss;  //miss and cpu_instr_ena means axi to i-ram

    wire [31:0] cache_line_addr; //
    assign cache_line_addr = {cpu_instr_addr[ADDR_WIDTH-1 : OFFSET_WIDTH+2],{(OFFSET_WIDTH+2){1'b0}}};

    //AXI FSM NEXT STATE
    always @(*) begin
        if(rst)begin
            next_state = READ_IDLE;
            next_count = 8'b0000_0000;
            next_offset_set = 3'b000;
        end else begin
            case(cur_state)
                READ_IDLE:begin
//                  next_state = (axi_ena!=1'b1 && axi_ena != 1'b0)?READ_IDLE: axi_ena? READ_ADDR:READ_IDLE;  //if hit -> READ_IDLE
                    next_state = (k == 1'b0)? READ_IDLE: axi_ena? READ_ADDR:READ_IDLE;  //if hit -> READ_IDLE
                    next_count = 8'b0000_0000;
                    next_offset_set = (k == 1'b0)? offset_cpu : axi_ena? 3'b000 : offset_cpu;
                end
                READ_ADDR:begin
                    next_state = arready? READ_DATA :READ_ADDR;
                    next_count = arready? CACHE_LINE_SIZE : next_count;
                    next_offset_set = arready? 3'b000 : next_offset_set;
                end
                READ_DATA:begin
                    next_state = rlast? READ_IDLE :READ_DATA;
                    next_count = rlast? 8'b0000_0000 : cur_count - 1;
                    next_offset_set = rlast? offset_cpu : offset_set + 1;
                end
                default :begin
                    next_state = READ_IDLE;
                    next_count = 8'b0000_0000;
                    next_offset_set = offset_cpu;
                end
            endcase
        end
    end

    //update AXI FSM
    always @(posedge clk) begin
        if(rst)begin
            offset_set <= 3'b000;
            cur_state <= READ_IDLE;
            cur_count <= 8'b0000_0000;

        end else begin
            offset_set <= next_offset_set;
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
                    write_tag_en <= 3'b000;
                    write_data_en <= 4'b0000;
                    araddr <= 32'h0000_0000;
                    arlen <= 8'b0000_0000;
                    arvalid <= 1'b0;
                end
                READ_ADDR:begin
                    write_tag_en <= 3'b000;
                    write_data_en <= 4'b0000;
                    araddr <= cache_line_addr;
                    arlen <= CACHE_LINE_SIZE-1;
                    arvalid <= 1'b1;
                end
                READ_DATA:begin
                    araddr <= 32'h0000_0000;
                    arlen <= 8'b0000_0000;
                    arvalid <= 1'b0;
                    if(cur_count > 0) begin
                    write_tag_en = 3'b111;
                    write_data_en = 4'b1111;
/*                    
                    i_data_mem  [index_cpu][32*(CACHE_LINE_SIZE - cur_count )+:32] <= rdata;
                    i_tag_mem   [index_cpu]     <= tag_cpu;
                    i_valid_mem [index_cpu]     <= 1'b1;
*/
                    end
                end
                default:begin
                    write_tag_en <= 3'b000;
                    write_data_en <= 4'b0000;
                    araddr <= 32'h0000_0000;
                    arlen <= 8'b0000_0000;
                    arvalid <= 1'b0;
                end
            endcase
        end
    end

endmodule
