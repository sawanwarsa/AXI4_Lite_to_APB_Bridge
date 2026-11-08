`timescale 1ns/1ps
module axi_write_control(
    input aclk,aresetn,
    input awvalid,
    input [31:0]awaddr,
    input wvalid,
    input [31:0]wdata,
    input [3:0]wstrb,
    input bready,wr_done,
    input [1:0]wr_resp,
    output awready,wready,
    output reg bvalid,
    output reg [1:0]bresp,
    output wr_req,
    output reg [31:0]wr_addr,wr_data,
    output reg [3:0]wr_strb

);
    reg has_aw,has_w;

    assign awready = !has_aw && !bvalid;
    assign wready  = !has_w && !bvalid;
    assign wr_req  = has_aw && has_w;


    // AW LATCH - capture and store the write address
    always@(posedge aclk)begin
        if(!aresetn)begin
             has_aw<=0;
             has_w <=0;
        end 
        else if (awaddr &&awready)begin
             wr_addr<=awaddr;
             has_aw <=1;
        end
        else if (wr_done)
             has_aw<=0;

    end
    
    // W LATCH  capture and store  write data and byte strobes
    always@(posedge aclk)begin
        if(!aresetn)begin
            has_w<=0;
            wr_data<=0;
            wr_strb<=0;
        end
      else if(wvalid && wready)begin
             wr_data<=wdata;
             wr_strb<=wstrb;
             has_w  <=1;

        end
        else if(wr_done)
             has_w<=0;
    end
  

    // B RESPONSE REGISTER 

    always@(posedge aclk)begin
        if(!aresetn)begin
            bvalid<=0;
            bresp <=0;      
        end
        else if(wr_done)begin
            bvalid<=1;
            bresp<=wr_resp;
        end
        else if(bvalid && bready)
            bvalid<=0;

    end

endmodule