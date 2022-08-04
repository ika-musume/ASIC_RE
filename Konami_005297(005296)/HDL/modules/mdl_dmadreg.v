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

module mdl_dmadreg
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,

    //control
    input   wire            i_DMADREG_SHIFT,
    input   wire            i_DMADREG_BDLD_EN,
    input   wire            i_DMADREG_BDHI_LD,
    input   wire            i_DMADREG_BDLO_LD,
    input   wire            i_DMADREG_BDHILO_LD,

    input   wire            i_DMA_ACT,
    input   wire            i_BDI_EN,
    input   wire            i_GLCNT_RD,

    output  wire            o_BDRWADDR_INC,

    input   wire            i_MUXED_BDI, //muxed bubble data input(bubble read)
    output  wire    [15:0]  o_DMATXREG, //parallel bubble read data(DMA TX)

    output  wire            o_EFF_BDO, //effective bubble data output(bubble write)
    input   wire    [15:0]  i_DIN //parallel bubble write data(DMA RX)
);



///////////////////////////////////////////////////////////
//////  DMA DATA REGISTER
////

//word load request(for write?)
reg             txreg_word_ld_rq = 1'b0;
wire            txreg_word_ld = txreg_word_ld_rq & i_DMA_ACT & i_ROT8[6];
assign  o_BDRWADDR_INC = txreg_word_ld_rq;

always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[1] == 1'b1) begin
            txreg_word_ld_rq <= i_DMADREG_BDHILO_LD; //latches at i_ROT8[2]; source latch launches at i_ROT8[7]
        end
    end
end


//8 bit shift register for data IO
reg     [7:0]   bytesr;
assign          o_EFF_BDO = bytesr[7];
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        case({i_GLCNT_RD, i_DMADREG_SHIFT})
            2'b00: bytesr <= bytesr; //hold
            2'b01: bytesr <= bytesr;
            2'b10: bytesr <= (i_DMADREG_BDHI_LD == 1'b0) ? o_DMATXREG[7:0] : o_DMATXREG[15:8]; //parallel load(bubble write)
            2'b11: begin bytesr[0] <= i_MUXED_BDI; bytesr[7:1] <= bytesr[6:0]; end //serial load(bubble read)
        endcase
    end
end



//D latch * 16
wire            txreg_hi_ld = (i_BDI_EN == 1'b1) ? (i_DMADREG_BDHI_LD & i_DMADREG_BDLD_EN) : txreg_word_ld;
wire            txreg_lo_ld = (i_BDI_EN == 1'b1) ? (i_DMADREG_BDLO_LD & i_DMADREG_BDLD_EN) : txreg_word_ld;
wire    [7:0]   txreg_hi_data = (i_BDI_EN == 1'b1) ? bytesr: i_DIN[15:8];
wire    [7:0]   txreg_lo_data = (i_BDI_EN == 1'b1) ? bytesr: i_DIN[7:0];

DL #(.dw(8)) DMATXREGHI (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_EN(txreg_hi_ld), .i_D(txreg_hi_data), .o_Q(o_DMATXREG[15:8]), .o_Q_n());
DL #(.dw(8)) DMATXREGLO (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_EN(txreg_lo_ld), .i_D(txreg_lo_data), .o_Q(o_DMATXREG[7:0]), .o_Q_n());


endmodule