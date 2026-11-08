`timescale 1ns/1ps
module apb_slave_model(
    input pclk,presetn,psel,penable,pwrite,
    input [31:0]paddr,pwdata,
    output [31:0]prdata,
    output pready,pslverr

);

reg [31:0] regs [0:7];
reg [3:0]cnt;
integer i;
wire [2:0]idx = paddr[4:2];
wire access =psel & penable;
assign pready=access &(cnt==regs[6][3:0]);


always@(posedge pclk or negedge presetn)begin
   if(!presetn)
      cnt<=4'd0;
   else if (!access || pready)
      cnt<=4'd0;
   else
      cnt<=cnt+4'd1;
end


wire err=(pwrite&& idx==5)||(regs[7][0] && idx<4);

assign pslverr= access & pready &err;

always@(posedge pclk or negedge presetn)begin
   if (!presetn)
       for(i=0;i<8;i=i+1)  regs[i] <=32'b0;
   else if (access && pready && pwrite &!err)
       regs[idx] <=pwdata;
end


assign prdata =(idx==5) ? 32'h0000_00A5 : regs[idx];
endmodule