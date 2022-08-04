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

module submdl_rot20
(
    input   wire            i_CLK,
    input   wire            i_CEN_n,

    input   wire            i_STOP,
    output  wire    [19:0]  o_ROT20_n
);

reg     [19:0]  SR20 = 20'b0000_0001_0000_0010_0000;
assign  o_ROT20_n = ~SR20;

always @(posedge i_CLK) begin
    if(~i_CEN_n) begin
        SR20[19:1] <= SR20[18:0];
        SR20[0] <= ~|{SR20[18:0], i_STOP};
    end
end

endmodule