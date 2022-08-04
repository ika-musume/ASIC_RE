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

module mdl_mskreg
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_MSKREG_LD,
    input   wire            i_MSKREG_SR_LD,
    input   wire            i_BOOTEN_n,

    //data
    input   wire    [15:0]  i_DIN,

    //serial data
    output  wire            o_MSKREG_SR_LSB
);



///////////////////////////////////////////////////////////
//////  MASK REGISTER
////

//D latch * 16
wire    [15:0]  mskreg_q;
DL #(.dw(16)) MSKREG (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_EN(i_MSKREG_LD), .i_D(i_DIN), .o_Q(mskreg_q), .o_Q_n());

//mask register sr control
wire    [1:0]   mskreg_sr_ctrl; //11:hold(invalid), 10:load, 01:shift, 00:hold
assign  mskreg_sr_ctrl[1] = ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n)) & (i_MSKREG_SR_LD & i_BOOTEN_n); //0-5_10-15
assign  mskreg_sr_ctrl[0] = ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n)) & ~(i_MSKREG_SR_LD & i_BOOTEN_n);

//mask register sr
reg     [15:0]  mskreg_sr;
assign  o_MSKREG_SR_LSB = mskreg_sr[0];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        case(mskreg_sr_ctrl)
            2'b11: begin
                mskreg_sr <= mskreg_sr;
            end
            2'b10: begin //load
                mskreg_sr <= mskreg_q;
            end
            2'b01: begin //shift
                mskreg_sr[15] <= ~i_BOOTEN_n;
                mskreg_sr[14:0] <= mskreg_sr[15:1];
            end
            2'b00: begin
                mskreg_sr <= mskreg_sr;
            end
        endcase
    end
end


endmodule