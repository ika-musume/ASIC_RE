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

module submdl_rot8
(
    input   wire            i_CLK,
    input   wire            i_CEN_n,

    input   wire            i_STOP_n,
    output  wire    [7:0]   o_ROT8
);

reg     [7:0]   SR8 = 8'b0;
assign  o_ROT8 = SR8;

always @(posedge i_CLK) begin
    if(~i_CEN_n) begin
        SR8[7:1] <= SR8[6:0];
        SR8[0] <= ~|{SR8[6:0], ~i_STOP_n}; //A55 NOT
    end
end

endmodule