`timescale 1ns/1ps
module address_decoder #(parameter NUM_REGS=8) (
    input [31:0] addr,
    output addr_valid
);

wire in_range =(addr[31:2]<NUM_REGS);
wire aligned = (addr[1:0]==2'b00);
assign addr_valid = in_range &aligned;
endmodule