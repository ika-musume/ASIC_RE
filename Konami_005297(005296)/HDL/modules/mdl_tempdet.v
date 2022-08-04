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

module mdl_tempdet
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //control
    input   wire            i_TEMPLO_n,
    input   wire            i_CLK2M_STOP_n,
    input   wire            i_CLK2M_STOP_DLYD_n,

    output  wire            o_TEMPDROP_SET_n,
    output  wire            o_HEATEN_n
);


//register for edge detection
reg             edgedet_0, edgedet_1;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        edgedet_0 <= i_CLK2M_STOP_n & i_TEMPLO_n;
        edgedet_1 <= i_CLK2M_STOP_DLYD_n;
    end
end

//TEMPDROP flag
assign          o_TEMPDROP_SET_n = ~(edgedet_0 & ~(i_CLK2M_STOP_n & i_TEMPLO_n)); //negative edge detection


wire            heaten_clr_n = ~(~edgedet_0 & (i_CLK2M_STOP_n & i_TEMPLO_n)) & i_CLK2M_STOP_n; //positive edge detection
wire            heaten_set_n = ~((~edgedet_1 & i_CLK2M_STOP_DLYD_n & ~i_TEMPLO_n) & heaten_clr_n);

//delay
reg     [1:0]   heaten_ctrl_n;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        heaten_ctrl_n[1] <= heaten_clr_n;
        heaten_ctrl_n[0] <= heaten_set_n;
    end
end

//HEATEN_n out
SRNAND C20 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(heaten_ctrl_n[1]), .i_R_n(heaten_ctrl_n[0]), .o_Q(o_HEATEN_n), .o_Q_n());


endmodule