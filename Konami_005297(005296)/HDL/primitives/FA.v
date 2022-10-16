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

module FA
(
    input   wire            i_A,
    input   wire            i_B,
    input   wire            i_CIN,

    output  wire            o_S,
    output  wire            o_COUT
);

assign  o_S = (i_CIN == 1'b0) ? (i_A ^ i_B) : ~(i_A ^ i_B);
assign  o_COUT = (i_CIN == 1'b0) ? (i_A & i_B) : (i_A | i_B);

endmodule