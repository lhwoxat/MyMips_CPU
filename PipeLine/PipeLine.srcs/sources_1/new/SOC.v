`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/21 20:24:55
// Design Name: 
// Module Name: SOC
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


module SOC(
    input wire clk,
    input wire rst
    );

    //instr ram
    wire instr_ram_rena_soc;
    wire [3:0] instr_ram_wena_soc;
    wire [31:0] instr_ram_addr_soc;
    wire [31:0] instr_ram_wdata_soc;
    wire [31:0] instr_ram_rdata_soc;
    wire stall_cpu_imiss_soc;
    //data ram
    wire data_ram_rena_soc;
    wire [3:0] data_ram_wena_soc;
    wire [31:0] data_ram_addr_soc;
    wire [31:0] data_ram_wdata_soc;
    wire [31:0] data_ram_rdata_soc;

    PipeLine cpu_core(
        .clk(clk),
        .rst(rst),
        //instr_ram
        .instr_ram_rena_top(instr_ram_rena_soc),
        .instr_ram_wena_top(instr_ram_wena_soc),
        .instr_ram_addr_top(instr_ram_addr_soc),
        .instr_ram_wdata_top(instr_ram_wdata_soc),
        .instr_ram_rdata_top(instr_ram_rdata_soc),
        .stall_cpu_imiss_top(stall_cpu_imiss_soc),
        //data_ram
        .data_ram_rena_top(data_ram_rena_soc),
        .data_ram_wena_top(data_ram_wena_soc),
        .data_ram_addr_top(data_ram_addr_soc),
        .data_ram_wdata_top(data_ram_wdata_soc),
        .data_ram_rdata_top(data_ram_rdata_soc)
    );

    Data_Ram data_ram_noaxi (
    .clka(clk),    // input wire clka
    .ena(data_ram_rena_soc),      // input wire ena
    .wea(data_ram_wena_soc),      // input wire [3 : 0] wea
    .addra(data_ram_addr_soc[11:2]),  // input wire [9 : 0] addra
    .dina(data_ram_wdata_soc),    // input wire [31 : 0] dina
    .douta(data_ram_rdata_soc)  // output wire [31 : 0] douta
    );

    wire [3 : 0] s_axi_awid;
    wire [31 : 0] s_axi_awaddr;
    wire [7 : 0] s_axi_awlen;
    wire [2 : 0] s_axi_awsize;
    wire [1 : 0] s_axi_awburst;
    wire s_axi_awvalid;
    wire s_axi_awready;
    wire [31 : 0] s_axi_wdata;
    wire [3 : 0] s_axi_wstrb;
    wire s_axi_wlast;
    wire s_axi_wvalid;
    wire s_axi_wready;
    wire [3 : 0] s_axi_bid;
    wire [1 : 0] s_axi_bresp;
    wire s_axi_bvalid;
    wire s_axi_bready;
    wire [3 : 0] s_axi_arid;
    wire [31 : 0] s_axi_araddr;
    wire [7 : 0] s_axi_arlen;
    wire [2 : 0] s_axi_arsize;
    wire [1 : 0] s_axi_arburst;
    wire s_axi_arvalid;
    wire s_axi_arready;
    wire [3 : 0] s_axi_rid;
    wire [31 : 0] s_axi_rdata;
    wire [1 : 0] s_axi_rresp;
    wire s_axi_rlast;
    wire s_axi_rvalid;
    wire s_axi_rready;

    icache instr_cache(
    .clk(clk),
    .rst(rst), 
    //cpu
    .cpu_instr_ena(instr_ram_rena_soc),
    .cpu_instr_addr(instr_ram_addr_soc),
    .cpu_instr_data(instr_ram_rdata_soc),
    .stall_all(stall_cpu_imiss_soc),
    //axi
    //aw   with out awcache awlock  awprot
    .awid(s_axi_awid),
    .awaddr(s_axi_awaddr),
    .awlen(s_axi_awlen),
    .awsize(s_axi_awsize),
    .awburst(s_axi_awburst),
    .awvalid(s_axi_awvalid),
    .awready(s_axi_awready),
    //w
    .wdata(s_axi_wdata),
    .wstrb(s_axi_wstrb),//
    .wlast(s_axi_wlast),
    .wvalid(s_axi_wvalid),
    .wready(s_axi_wready),
    //ar
    .arid(s_axi_arid),
    .araddr(s_axi_araddr),
    .arlen(s_axi_arlen),
    .arsize(s_axi_arsize),
    .arburst(s_axi_arburst),
    .arvalid(s_axi_arvalid),
    .arready(s_axi_arready),
    //r
    .rid(s_axi_rid),
    .rdata(s_axi_rdata),
    .rresp(s_axi_rresp),
    .rlast(s_axi_rlast),
    .rvalid(s_axi_rvalid),
    .rready(s_axi_rready),
    //b
    .bid(s_axi_bid),
    .bresp(s_axi_bresp),
    .bvalid(s_axi_bvalid),
    .bready(s_axi_bready)
    );

    AXI_RAM_I ram_axi (
    .rsta_busy(rsta_busy),          // output wire rsta_busy
    .rstb_busy(rstb_busy),          // output wire rstb_busy
    .s_aclk(clk),                // input wire s_aclk
    .s_aresetn(~rst),          // input wire s_aresetn
    .s_axi_awid(s_axi_awid),        // input wire [3 : 0] s_axi_awid
    .s_axi_awaddr(s_axi_awaddr),    // input wire [31 : 0] s_axi_awaddr
    .s_axi_awlen(s_axi_awlen),      // input wire [7 : 0] s_axi_awlen
    .s_axi_awsize(s_axi_awsize),    // input wire [2 : 0] s_axi_awsize
    .s_axi_awburst(s_axi_awburst),  // input wire [1 : 0] s_axi_awburst
    .s_axi_awvalid(s_axi_awvalid),  // input wire s_axi_awvalid
    .s_axi_awready(s_axi_awready),  // output wire s_axi_awready
    .s_axi_wdata(s_axi_wdata),      // input wire [31 : 0] s_axi_wdata
    .s_axi_wstrb(s_axi_wstrb),      // input wire [3 : 0] s_axi_wstrb
    .s_axi_wlast(s_axi_wlast),      // input wire s_axi_wlast
    .s_axi_wvalid(s_axi_wvalid),    // input wire s_axi_wvalid
    .s_axi_wready(s_axi_wready),    // output wire s_axi_wready
    .s_axi_bid(s_axi_bid),          // output wire [3 : 0] s_axi_bid
    .s_axi_bresp(s_axi_bresp),      // output wire [1 : 0] s_axi_bresp
    .s_axi_bvalid(s_axi_bvalid),    // output wire s_axi_bvalid
    .s_axi_bready(s_axi_bready),    // input wire s_axi_bready
    .s_axi_arid(s_axi_arid),        // input wire [3 : 0] s_axi_arid
    .s_axi_araddr(s_axi_araddr),    // input wire [31 : 0] s_axi_araddr
    .s_axi_arlen(s_axi_arlen),      // input wire [7 : 0] s_axi_arlen
    .s_axi_arsize(s_axi_arsize),    // input wire [2 : 0] s_axi_arsize
    .s_axi_arburst(s_axi_arburst),  // input wire [1 : 0] s_axi_arburst
    .s_axi_arvalid(s_axi_arvalid),  // input wire s_axi_arvalid
    .s_axi_arready(s_axi_arready),  // output wire s_axi_arready
    .s_axi_rid(s_axi_rid),          // output wire [3 : 0] s_axi_rid
    .s_axi_rdata(s_axi_rdata),      // output wire [31 : 0] s_axi_rdata
    .s_axi_rresp(s_axi_rresp),      // output wire [1 : 0] s_axi_rresp
    .s_axi_rlast(s_axi_rlast),      // output wire s_axi_rlast
    .s_axi_rvalid(s_axi_rvalid),    // output wire s_axi_rvalid
    .s_axi_rready(s_axi_rready)    // input wire s_axi_rready
    );
endmodule
