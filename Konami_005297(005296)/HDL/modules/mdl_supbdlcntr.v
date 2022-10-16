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

module mdl_supbdlcntr
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_SYS_RUN_FLAG,

    input   wire            i_4BEN_n,
    input   wire            i_BDI_EN,
    input   wire            i_SUPBD_START_n,

    input   wire            i_MSKREG_SR_LSB,
    input   wire            i_GLCNT_RD,


    output  wire            o_SUPBDLCNTR_CNT,
    output  wire            o_SUPBD_ACT_n,
    output  wire            o_SUPBD_END_n
);



///////////////////////////////////////////////////////////
//////  SUPPLEMENTARY BUBBLE DATA LENGTH COUNTER
////

//count enable
SRNAND J34 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_SUPBD_END_n), .i_R_n(i_SUPBD_START_n), .o_Q(o_SUPBD_ACT_n), .o_Q_n());

//delay something?
reg             supbd_act_n_dlyd = 1'b1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n)) == 1'b1) begin //0-5_10-15
            supbd_act_n_dlyd <= o_SUPBD_ACT_n;
        end
        else begin
            supbd_act_n_dlyd <= supbd_act_n_dlyd;
        end
    end
end

//supplementary data count up
wire            glcnt_wr = ((~supbd_act_n_dlyd | o_SUPBD_ACT_n) & ~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) & i_MSKREG_SR_LSB);
assign          o_SUPBDLCNTR_CNT = (i_BDI_EN == 1'b0) ? glcnt_wr : i_GLCNT_RD;

//supplementary data bit counter
reg     [3:0]   supbd_length_cntr = 4'hF;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(o_SUPBD_ACT_n == 1'b1) begin //reset
            supbd_length_cntr <= 4'hF;
        end
        else begin
            if(o_SUPBDLCNTR_CNT == 1'b1) begin
                if(supbd_length_cntr == 4'h0) begin
                    supbd_length_cntr <= 4'hF;
                end
                else begin
                    supbd_length_cntr <= supbd_length_cntr - 4'h1;
                end
            end
            else begin
                supbd_length_cntr <= supbd_length_cntr;
            end
        end
    end
end

//flag
wire            eq14 = (supbd_length_cntr == 4'h1) ? 1'b1 : 1'b0; //4'd14
assign  o_SUPBD_END_n = (~(eq14 & ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n))) & i_SYS_RUN_FLAG); //0-5_10-15


endmodule