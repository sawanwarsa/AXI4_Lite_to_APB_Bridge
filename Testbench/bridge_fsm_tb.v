`timescale 1ns/1ps
module tb_bridge_fsm;
    localparam AW = 32, DW = 32;
    localparam [1:0] OKAY = 2'b00, SLVERR = 2'b10, DECERR = 2'b11;

    logic clk = 0, rst_n = 0;
    logic wr_req = 0, rd_req = 0;
    logic [AW-1:0] wr_addr = '0, rd_addr = '0;
    logic [DW-1:0] wr_data = '0;
    logic [3:0]    wr_strb = '0;
    logic          addr_valid, apb_done = 0, apb_err = 0;
    logic [DW-1:0] apb_rdata = '0;
    logic [AW-1:0] dec_addr, apb_addr;
    logic          apb_start, apb_write, wr_done, rd_done;
    logic [DW-1:0] apb_wdata, rd_data;
    logic [1:0]    wr_resp, rd_resp;

    bridge_fsm #(AW, DW) dut (.*);

    // ---------- clock, decoder model, APB slave model ----------
    always #5 clk = ~clk;
    assign addr_valid = (dec_addr < 32'h400);

    logic [DW-1:0] mem [0:255];
    int apb_delay = 0, apb_cnt = 0;
    bit force_err = 0;

    always @(posedge clk) if (apb_start) begin
        apb_cnt++;
        repeat (apb_delay) @(posedge clk);
        apb_err <= force_err;
        if (apb_write && !force_err) mem[apb_addr[9:2]] = apb_wdata;
        apb_rdata <= mem[apb_addr[9:2]];
        apb_done  <= 1;
        @(posedge clk);
        apb_done <= 0;  apb_err <= 0;
    end

    // ---------- checker and protocol monitor ----------
    int pass = 0, fail = 0;
    task automatic check(string name, logic [DW-1:0] got, exp);
        if (got === exp) pass++;
        else begin fail++; $display("FAIL %s: got %h, expected %h", name, got, exp); end
    endtask

    logic wd_q = 0, rd_q = 0;
    always @(posedge clk) begin
        wd_q <= wr_done;  rd_q <= rd_done;
        if (wr_done && rd_done) begin fail++; $display("FAIL: both done high"); end
        if ((wr_done && wd_q) || (rd_done && rd_q)) begin fail++; $display("FAIL: done longer than 1 cycle"); end
    end

    // ---------- AXI-side drivers ----------
    task automatic axi_write(input [AW-1:0] a, input [DW-1:0] d, input [3:0] s);
        @(posedge clk); wr_req <= 1; wr_addr <= a; wr_data <= d; wr_strb <= s;
        @(posedge clk); wr_req <= 0;
        do @(posedge clk); while (!wr_done);
    endtask

    task automatic axi_read(input [AW-1:0] a);
        @(posedge clk); rd_req <= 1; rd_addr <= a;
        @(posedge clk); rd_req <= 0;
        do @(posedge clk); while (!rd_done);
    endtask

    // ---------- tests ----------
    int n;
    initial begin
        $dumpfile("bridge_fsm.vcd"); $dumpvars(0, tb_bridge_fsm);
        for (int i = 0; i < 256; i++) mem[i] = '0;
        repeat (3) @(posedge clk);  rst_n <= 1;

        // T1: valid write
        axi_write(32'h10, 32'hDEADBEEF, 4'hF);
        check("T1 wr_resp", wr_resp, OKAY);
        check("T1 mem",     mem[4],  32'hDEADBEEF);

        // T2: read back
        axi_read(32'h10);
        check("T2 rd_resp", rd_resp, OKAY);
        check("T2 rd_data", rd_data, 32'hDEADBEEF);

        // T3: invalid address, write -> DECERR, APB skipped
        n = apb_cnt;
        axi_write(32'h800, 32'h1, 4'hF);
        check("T3 wr_resp", wr_resp, DECERR);
        check("T3 no APB",  apb_cnt, n);

        // T4: invalid address, read -> DECERR, rd_data = 0
        axi_read(32'h800);
        check("T4 rd_resp", rd_resp, DECERR);
        check("T4 rd_data", rd_data, 0);
        check("T4 no APB",  apb_cnt, n);

        // T5: bad strobe -> SLVERR, APB skipped, memory untouched
        axi_write(32'h14, 32'h12345678, 4'h3);
        check("T5 wr_resp", wr_resp, SLVERR);
        check("T5 no APB",  apb_cnt, n);
        check("T5 mem",     mem[5], 0);

        // T6: APB slave error on a read -> SLVERR, rd_data = 0
        force_err = 1;
        axi_read(32'h10);
        check("T6 rd_resp", rd_resp, SLVERR);
        check("T6 rd_data", rd_data, 0);
        force_err = 0;

        // T7: APB wait states
        apb_delay = 5;
        axi_write(32'h20, 32'hCAFE0001, 4'hF);
        check("T7 wr_resp", wr_resp, OKAY);
        check("T7 mem",     mem[8], 32'hCAFE0001);
        apb_delay = 0;

        // T8: write and read together -> write wins
        @(posedge clk); wr_req <= 1; rd_req <= 1;
        wr_addr <= 32'h24; wr_data <= 32'hA5A5A5A5; wr_strb <= 4'hF; rd_addr <= 32'h10;
        @(posedge clk); wr_req <= 0; rd_req <= 0;
        do @(posedge clk); while (!(wr_done || rd_done));
        check("T8 write first", wr_done, 1);
        check("T8 rd_done low", rd_done, 0);

        repeat (5) @(posedge clk);
        $display("RESULT: %0d passed, %0d failed -> %s", pass, fail, fail ? "FAIL" : "PASS");
        #200000 $finish;
    end

    initial begin #200000; $display("TIMEOUT: FSM stuck"); $finish; end
endmodule