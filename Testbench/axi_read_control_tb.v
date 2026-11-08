`timescale 1ns/1ps
module axi_read_control_tb;
    logic aclk,aresetn;
    logic arvalid;
    logic [31:0]araddr;
    logic rready,rd_done;
    logic [1:0]rd_resp;
    logic [31:0]rd_data;
    logic arready,rvalid;
    logic [31:0]rdata;
    logic [1:0]rresp;
    logic rd_req;
    logic [31:0]rd_addr;
    integer errors =0;

    axi_read_control dut(.aclk(aclk),.aresetn(aresetn),.arvalid(arvalid),
    .araddr(araddr),.rready(rready),.rd_done(rd_done),.rd_resp(rd_resp),
    .rd_data(rd_data),.arready(arready),.rvalid(rvalid),.rdata(rdata),
    .rresp(rresp),.rd_req(rd_req),.rd_addr(rd_addr));

    always #5 aclk = ~aclk;
    
    task automatic check(input bit cond , input string msg);
        if(cond) $display("PASS : %s",msg);
        else begin errors++; $display(" FAIL : %s @%t ",msg ,$time); end

    endtask
    
    // drive AR and wait for the handshake edge
    task automatic send_ar(input [31:0] a);
        arvalid = 1; araddr = a;
        @(posedge aclk);
        while (!arready) @(posedge aclk);
        #1 arvalid = 0;
    endtask

    // APB side: one-cycle rd_done pulse
    task automatic apb_done(input [31:0] d, input [1:0] r);
        @(posedge aclk); #1 rd_done = 1; rd_data = d; rd_resp = r;
        @(posedge aclk); #1 rd_done = 0;
    endtask

    initial begin
        #200000 $display("TIMEOUT"); $finish;
    end

    initial begin
        aresetn = 0; arvalid = 0; araddr = 0; rready = 0;
        rd_done = 0; rd_resp = 0; rd_data = 0;
        repeat (3) @(posedge aclk);
        #1 aresetn = 1;
        #1 check(arready && !rvalid && !rd_req, "reset/idle state");

        // Test 1: normal read, busy blocking, stalled R channel
        send_ar(32'h0000_1000);
        #1 check(rd_req && rd_addr == 32'h1000 && !arready, "AR latched, rd_req up");
        arvalid = 1; araddr = 32'h0000_2000;            // new address while busy
        repeat (2) @(posedge aclk);
        #1 check(!arready && rd_addr == 32'h1000, "busy: arready low, addr unchanged");
        arvalid = 0;
        apb_done(32'hDEAD_BEEF, 2'b00);
        check(rvalid && rdata == 32'hDEAD_BEEF && rresp == 2'b00 && !rd_req,
              "rd_done loads response, rd_req clears");
        repeat (3) @(posedge aclk);
        #1 check(rvalid && rdata == 32'hDEAD_BEEF && !arready, "R stalled: response stable");
        rready = 1; @(posedge aclk); #1 rready = 0;
        check(!rvalid && arready, "R handshake done, arready back");

        // Test 2: error response forces rdata to 0
        send_ar(32'h0000_3000);
        apb_done(32'hFFFF_FFFF, 2'b10);
        check(rvalid && rdata == 32'd0 && rresp == 2'b10, "error: rdata forced to 0");
        rready = 1; @(posedge aclk); #1 rready = 0;
        check(!rvalid, "error response consumed");

        // Test 3: back-to-back read with rready already high
        rready = 1;
        send_ar(32'h0000_4000);
        apb_done(32'h1234_5678, 2'b00);
        check(rvalid && rdata == 32'h1234_5678, "rready high: response presented");
        @(posedge aclk); #1 check(!rvalid && arready, "single-cycle response, idle again");
        rready = 0;

        // Test 4: stray rd_done while idle is ignored
        apb_done(32'hAAAA_AAAA, 2'b00);
        check(!rvalid && !rd_req, "stray rd_done ignored");

        $display("---- DONE: %0d error(s) ----", errors);
        #200000 $finish;
    end


endmodule
