module K005297_dmaaddrcntr
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,

    //control
    input   wire            i_ALD_nB_U,
    input   wire            i_ADDR_RST,
    input   wire            i_BDRWADDR_INC,
    input   wire            i_MSKADDR_INC,

    output  wire    [6:0]   o_AOUT, //A7-A1
    output  wire    [3:0]   o_ALD_DMABD, //bubble data
    output  wire            o_ALD_DMAMSK //error map
);



///////////////////////////////////////////////////////////
//////  DMA TX(BUBBLE DATA) ADDRESS COUNTER
////

reg     [10:0]  dmabd_addr_cntr = 11'h000;

always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ADDR_RST == 1'b1) begin
            dmabd_addr_cntr <= 11'h000;
        end
        else begin
            if((i_BDRWADDR_INC & i_ROT8[1]) == 1'b1) begin //count up
                if(i_ALD_nB_U == 1'b0) begin //bootloader
                    if(dmabd_addr_cntr == 11'h7FF) begin
                        dmabd_addr_cntr <= 11'h000;
                    end
                    else begin
                        dmabd_addr_cntr <= dmabd_addr_cntr + 11'h001;
                    end
                end
                else begin //user pages
                    if(dmabd_addr_cntr == 11'h0FF) begin
                        dmabd_addr_cntr <= 11'h000;
                    end
                    else begin
                        dmabd_addr_cntr <= dmabd_addr_cntr + 11'h001;
                    end
                end
            end
            else begin
                dmabd_addr_cntr <= dmabd_addr_cntr;
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  DMA RX(ERROR MAP) ADDRESS COUNTER
////

//mskaddr inc latch(why?)
reg             mskaddr_inc_latched;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[1] == 1'b1) begin //D-latch latches this at ROT8[2] == 1'b1;
            mskaddr_inc_latched <= i_MSKADDR_INC;
        end
    end
end

//address counter
reg     [7:0]  dmamsk_addr_cntr = 8'h00;

always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ADDR_RST == 1'b1) begin
            dmamsk_addr_cntr <= 8'h00;
        end
        else begin
            if((mskaddr_inc_latched & i_ROT8[1]) == 1'b1) begin //count up
                if(dmamsk_addr_cntr == 8'hFF) begin
                    dmamsk_addr_cntr <= 8'h00;
                end
                else begin
                    dmamsk_addr_cntr <= dmamsk_addr_cntr + 8'h01;
                end
            end
            else begin
                dmamsk_addr_cntr <= dmamsk_addr_cntr;
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  OUTPUTS
////

assign  o_AOUT = (i_MSKADDR_INC == 1'b0) ? dmabd_addr_cntr[6:0] : dmamsk_addr_cntr[6:0];
assign  o_ALD_DMABD = dmabd_addr_cntr[10:7];
assign  o_ALD_DMAMSK = dmamsk_addr_cntr[7];



endmodule