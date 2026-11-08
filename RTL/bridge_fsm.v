

`timescale 1ns/1ps
module bridge_fsm #(parameter AW = 32, DW = 32) (
    input  wire          clk, rst_n,
    // AXI-side request
    input  wire          wr_req,
    input  wire [AW-1:0] wr_addr,
    input  wire [DW-1:0] wr_data,
    input  wire [3:0]    wr_strb,
    input  wire          rd_req,
    input  wire [AW-1:0] rd_addr,
    // from decoder / APB master
    input  wire          addr_valid, apb_done, apb_err,
    input  wire [DW-1:0] apb_rdata,
    // to decoder / APB master
    output reg  [AW-1:0] dec_addr,
    output reg           apb_start, apb_write,
    output reg  [AW-1:0] apb_addr,
    output reg  [DW-1:0] apb_wdata,
    // AXI-side response
    output reg           wr_done, rd_done,
    output reg  [1:0]    wr_resp, rd_resp,
    output reg  [DW-1:0] rd_data 
);

    localparam [1:0]IDLE = 2'b00,
                   CHECK= 2'b01,
                   APB  = 2'b10,
                   RESP = 2'b11;

    localparam [1:0] OKAY=2'd1, SILVERR=2'd2,DECERR=2'd3;

    reg [1:0] state,resp_q;
    reg [3:0] strb_q;


    //
    always@(posedge clk)begin
        if(!rst_n)begin
            state<= IDLE; resp_q<=OKAY; strb_q<=4'h0; dec_addr<=0;
            apb_addr<=0; apb_wdata<=0; apb_start<=0; apb_write<=0;
            wr_done<=0; rd_done<=0; wr_resp<=OKAY; rd_resp<=OKAY; rd_data<=0;
        end    
        else begin
            apb_start<=0;
            wr_done <=0;
            rd_done <=0;
        end
    end
    
    //
    always@(*)begin
        
        case(state)
            IDLE: if (wr_req || rd_req)begin
                apb_write <= wr_req;
                dec_addr  <= wr_req ? wr_addr : rd_addr;
                apb_addr  <= wr_req ? wr_addr : rd_addr;
                apb_wdata <= wr_data;
                strb_q    <= wr_strb;
                state     <= CHECK;
            end
            
            CHECK: 
                if(!addr_valid)begin
                   resp_q <= DECERR;
                   rd_data<= 0;
                   state  <=RESP;
                end else if (apb_write && strb_q!=4'hF)begin
                    resp_q <= SILVERR;
                    rd_data<= 0;
                    state  <= RESP;
                end else begin
                    apb_start <=1;
                    state     <=APB;
                end
            

            APB: if(apb_done)begin
                resp_q <= apb_err? SILVERR: OKAY;
                rd_data<= (apb_err || apb_write) ? 0 : apb_rdata;
                state  <= RESP;
            end

            RESP: begin
                if(apb_write) wr_resp <= resp_q;
                else          rd_resp <= resp_q;
                wr_done <= apb_write;
                rd_done <= ~apb_write;
                state   <= IDLE;
            end 
            
        endcase
    end
    
endmodule