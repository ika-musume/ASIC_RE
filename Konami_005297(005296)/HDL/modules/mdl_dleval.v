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

module mdl_dleval
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_TST,
    input   wire            i_SYS_RST_n,
    
    input   wire            i_4BEN_n,
    input   wire            i_UMODE_n,
    input   wire            i_DLCNTR_LSB,
    input   wire            i_DLCNTR_CFLAG,

    input   wire            i_BYTEACQ_DONE,
    input   wire            i_SUPBD_END_n,

    output  wire            o_SUPBD_START_n
);



///////////////////////////////////////////////////////////
//////  DATA LENGTH COUNTER
////

//eq480
wire            const480 = ~&{i_ROT20_n[8], i_ROT20_n[7], i_ROT20_n[6], i_ROT20_n[5]};
reg             eq480_flag_n = 1'b0;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq480_flag_n <= (((i_DLCNTR_LSB ^ const480) | eq480_flag_n) & i_ROT20_n[19]);
    end
end

//bootloader done flag
reg             boot_done = 1'b0;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        boot_done <= (i_ROT20_n[9] == 1'b0) ? (~eq480_flag_n | i_TST) & i_UMODE_n :
                                              boot_done & i_UMODE_n;
    end
end


//page done flag
reg             pg_done = 1'b0;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_4BEN_n == 1'b1) begin //2bit mode
            pg_done <= (i_ROT20_n[7] == 1'b0) ? ((i_TST | i_DLCNTR_CFLAG) & ~i_UMODE_n) : pg_done;
        end
        else begin //4bit mode
            pg_done <= (i_ROT20_n[8] == 1'b0) ? ((i_TST | i_DLCNTR_CFLAG) & ~i_UMODE_n) : pg_done;
        end
    end
end



///////////////////////////////////////////////////////////
//////  EFFECTIVE BUBBLE DATA END FLAG
////

wire            effbd_done = ~((boot_done | pg_done) & ~i_ROT20_n[10]);
wire            supbd_rdy;
assign          o_SUPBD_START_n = ~&{supbd_rdy, i_BYTEACQ_DONE, ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n))} & i_SYS_RST_n;

SRNAND K23 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_END_n), .i_R_n(effbd_done), .o_Q(), .o_Q_n(supbd_rdy));


endmodule