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

module SRNOR
(
    input   wire            i_CLK,
    input   wire            i_CEN_n,

    input   wire            i_S,
    input   wire            i_R,
    output  wire            o_Q,
    output  wire            o_Q_n
);

reg             DFF = 1'b1;
reg             Q;

assign  o_Q = Q;
assign  o_Q_n = ~Q;

always @(posedge i_CLK) begin
    if(!i_CEN_n) begin
        case({i_S, i_R})
            2'b00: DFF <= DFF; //hold
            2'b01: DFF <= 1'b0; //reset
            2'b10: DFF <= 1'b1; //set
            2'b11: DFF <= DFF; //hold(illegal)
        endcase
    end
end

always @(*) begin
    case({i_S, i_R, DFF})
        3'b000: Q <= DFF; //유지
        3'b001: Q <= DFF; //유지
        3'b010: Q <= DFF; //reset이고 DFF가 0인경우
        3'b011: Q <= 1'b0; //reset인데 DFF가 1인경우
        3'b100: Q <= 1'b1; //set인데 DFF가 0인경우
        3'b101: Q <= DFF; //set이고 DFF가 1인경우
        3'b110: Q <= DFF; //illegal
        3'b111: Q <= DFF; //illegal
    endcase
end

endmodule