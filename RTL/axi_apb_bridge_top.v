
`timescale 1ns/1ps
module axi_apb_bridge #(parameter AW = 32, DW = 32, NUM_REGS = 8) (
    input  wire                aclk, aresetn,
    // AXI4-Lite slave
    input  wire                awvalid, output wire awready, input wire [AW-1:0] awaddr,
    input  wire                wvalid,  output wire wready,  input wire [DW-1:0] wdata,
    input  wire [DW/8-1:0] wstrb,
    output wire                bvalid,  input  wire bready,  output wire [1:0] bresp,
    input  wire                arvalid, output wire arready, input wire [AW-1:0] araddr,
    output wire                rvalid,  input  wire rready,
    output wire [DW-1:0]   rdata,   output wire [1:0] rresp,
    // APB3 master
    output wire                psel, penable, pwrite,
    output wire [AW-1:0]   paddr,
    output wire [DW-1:0]   pwdata,
    input  wire [DW-1:0]   prdata,
    input  wire                pready, pslverr
);

    wire wr_req, rd_req, wr_done, rd_done, addr_valid;
    wire apb_write, apb_start, apb_done, apb_err;

    wire [AW-1:0] wr_addr, rd_addr, dec_addr, apb_addr;
    wire [DW-1:0] wr_data, rd_data, apb_rdata, apb_wdata;

    wire [3:0] wr_strb;
    wire [1:0] wr_resp, rd_resp;

    axi_write_control u_wr (
        .aclk(aclk), .aresetn(aresetn),
        .awvalid(awvalid), .awready(awready), .awaddr(awaddr),
      .wvalid(wvalid), .wready(wready), .wdata(wdata), .wstrb(wstrb),
        .bvalid(bvalid), .bready(bready), .bresp(bresp),
        .wr_req(wr_req), .wr_addr(wr_addr), .wr_data(wr_data),
        .wr_strb(wr_strb),
        .wr_done(wr_done), .wr_resp(wr_resp)
    );

    axi_read_control u_rd (
        .aclk(aclk), .aresetn(aresetn),
        .arvalid(arvalid), .arready(arready), .araddr(araddr),
        .rvalid(rvalid), .rready(rready), .rdata(rdata), .rresp(rresp),
        .rd_req(rd_req), .rd_addr(rd_addr),
        .rd_done(rd_done), .rd_data(rd_data), .rd_resp(rd_resp)
    );

    address_decoder #(NUM_REGS) u_dec (
        .addr(dec_addr), .addr_valid(addr_valid)
    );

    bridge_fsm #(AW,DW) u_fsm (
        .clk(aclk), .rst_n(aresetn),
        .wr_req(wr_req), .wr_addr(wr_addr),
        .wr_data(wr_data), .wr_strb(wr_strb),
        .rd_req(rd_req), .rd_addr(rd_addr),
        .addr_valid(addr_valid),
        .apb_done(apb_done), .apb_err(apb_err),
        .apb_rdata(apb_rdata),
        .dec_addr(dec_addr),
        .apb_start(apb_start), .apb_write(apb_write),
        .apb_addr(apb_addr), .apb_wdata(apb_wdata),
        .wr_done(wr_done), .rd_done(rd_done),
        .wr_resp(wr_resp), .rd_resp(rd_resp),
        .rd_data(rd_data)
    );

    apb_master_controller u_apb (
        .pclk(aclk), .presetn(aresetn),
        .apb_start(apb_start), .apb_write(apb_write),
        .apb_addr(apb_addr), .apb_wdata(apb_wdata),
        .pready(pready), .pslverr(pslverr), .prdata(prdata),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata),
        .apb_done(apb_done), .apb_rdata(apb_rdata),
        .apb_err(apb_err)
    );

endmodule
