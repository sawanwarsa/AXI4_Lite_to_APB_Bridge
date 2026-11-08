`timescale 1ns/1ps
module axi_read_control (
    input aclk,aresetn,arvalid,
    input [31:0]araddr,
    input rready,rd_done,
    input [1:0]rd_resp,
    input [31:0]rd_data,
    output reg arready,rvalid,
    output reg [31:0]rdata,
    output reg [1:0]rresp,
    output rd_req,
    output [31:0]rd_addr

);
    reg has_ar;
    reg [31:0]araddr_q;

    assign arready = !has_ar && !rvalid;
    assign rd_req  = has_ar;
    assign rd_addr = araddr_q;

    //AR LATCH
    always@(posedge aclk)begin
        if(!aresetn)begin
            has_ar<=1'b0;
            araddr_q<=32'b0;
            rvalid<=1'b0;
            rdata <=32'b0;
            rresp <=2'b00;    
        end
        else begin
            if (arvalid && arready)begin //idle read
                has_ar <= 1'b1;
                araddr_q<=araddr;
            end 
            if(rd_done && has_ar)begin
                has_ar <=1'b0;
                rvalid <=1'b1;
                rresp <=rd_resp;
                rdata <=(rd_resp == 2'b00)? rd_data : 32'd0;
            end
            else if (rvalid && rready)
                 rvalid <=1'b0;
                 
         end
    end

endmodule