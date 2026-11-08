
`timescale 1ns/1ps
module tb_apb_slave_model;
reg pclk,presetn,psel,penable,pwrite;
reg [31:0]paddr,pwdata;
wire [31:0]prdata;
wire pready,pslverr;

integer errors = 0;
integer i;
integer waits;
reg [31:0] rdata;
reg slverr;

parameter STATUS = 32'h14;
parameter WAIT_CFG = 32'h18;
parameter ERR_CFG = 32'h1C;
parameter CTRL = 32'h10;

apb_slave_model dut(.pclk(pclk),.presetn(presetn),.psel(psel),
.penable(penable),.pwrite(pwrite),.paddr(paddr),.pwdata(pwdata),
.prdata(prdata),.pready(pready),.pslverr(pslverr));


always #5 pclk = ~pclk;

// ---------- helper tasks ----------
  task apb_xfer(input wr, input [31:0] addr, input [31:0] wdata);
    begin
      @(negedge pclk);                         // setup phase
      psel = 1; penable = 0; pwrite = wr; paddr = addr; pwdata = wdata;
      @(negedge pclk);                         // access phase
      penable = 1; waits = 0;
      @(posedge pclk);
      while (!pready) begin                    // count wait states
        waits = waits + 1;
        @(posedge pclk);
      end
      rdata = prdata; slverr = pslverr;        // capture
      @(negedge pclk);
      psel = 0; penable = 0; pwrite = 0;       // idle
    end
  endtask

  task check(input [8*20-1:0] name, input [31:0] got, input [31:0] exp);
    begin
      if (got === exp) $display("PASS  %0s", name);
      else begin
        $display("FAIL  %0s : got %h, expected %h", name, got, exp);
        errors = errors + 1;
      end
    end
  endtask


initial begin
   $dumpfile("tb_apb_slave_model.vcd");
   $dumpvars(0,tb_apb_slave_model);
end


// ---------- main test sequence ----------
  initial begin
    pclk = 0;
    presetn = 0;
    psel = 0;
    penable = 0;
    pwrite = 0;
    paddr = 0;
    pwdata = 0;

    repeat (3) @(negedge pclk);                // reset
    presetn = 1;

    // T1: reset value
    apb_xfer(0, 32'h00, 0);
    check("reset REG0", rdata, 0);

    // T2: write/read REG0-REG3 and CTRL
    for (i = 0; i < 5; i = i + 1) begin
      apb_xfer(1, i*4, 32'hA0A0_0000 + i);
      check("write no error", slverr, 0);
      apb_xfer(0, i*4, 0);
      check("readback", rdata, 32'hA0A0_0000 + i);
    end

    // T3: read STATUS
    apb_xfer(0, STATUS, 0);
    check("STATUS data", rdata, 32'hA5);
    check("STATUS rd no error", slverr, 0);

    // T4: write STATUS -> error, ignored
    apb_xfer(1, STATUS, 32'hFFFF_FFFF);
    check("STATUS wr error", slverr, 1);
    check("STATUS wr ignored", dut.regs[5], 0);

    // T5: wait states (new WAIT_CFG applies from the next transfer)
    apb_xfer(1, WAIT_CFG, 2);   check("wr used old waits", waits, 0);
    apb_xfer(0, 32'h00, 0);     check("waits = 2", waits, 2);
    apb_xfer(1, WAIT_CFG, 15);  apb_xfer(0, 32'h00, 0);
    check("waits = 15", waits, 15);
    apb_xfer(1, WAIT_CFG, 0);   apb_xfer(0, 32'h00, 0);
    check("waits = 0", waits, 0);

    // T6: ERR_CFG[0] forces errors on REG0-REG3
    apb_xfer(1, ERR_CFG, 1);
    check("ERR_CFG wr no error", slverr, 0);
    apb_xfer(1, 32'h00, 32'h1234_5678);
    check("forced error", slverr, 1);
    check("REG0 unchanged", dut.regs[0], 32'hA0A0_0000);
    apb_xfer(1, CTRL, 32'h55);
    check("CTRL no error", slverr, 0);
    apb_xfer(1, ERR_CFG, 0);
    apb_xfer(1, 32'h00, 32'h1234_5678);
    check("error cleared", slverr, 0);
    apb_xfer(0, 32'h00, 0);
    check("REG0 updated", rdata, 32'h1234_5678);

    if(errors ==0) $display("ALL TEST PASSED");
    else           $display("ALL TEST FAILED %0d",errors);
    #200000 $finish;
  end

initial begin
   #200000;
   $display("TIMEOUT: simulation stuck");
   $finish;
end

endmodule
