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

module mdl_dmafe
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,

    //reset
    input   wire            i_SYS_RST_n,

    //68000
    input   wire            i_CPURST_n,
    input   wire            i_AS_n,
    input   wire            i_BG_n,
    output  wire            o_BR_n,
    output  wire            o_BGACK_n,

    //control
    input   wire            i_BR_START_n,
    input   wire            i_DMA_END,

    output  wire            o_ALD_EN,
    output  wire            o_DMA_ACT
);


///////////////////////////////////////////////////////////
//////  DMA FRONTEND
////

//
//  USE 4MHz CLOCK
//


//DMA ACT flag
//This SR latch receives the SET signal from the asynchronous source during ROT8[7] = 1
//so, sample the SET signal twice, at both posedge and negedge of ROT8[7] = 1
reg             dma_act_set_n;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[6] == 1'b1) begin //async signal from CPU, sample them here, latch C83 @ posedge ROT8[7]
            dma_act_set_n <= ~(~o_BR_n & (i_AS_n | ~i_CPURST_n) & ~(i_BG_n & i_CPURST_n)); //C87 NAND
        end
        else if(i_ROT8[7] == 1'b1) begin //async signal from CPU, sample them here, latch C83 @ negedge ROT8[7]
            dma_act_set_n <= ~(~o_BR_n & (i_AS_n | ~i_CPURST_n) & ~(i_BG_n & i_CPURST_n)); //C87 NAND
        end
        else begin //disable
            dma_act_set_n <= 1'b1;
        end
    end
end
   
reg             dma_act_reset_n;

reg             dma_end_dlyd;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        dma_end_dlyd <= i_DMA_END;

        dma_act_reset_n <= ~((i_DMA_END & ~dma_end_dlyd) | ~i_SYS_RST_n);
    end
end

SRNAND C83 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(dma_act_set_n), .i_R_n(dma_act_reset_n), .o_Q(o_DMA_ACT), .o_Q_n());


//BGACK
SRNAND C86 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(dma_act_reset_n | o_DMA_ACT), .i_R_n(dma_act_set_n), .o_Q(o_BGACK_n), .o_Q_n()); //set port: demorgan


//BR
reg             br_start_dlyd;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        br_start_dlyd <= ~i_BR_START_n;
    end
end

wire            br_set_n = i_BR_START_n | br_start_dlyd;
wire            br_reset_n = ~((o_DMA_ACT & i_ROT8[1]) | ~i_SYS_RST_n);
SRNAND C88 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(br_reset_n), .i_R_n(br_set_n), .o_Q(o_BR_n), .o_Q_n()); //set port: demorgan


//Address Latch Enable
//Glitch can occur here. Not a serious one. Solve.
wire            ald_en_set_n = ~(o_DMA_ACT & i_ROT8[0]);
wire            ald_en_reset_n = ~((o_DMA_ACT & i_ROT8[2]) | ~i_SYS_RST_n);
SRNAND C70 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(ald_en_reset_n), .i_R_n(ald_en_set_n), .o_Q(), .o_Q_n(o_ALD_EN));


endmodule