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

module mdl_dmatiming
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //system flags
    input   wire            i_UMODE_n,
    input   wire            i_ACC_ACT_n,
    input   wire            i_DMA_ACT,
    input   wire            i_BDI_EN,
    input   wire            i_MSKREG_SR_LD,
    input   wire            i_ACQ_MSK_LD,
    input   wire            i_ACQ_START,
    input   wire            i_SUPBDO_EN_n,
    input   wire            i_DMADREG_BDLO_LD,

    output  reg             o_BR_START_n,
    output  wire            o_DMA_END,
    output  wire            o_DMA_WORD_END,
    output  wire            o_MSKREG_LD,
    output  wire            o_MSKADDR_INC,
    output  wire            o_DMADREG_BDHILO_LD,
    output  wire            o_DMA_WR_ACT_n
);

///////////////////////////////////////////////////////////
//////  DMA TIMINGS
////

//
//  USE 4MHz CLOCK
//

//BDLO_LD negedge detection
reg             dmareg_bdlo_ld_dlyd;
wire            dmareg_bdlo_ld_negedge = dmareg_bdlo_ld_dlyd & ~i_DMADREG_BDLO_LD;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        dmareg_bdlo_ld_dlyd <= i_DMADREG_BDLO_LD;
    end
end

//dma command d1 SRNOR control
wire            dma_command_d1_set = o_MSKREG_LD | ~i_SYS_RST_n;
wire            dma_command_d1_reset = ~(i_UMODE_n | ~((i_MSKREG_SR_LD & ~i_ROT20_n[1]) | (i_ACQ_MSK_LD & ~i_ROT20_n[3])));

//dma command d0 SRNAND control
wire            dma_command_d0_set_n = ~(~(~(o_DMADREG_BDHILO_LD & i_ROT8[3]) & ~(i_ACQ_START & ~i_ROT20_n[0]) & i_SUPBDO_EN_n) | ~i_SYS_RST_n);
wire            dma_command_d0_reset_n = ~(((i_ACQ_MSK_LD & ~i_ROT20_n[3]) & ~i_BDI_EN) | dmareg_bdlo_ld_negedge);
assign  o_DMA_WORD_END = ~dma_command_d0_set_n;

//dma commands from sr latches
wire    [1:0]   dma_command_input; //[G5, F20] 

//G5, d1
SRNOR G5 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S(dma_command_d1_set), .i_R(dma_command_d1_reset), .o_Q(), .o_Q_n(dma_command_input[1]));

//F50, d0
SRNAND F50 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(dma_command_d0_set_n), .i_R_n(dma_command_d0_reset_n), .o_Q(), .o_Q_n(dma_command_input[0]));




//dma command control block
//rot8    4 5 6 7 0 1 2 3 4 5 6 7
//rot20   0   1   2   3   4   5

//dma command input is stable at falling edge of ROT8[3], because the launching latches are all enabled by ROT8[3] or ROT20[3]
reg             dma_command_lock_n = 1'b0; //latches command status at ROT8[3] == 1
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[3] == 1'b1) begin
            if(dma_command_lock_n == 1'b0) begin
                if(i_ACC_ACT_n == 1'b0) begin
                    dma_command_lock_n <= 1'b1; //unlock
                end
                else begin
                    dma_command_lock_n <= 1'b0; //lock hold
                end
            end
            else begin
                if(i_ACC_ACT_n & ~|{dma_command_input} == 1'b1) begin
                    dma_command_lock_n <= 1'b0; //lock
                end
                else begin
                    dma_command_lock_n <= 1'b1; //unlock
                end
            end

            if(dma_command_lock_n == 1'b0) begin
                if(i_ACC_ACT_n == 1'b0) begin //unlock
                    o_BR_START_n <= ~|{dma_command_input}; 
                end
                else begin
                    o_BR_START_n <= 1'b1; //still locked
                end
            end
            else begin
                if(i_ACC_ACT_n == 1'b0) begin //free
                    o_BR_START_n <= ~|{dma_command_input};
                end
                else begin
                    o_BR_START_n <= ~|{dma_command_input}; //locks when NOR(dmainput) is 1
                end
            end
        end
    end
end

reg     [1:0]   dma_command_0; //d-latch @ ROT8[4]
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[4] == 1'b1) begin
            dma_command_0 <= dma_command_input & {2{(dma_command_lock_n & i_SYS_RST_n)}};
        end
    end
end

reg     [1:0]   dma_command_1; //d-latch @ ROT8[7]
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[6] == 1'b1) begin
            dma_command_1 <= dma_command_0 & {2{(dma_command_lock_n)}};
        end
    end
end


assign  o_DMA_END           = ~( dma_command_1[1] |  dma_command_1[0]);
assign  o_MSKADDR_INC       =  ( dma_command_1[1] & ~dma_command_1[0] & i_DMA_ACT);
assign  o_MSKREG_LD         =  o_MSKADDR_INC & i_ROT8[3];
assign  o_DMADREG_BDHILO_LD =  ( dma_command_1[1] &  dma_command_1[0] & i_DMA_ACT) |
                              (~dma_command_1[1] &  dma_command_1[0] & i_DMA_ACT);
assign  o_DMA_WR_ACT_n      = o_MSKADDR_INC | ~o_DMADREG_BDHILO_LD | ~i_BDI_EN;


endmodule