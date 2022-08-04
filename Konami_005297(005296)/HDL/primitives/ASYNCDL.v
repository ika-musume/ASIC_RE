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

module ASYNCDL
(
    input   wire            i_SET,
    input   wire            i_EN,
    input   wire            i_D,
    output  reg             o_Q
);

always @(*) begin
    if(i_SET) begin
        o_Q <= 1'b1;
    end
    else begin
        if(i_EN) begin
            o_Q <= i_D;
        end
        else begin
            o_Q <= o_Q;
        end
    end
end

endmodule