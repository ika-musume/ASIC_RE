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

module DL #(parameter dw=1)
(
    input   wire                i_CLK,
    input   wire                i_CEN_n,

    input   wire                i_EN,
    input   wire    [dw-1:0]    i_D,
    output  wire    [dw-1:0]    o_Q,
    output  wire    [dw-1:0]    o_Q_n
);

reg     [dw-1:0]    DFF;
wire    [dw-1:0]    OUTPUT = (i_EN == 1'b0) ? DFF : i_D;

assign  o_Q = OUTPUT;
assign  o_Q_n = ~OUTPUT;

always @(posedge i_CLK) begin
    if(!i_CEN_n) begin
        if(i_EN) begin
            DFF <= i_D;
        end
    end
end

endmodule