
`timescale 1ns/1ps
module address_decoder_tb;
reg [31:0]addr;
wire addr_valid;
parameter NUM_REGS=8;

integer errors =0;
integer i;

address_decoder #(.NUM_REGS(NUM_REGS)) dut(.addr(addr),
    .addr_valid(addr_valid));

task check(input[31:0]a, input expected);
     begin
        addr =a;
        #1;
        if(addr_valid!==expected) begin
             $display("FAIL :addr=0x%08h expected=%b got=%b",
             a,expected,addr_valid);
             errors = errors+1;
        end else
            $display("PASS :addr=0x%08h addr_valid=%b",
            a,addr_valid);

     end
endtask

initial begin
    check(32'h0000_0000,1);
    check(32'h0000_001C,1);
    check(32'h0000_0020,1);
    check(32'h0000_0004,1);
    check(32'h0000_0008,0);
    check(32'h0000_0014,1);
    check(32'h0000_0018,1);
    check(32'h0000_0024,0);
    check(32'h0000_0036,1);
    check(32'h0000_0040,0);

    for(i=0;i<64;i=i+1)
       check(i,(i[1:0]==2'b00 && (i<NUM_REGS*4)));

    if(errors ==0)
        $display("ALL TEST PASSED");
    else 
        $display("%0d TESTS FAILED",errors);
    #200000 $finish;
 
end
initial begin #200000; $display("TIMEOUT"); $finish; end

endmodule
