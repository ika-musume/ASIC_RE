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

module mdl_invalpgdgen
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
    input   wire            i_PGREG_D2,
    input   wire            i_PGREG_D8,

    input   wire            i_EFFBDO_EN,
    input   wire            i_BDO_EN_n,
    input   wire            i_GLCNT_RD,

    input   wire            i_VALPG_ACC_FLAG,
    input   wire            i_UMODE_n,
    input   wire            i_SUPBD_ACT_n,
    input   wire            i_SYNCED_FLAG,
    input   wire            i_ALD_nB_U,

    input   wire            i_BDI,
    output  wire            o_MUXED_BDI,
    output  wire            o_EFF_MUXED_BDI
);



///////////////////////////////////////////////////////////
//////  INVALID PAGE DATA GENERATOR
////

//muxed bdi = bubble data + invalid page data
//effective muxed bdi = excepts supplementary bubble data
assign  o_EFF_MUXED_BDI = o_MUXED_BDI & i_SUPBD_ACT_n;


//SR shift enable
wire            sr8_last_shift; //shift flag
wire            sr8_shift = (i_EFFBDO_EN & i_GLCNT_RD) | (i_BDO_EN_n & sr8_last_shift); //mux?

SRNAND F37 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[8]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(sr8_last_shift));


//shift register
reg     [7:0]   sr8;
wire            sr8_msb;
wire            sr8_lsb = sr8[0];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr8_shift == 1'b1) begin
            sr8[7] <= sr8_msb;
            sr8[6:0] <= sr8[7:1];
        end
        else begin
            sr8 <= sr8;
        end
    end
end


//adder
wire            sr8_const, sr8_fa_sum, sr8_fa_cout; //FA carry out
reg             sr8_fa_cflag = 1'b0; //FA carry storage
assign          sr8_msb = (i_ALD_nB_U == 1'b0) ? sr8_fa_sum & i_SYNCED_FLAG : sr8_lsb & i_SYNCED_FLAG; //bootloader : user pages

FA Q59 (.i_A(o_EFF_MUXED_BDI), .i_B(sr8_lsb), .i_CIN(sr8_fa_cflag), .o_S(sr8_fa_sum), .o_COUT(sr8_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr8_shift == 1'b1) begin
            sr8_fa_cflag <= sr8_fa_cout & (i_SUPBD_ACT_n & ~i_ALD_nB_U);
        end
        else begin
            sr8_fa_cflag <= sr8_fa_cflag & (i_SUPBD_ACT_n & ~i_ALD_nB_U);
        end
    end
end


//page number synchronizer(signal from true D-latch)
reg     [1:0]   sr8_bitmux_sel_0;
reg     [1:0]   sr8_bitmux_sel_1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        sr8_bitmux_sel_0 <= {i_PGREG_D8, i_PGREG_D2};
        sr8_bitmux_sel_1 <= sr8_bitmux_sel_0;
    end
end

//sr8 bit selector for scrambling?
reg             sr8_bitmux;
always @(*) begin
    case(sr8_bitmux_sel_1)
        2'b00: sr8_bitmux <= sr8[7];
        2'b01: sr8_bitmux <= sr8[6];
        2'b10: sr8_bitmux <= sr8[5];
        2'b11: sr8_bitmux <= sr8[4];
    endcase
end

assign          o_MUXED_BDI = i_BDI ^ (sr8_bitmux & ~(i_VALPG_ACC_FLAG | i_UMODE_n | ~i_SUPBD_ACT_n));


endmodule