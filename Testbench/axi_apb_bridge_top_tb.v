
`timescale 1ns/1ps
// APB slave model: 8 registers, STATUS (0x14) is read-only -> PSLVERR on write, 1 wait state


module tb_axi_apb_bridge;
    localparam OKAY = 2'b00, SLVERR = 2'b10, DECERR = 2'b11;

    reg         aclk = 0, aresetn = 0;
    reg         awvalid = 0, wvalid = 0, bready = 0, arvalid = 0, rready = 0;
    reg  [31:0] awaddr = 0, wdata = 0, araddr = 0;
    reg  [3:0]  wstrb = 4'hF;
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;
    wire        psel, penable, pwrite, pready, pslverr;
    wire [31:0] paddr, pwdata, prdata;

    integer pass_cnt = 0, fail_cnt = 0;
    reg [1:0]  resp;
    reg [31:0] data;

    axi_apb_bridge dut (.*);
    apb_slave_model slv (.pclk(aclk), .presetn(aresetn), .*);

    always #5 aclk = ~aclk;
  
    

    // ---------- helper tasks ----------
    task check(input [8*28-1:0] name, input [31:0] got, input [31:0] exp);
        if (got === exp) begin pass_cnt++; $display("PASS  %0s", name); end
        else begin fail_cnt++; $display("FAIL  %0s  got=%h exp=%h", name, got, exp); end
    endtask

    task send_aw(input [31:0] a);
        begin
            awaddr <= a; awvalid <= 1;
            do @(posedge aclk); while (!awready);
            awvalid <= 0;
        end
    endtask

    task send_w(input [31:0] d);
        begin
            wdata <= d; wvalid <= 1;
            do @(posedge aclk); while (!wready);
            wvalid <= 0;
        end
    endtask

    // mode 0: AW and W together, 1: AW first, 2: W first; bdelay: cycles before bready
    task axi_write(input [31:0] a, d, input integer mode, bdelay, output [1:0] r);
        begin
            case (mode)
                0: fork send_aw(a); send_w(d); join
                1: begin send_aw(a); repeat (3) @(posedge aclk); send_w(d); end
                2: begin send_w(d);  repeat (3) @(posedge aclk); send_aw(a); end
            endcase
            repeat (bdelay) @(posedge aclk);
            bready <= 1;
            do @(posedge aclk); while (!bvalid);
            r = bresp;
            bready <= 0;
        end
    endtask

    task axi_read(input [31:0] a, output [31:0] d, output [1:0] r);
        begin
            araddr <= a; arvalid <= 1;
            do @(posedge aclk); while (!arready);
            arvalid <= 0; rready <= 1;
            do @(posedge aclk); while (!rvalid);
            d = rdata; r = rresp;
            rready <= 0;
        end
    endtask

    // ---------- main ----------
    initial begin
        repeat (4) @(posedge aclk);
        aresetn <= 1;
        repeat (2) @(posedge aclk);

        // 1. Write 0x1234_5678 to 0x04, then read back
        axi_write(32'h04, 32'h1234_5678, 0, 0, resp);   check("write 0x04 BRESP",  resp, OKAY);
        axi_read (32'h04, data, resp);                  check("read 0x04 RDATA",   data, 32'h1234_5678);
                                                        check("read 0x04 RRESP",   resp, OKAY);
        // 2. Write to invalid address 0x20 -> DECERR, APB skipped
        axi_write(32'h20, 32'hDEAD_BEEF, 0, 0, resp);   check("write 0x20 BRESP",  resp, DECERR);
        // 3. Write to STATUS 0x14 -> slave returns PSLVERR
        axi_write(32'h14, 32'hFFFF_FFFF, 0, 0, resp);   check("write 0x14 BRESP",  resp, SLVERR);
        axi_read (32'h14, data, resp);                  check("STATUS unchanged",  data, 32'h0000_00A5);
        // 4. Read invalid address 0x20 -> DECERR, RDATA = 0
        axi_read (32'h20, data, resp);                  check("read 0x20 RRESP",   resp, DECERR);
                                                        check("read 0x20 RDATA",   data, 0);
        // 5. Unaligned address -> DECERR
        axi_write(32'h06, 32'h1, 0, 0, resp);           check("unaligned BRESP",   resp, DECERR);
        // 6. AW before W, W before AW
        axi_write(32'h08, 32'hAAAA_0001, 1, 0, resp);   check("AW first BRESP",    resp, OKAY);
        axi_write(32'h0C, 32'hBBBB_0002, 2, 0, resp);   check("W first BRESP",     resp, OKAY);
        axi_read (32'h08, data, resp);                  check("AW first data",     data, 32'hAAAA_0001);
        axi_read (32'h0C, data, resp);                  check("W first data",      data, 32'hBBBB_0002);
        // 7. B channel back-pressure
        axi_write(32'h1C, 32'hCAFE_F00D, 0, 5, resp);   check("bready delay BRESP", resp, OKAY);
        axi_read (32'h1C, data, resp);                  check("bready delay data", data, 32'hCAFE_F00D);

        $display("\nSUMMARY: %0d passed, %0d failed", pass_cnt, fail_cnt);
        #200000 $finish;
    end

    initial begin #200000; $display("TIMEOUT"); $finish; end   // watchdog
    initial begin $dumpfile("tb_axi_apb_bridge.vcd"); $dumpvars(0, tb_axi_apb_bridge); end
endmodule
