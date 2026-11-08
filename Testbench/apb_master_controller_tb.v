`timescale 1ns/1ps
module tb_apb_master;

    // Signals
    reg         pclk = 0, presetn = 0;
    reg         apb_start = 0, apb_write = 0;
    reg  [31:0] apb_addr = 0, apb_wdata = 0;
    wire        psel, penable, pwrite, apb_done, apb_err;
    wire [31:0] paddr, pwdata, apb_rdata;
    wire        pready, pslverr;
    wire [31:0] prdata;

    // DUT
    apb_master_controller dut (
        .pclk(pclk), .presetn(presetn),
        .apb_start(apb_start), .apb_write(apb_write),
        .apb_addr(apb_addr), .apb_wdata(apb_wdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata),
        .apb_done(apb_done), .apb_rdata(apb_rdata), .apb_err(apb_err)
    );

    // Clock: 10 ns period
    always #5 pclk = ~pclk;

    // Simple APB slave model: 4 words, configurable wait states
    reg [31:0] mem [0:3];
    reg [3:0]  wait_states = 0, wait_cnt = 0;

    assign pready  = psel & penable & (wait_cnt == wait_states);
    assign pslverr = pready & (paddr[31:4] != 0);   // only 0x00-0x0C valid
    assign prdata  = mem[paddr[3:2]];

    always @(posedge pclk) begin
        wait_cnt <= (psel & penable & ~pready) ? wait_cnt + 1 : 0;
        if (pready & pwrite & ~pslverr) mem[paddr[3:2]] <= pwdata;
    end

    // Helper tasks
    integer errors = 0;

    task apb_xfer(input w, input [31:0] a, d);
    begin
        @(negedge pclk);
        apb_write = w; apb_addr = a; apb_wdata = d; apb_start = 1;
        @(negedge pclk);
        apb_start = 0;
        wait (apb_done);
    end
    endtask

    task check(input [31:0] exp_data, input exp_err);
    begin
        if (apb_rdata === exp_data && apb_err === exp_err)
            $display("PASS t=%0t rdata=%h err=%b", $time, apb_rdata, apb_err);
        else begin
            $display("FAIL t=%0t rdata=%h (exp %h) err=%b (exp %b)",
                     $time, apb_rdata, exp_data, apb_err, exp_err);
            errors = errors + 1;
        end
    end
    endtask

    // Main test sequence
    integer i;
    initial begin
        for (i = 0; i < 4; i = i + 1) mem[i] = 0;
        $dumpfile("apb.vcd"); $dumpvars(0, tb_apb_master);

        repeat (3) @(negedge pclk);
        presetn = 1;                                  // release reset

        wait_states = 0;                              // Test 1: write, no wait
        apb_xfer(1, 32'h04, 32'h1234_5678);
        apb_xfer(0, 32'h04, 0);                       // Test 2: read back
        check(32'h1234_5678, 0);

        wait_states = 1;                              // Test 3: one wait state
        apb_xfer(1, 32'h08, 32'hDEAD_BEEF);
        wait_states = 2;                              //   read with two waits
        apb_xfer(0, 32'h08, 0);
        check(32'hDEAD_BEEF, 0);

        apb_xfer(0, 32'h20, 0);                       // Test 4: bad address
        check(32'h0, 1);

        $display(errors ? "TEST FAILED: %0d errors" : "ALL TESTS PASSED", errors);
        #200000$finish;
    end

    // Watchdog
    initial begin #200000; $display("TIMEOUT"); $finish; end

endmodule