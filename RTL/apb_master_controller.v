`timescale 1ns/1ps
module apb_master_controller(
    input pclk,presetn,
    input apb_start,apb_write,
    input [31:0]apb_addr,apb_wdata,prdata,
    input pready,pslverr,
    output reg psel,penable,pwrite,
    output reg [31:0] paddr,pwdata,
    output reg apb_done,
    output reg [31:0]apb_rdata,
    output reg apb_err
);

localparam IDLE=2'd0,
           SETUP=2'd1,
           ACCESS=2'd2;
reg [1:0] state,next_state;

//state register
always@(posedge pclk)begin
    if(!presetn)
        state<=IDLE;
    else
        state<=next_state;
end

//Next state logic|combinatinal
always@(*)begin
   next_state=state;

   case(state)
        IDLE:begin
           if(apb_start)
               next_state=SETUP;
            else
               next_state=IDLE;
        end

        SETUP:begin
            if(penable)
               next_state=ACCESS;
            else
               next_state=SETUP;
        end

        ACCESS:begin
            if(pready)
               next_state=IDLE;
            else
               next_state=ACCESS;
        end
        default:next_state=IDLE;

    endcase
end

//Output logic |sequential

always@(posedge pclk)begin
    if(!presetn)begin
       psel<=0; penable<=0; pwrite<=0;
       paddr<=0; pwdata<=0; apb_done<=0;
       apb_err<=0; apb_rdata<=0;
    end

    else begin
        psel<= (next_state !=IDLE);
        penable<=(next_state ==ACCESS);
        apb_done<= 0;

        if(state ==IDLE && apb_start)begin
           pwrite<=apb_write;
           paddr<=apb_addr;
           pwdata<=apb_wdata;

        end
        
        if(state ==ACCESS &&pready)begin
            apb_rdata<= prdata;
            apb_err<=pslverr;
            apb_done<=1;
        end

    end

end

endmodule
