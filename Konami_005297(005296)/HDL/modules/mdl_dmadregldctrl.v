/*
    Copyright (C) 2022 Sehyeon Kim(Raki)
    
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

module mdl_dmadregldctrl
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_BDI_EN,
    input   wire            i_UMODE_n,
    
    input   wire            i_ACQ_MSK_LD,
    input   wire            i_MSKREG_SR_LD,
    input   wire            i_BYTEACQ_DONE,
    input   wire            i_GLCNT_RD,

    input   wire            i_ACQ_START,
    input   wire            i_SUPBD_START_n,
    input   wire            i_VALPG_FLAG_SET_n,

    input   wire            i_PGREG_SR_LSB,
    input   wire            i_DLCNTR_LSB,

    input   wire            i_DMA_WORD_END,

    output  wire            o_NEWBYTE,
    output  wire            o_DLCNT_EN,
    output  reg             o_DMADREG_BDHI_LD = 1'b1,
    output  wire            o_DMADREG_BDLO_LD
);

//NEWBYTE for DMA outlatch control
reg             initial_newbyte; //only asserted at the beginning
assign          o_NEWBYTE = initial_newbyte | i_BYTEACQ_DONE & i_GLCNT_RD;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        initial_newbyte <= i_ACQ_MSK_LD & (i_MSKREG_SR_LD & ~i_ROT20_n[1]) & i_BDI_EN;
    end
end



//bootloader related
wire            newbyte_dlyd;
assign          o_DLCNT_EN = newbyte_dlyd & ~i_ROT20_n[0];
SRNAND K33 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[1]), .i_R_n(~o_NEWBYTE), .o_Q(), .o_Q_n(newbyte_dlyd));



//user page related
wire            valpg_dma_req;
SRNAND J38 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_START_n), .i_R_n(i_VALPG_FLAG_SET_n), .o_Q(), .o_Q_n(valpg_dma_req));


reg             dlcntr_cmp, dlcntr_zero_n;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        dlcntr_cmp <= (((i_DLCNTR_LSB ^ (i_PGREG_SR_LSB | valpg_dma_req)) | dlcntr_cmp) & i_ROT20_n[19]) | i_UMODE_n;

        dlcntr_zero_n <= (i_4BEN_n == 1'b1) ? ((i_ROT20_n[7] == 1'b0) ? dlcntr_cmp : dlcntr_zero_n) :
                                              ((i_ROT20_n[8] == 1'b0) ? dlcntr_cmp : dlcntr_zero_n); //2bit : 4bit
    end
end


reg             init_dma_req = 1'b0; //this sr latch's outer circuit has a combinational loop
                                       //RESET PORT(flag set) ACQ_START @ D0
                                       //SET PORT(flag reset) ACQ_MSK_LD @ D4(stable before D4)
always @(posedge i_MCLK) begin
    if(i_SYS_RST_n == 1'b0) begin //synchronous reset(SR latch originally)
        init_dma_req <= 1'b0;
    end
    else begin
        if(!i_CLK2M_PCEN_n) begin
            if(i_ROT20_n[19] == 1'b0) begin //SR latch's reset works @ ROT20[0]
                if(i_ACQ_START == 1'b1) begin
                    init_dma_req <= 1'b1;
                end
            end
            else if(i_ROT20_n[3] == 1'b0) begin
                if(init_dma_req & ~i_ACQ_MSK_LD == 1'b1) begin
                    init_dma_req <= 1'b0;
                end
            end
            else begin
                init_dma_req <= init_dma_req;
            end
        end
    end
end


//SR latch
wire            bootloader_dma_req;
SRNAND K38 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~(o_NEWBYTE & dlcntr_zero_n)), .i_R_n(~(o_DLCNT_EN & ~dlcntr_zero_n)), .o_Q(bootloader_dma_req), .o_Q_n());

//DMADREG HI/LO toggle
wire            dmadreg_toggle_hilo = ~(init_dma_req & i_BDI_EN) & (~valpg_dma_req | bootloader_dma_req) & o_NEWBYTE;

//K50 TFF
assign          o_DMADREG_BDLO_LD = ~o_DMADREG_BDHI_LD;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_DMA_WORD_END == 1'b1) begin //reset
            o_DMADREG_BDHI_LD <= 1'b1; 
        end
        else begin
            if(dmadreg_toggle_hilo == 1'b1) begin
                o_DMADREG_BDHI_LD <= ~o_DMADREG_BDHI_LD;
            end
            else begin
                o_DMADREG_BDHI_LD <= o_DMADREG_BDHI_LD;
            end
        end
    end
end


endmodule