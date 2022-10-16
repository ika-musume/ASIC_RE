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

module mdl_byteacqcntr
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
    input   wire            i_GLCNT_RD,
    input   wire            i_NEWBYTE,
    input   wire            i_ACC_ACT_n,
    input   wire            i_BUBWR_WAIT,

    output  reg             o_BYTEACQ_DONE = 1'b0
);



///////////////////////////////////////////////////////////
//////  BYTE ACQUISITION COUNTER
////

//byte acquisition counter
reg     [2:0]   byte_acq_cntr = 3'h7;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if((i_NEWBYTE | i_ACC_ACT_n) == 1'b1) begin //reset
            byte_acq_cntr <= 3'h7;
        end
        else begin
            if(i_GLCNT_RD == 1'b1) begin
                if(byte_acq_cntr == 3'h0) begin
                    byte_acq_cntr <= 3'h7;
                end
                else begin
                    byte_acq_cntr <= byte_acq_cntr - 3'h1;
                end
            end
            else begin
                byte_acq_cntr <= byte_acq_cntr;
            end
        end
    end
end

//flag
wire            eq7 = (byte_acq_cntr == 3'h0) ? 1'b1 : 1'b0;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) == 1'b1) begin //3-8_13-18
            o_BYTEACQ_DONE <= eq7 | i_BUBWR_WAIT;
        end
        else begin
            o_BYTEACQ_DONE <= o_BYTEACQ_DONE;
        end
    end
end


endmodule