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

module mdl_functrig
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_HALT, //TST4
    input   wire            i_SYS_RST_n,

    input   wire            i_UMODE_n,
    input   wire            i_CYCLECNTR_LSB,

    input   wire            i_ACC_INVAL_n,
    input   wire            i_PGCMP_EQ,
    input   wire            i_SYNCTIP_n,
    input   wire            i_BDI_EN,

    output  wire            o_ACC_END,
    output  wire            o_SWAP_START,
    output  wire            o_ACQ_START,
    output  wire            o_ADDR_RST
);



///////////////////////////////////////////////////////////
//////  ACCESS TERMINATION
////

//terminates magnetic field roation after 7030us
wire            const702 = ~&{i_ROT20_n[9], i_ROT20_n[7], i_ROT20_n[5], i_ROT20_n[4], i_ROT20_n[3], i_ROT20_n[2], i_ROT20_n[1]};
reg             eq702_flag_n = 1'b1;
reg             acc_end_flag_n = 1'b1;

assign  o_ACC_END = ~acc_end_flag_n;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq702_flag_n <= (((i_CYCLECNTR_LSB | i_HALT) ^ const702) | eq702_flag_n | i_UMODE_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        acc_end_flag_n <= (i_SYS_RST_n == 1'b0) ? 1'b1 : 
                                                  (i_ROT20_n[10] == 1'b0) ? eq702_flag_n : acc_end_flag_n;
    end
end






///////////////////////////////////////////////////////////
//////  SWAP START
////

//turn on swap gate after 6240us
wire            const623 = ~&{i_ROT20_n[9], i_ROT20_n[6], i_ROT20_n[5], i_ROT20_n[3], i_ROT20_n[2], i_ROT20_n[1], i_ROT20_n[0]};
reg             eq623_flag_n = 1'b1;
reg             swap_start_flag_n = 1'b1;

assign  o_SWAP_START = ~swap_start_flag_n;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq623_flag_n <= (((i_CYCLECNTR_LSB | i_HALT) ^ const623) | eq623_flag_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        swap_start_flag_n <= (i_BDI_EN == 1'b1) ? 1'b1 : 
                                               (i_ROT20_n[10] == 1'b0) ? eq623_flag_n : swap_start_flag_n;
    end
end






///////////////////////////////////////////////////////////
//////  ACQUISITION START
////

//start bubble data acquisition after 980us
wire            const97 = ~&{i_ROT20_n[6], i_ROT20_n[5], i_ROT20_n[0]};
reg             eq97_flag_n = 1'b1;
reg             acq_start_flag_n = 1'b1;
wire            acq_start_flag_feedback = (i_SYS_RST_n == 1'b0) ? 1'b1 : 
                                                                  (i_ROT20_n[10] == 1'b0) ? (eq97_flag_n | ~i_BDI_EN) : acq_start_flag_n;

assign  o_ACQ_START = ~acq_start_flag_n;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq97_flag_n <= (((i_CYCLECNTR_LSB | i_HALT) ^ const97) | eq97_flag_n | i_UMODE_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        acq_start_flag_n <= (|{~i_ACC_INVAL_n, i_BDI_EN, ~i_PGCMP_EQ, i_ROT20_n[14]} & i_SYNCTIP_n) & acq_start_flag_feedback;
    end
end


//delayed ~ROT20_n[18] ...why not D19?
reg             rot20_d18_dlyd;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        rot20_d18_dlyd <= ~i_ROT20_n[18];
    end
end

assign  o_ADDR_RST = o_ACQ_START & rot20_d18_dlyd;


endmodule