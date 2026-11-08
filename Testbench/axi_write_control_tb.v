`timescale 1ns/1ps
module tb_axi_write_control;
    // ---------------- Signals ----------------
    reg aclk = 0, aresetn;
    reg awvalid, wvalid, bready, wr_done;
    reg [31:0] awaddr, wdata;
    reg [3:0]  wstrb;
    reg [1:0]  wr_resp;
    wire        awready, wready, bvalid, wr_req;
    wire [1:0]  bresp;
    wire [31:0] wr_addr, wr_data;
    wire [3:0]  wr_strb;
    integer errors = 0;

    // ---------------- DUT ----------------
    axi_write_control dut (
        .aclk(aclk), .aresetn(aresetn),
        .awvalid(awvalid), .awaddr(awaddr), .awready(awready),
        .wvalid(wvalid), .wdata(wdata), .wstrb(wstrb), .wready(wready),
        .bready(bready), .bvalid(bvalid), .bresp(bresp),
        .wr_done(wr_done), .wr_resp(wr_resp), .wr_req(wr_req),
        .wr_addr(wr_addr), .wr_data(wr_data), .wr_strb(wr_strb)
    );

    always #5 aclk = ~aclk;

    // ---------------- Utility tasks ----------------
    task tick(input integer n);
        begin repeat (n) @(posedge aclk); #1; end
    endtask

    task check(input c, input [8*48:1] m);
        begin
            if (!c) begin errors = errors + 1; $display("FAIL @%0t: %0s", $time, m); end
            else $display("PASS: %0s", m);
        end
    endtask

    task reset;
        begin
            {awvalid, wvalid, bready, wr_done} <= 0;
            {awaddr, wdata, wstrb, wr_resp}    <= 0;
            aresetn <= 0; tick(3); aresetn <= 1; tick(1);
        end
    endtask

    // ---------------- AXI master tasks ----------------
    task send_aw(input [31:0] a);
        begin
            awvalid <= 1; awaddr <= a;
            @(posedge aclk);
            while (!awready) @(posedge aclk);
            awvalid <= 0; #1;
        end
    endtask

    task send_w(input [31:0] d, input [3:0] s);
        begin
            wvalid <= 1; wdata <= d; wstrb <= s;
            @(posedge aclk);
            while (!wready) @(posedge aclk);
            wvalid <= 0; #1;
        end
    endtask

    task recv_b(input integer dly, input [1:0] exp);
        begin
            repeat (dly) @(posedge aclk);
            bready <= 1;
            @(posedge aclk);
            while (!bvalid) @(posedge aclk);
            check(bresp == exp, "B channel: bresp correct at handshake");
            bready <= 0; #1;
        end
    endtask

    // ---------------- APB side tasks ----------------
    task apb_done(input [1:0] r, input integer dly);
        begin
            wait (wr_req);
            repeat (dly) @(posedge aclk);
            wr_done <= 1; wr_resp <= r;
            @(posedge aclk);
            wr_done <= 0;
        end
    endtask

    task finish_write(input [1:0] r);
        begin
            fork apb_done(r, 1); recv_b(0, r); join
            tick(1);
            check(!bvalid && !wr_req, "write complete: bvalid and wr_req cleared");
        end
    endtask

    // ---------------- Test cases ----------------
    initial begin
        $dumpfile("tb.vcd"); $dumpvars(0, tb_axi_write_control);
        reset;

        // 1. AW first
        send_aw(32'h10); tick(3);
        check(dut.has_aw && !wr_req, "AW first: address latched, no wr_req yet");
        send_w(32'hA, 4'hF);
        check(wr_req && wr_addr == 32'h10 && wr_data == 32'hA && wr_strb == 4'hF,
              "AW first: wr_req after W with correct addr/data/strb");
        finish_write(2'b00);

        // 2. W first
        send_w(32'hB, 4'h3); tick(3);
        check(dut.has_w && !wr_req, "W first: data latched, no wr_req yet");
        send_aw(32'h20);
        check(wr_req && wr_addr == 32'h20 && wr_data == 32'hB && wr_strb == 4'h3,
              "W first: wr_req after AW with correct addr/data/strb");
        finish_write(2'b00);

        // 3. Same cycle
        fork send_aw(32'h30); send_w(32'hC, 4'hF); join
        check(wr_req, "Same cycle: wr_req high next cycle");
        finish_write(2'b10);

        // 4. Busy
        send_aw(32'h40); send_w(32'hD, 4'hF);
        awvalid <= 1; wvalid <= 1; tick(3);
        check(!awready && !wready, "Busy: awready and wready low while write pending");
        awvalid <= 0; wvalid <= 0;
        finish_write(2'b00);

        // 5. B stalled
        send_aw(32'h50); send_w(32'hE, 4'hF);
        apb_done(2'b10, 0); tick(1);
        check(bvalid && bresp == 2'b10, "B stalled: bvalid/bresp asserted");
        check(!awready && !wready, "B stalled: new writes blocked");
        tick(5);
        check(bvalid && bresp == 2'b10, "B stalled: response held while bready=0");
        recv_b(0, 2'b10); tick(1);
        check(!bvalid, "B stalled: bvalid cleared after bready");

        $display("DONE: %0d error(s)", errors);
        #200000$finish;
    end

    // ---------------- Timeout guard ----------------
    initial begin #200000; $display("TIMEOUT"); $finish; end
endmodule