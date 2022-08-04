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

module mdl_bubrdfe
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //system reset
    input   wire            i_SYS_RST_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_BDI_EN_SET_n,
    input   wire            i_BDI_EN_RST_n,

    input   wire    [3:0]   i_BDIN_n,

    //output
    output  wire            o_BDI,

    output  wire            o_BDI_EN
);


//input enable
SRNAND F32 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n((i_BDI_EN_SET_n & i_SYS_RST_n)), .i_R_n(i_BDI_EN_RST_n), .o_Q(o_BDI_EN), .o_Q_n());

//mux select counter
reg     [1:0]   mux_cntr = 2'd0;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[0] == 1'b0) begin
            mux_cntr <= 2'd0;
        end 
        else begin
            if(~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) == 1'b1) begin //3-8_13-18
                if(mux_cntr == 2'd3) begin
                    mux_cntr <= 2'd0;
                end
                else begin
                    mux_cntr <= mux_cntr + 2'd1;
                end
            end
            else begin
                mux_cntr <= mux_cntr;
            end
        end
    end
end

//bubble inlatch
reg     [3:0]   bubble_inlatch;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[18] == 1'b0) begin //d-latch latches SR data at ROT20_n[19]
            bubble_inlatch <= i_BDIN_n;
        end
    end
end

//in mux
reg             bubble_stream;
wire    [1:0]   mux_select = {(mux_cntr[1] & ~i_4BEN_n), mux_cntr[0]};
always @(*) begin
    case(mux_select) //bit3->2->1->0
        2'd0: bubble_stream <= bubble_inlatch[3];
        2'd1: bubble_stream <= bubble_inlatch[2];
        2'd2: bubble_stream <= bubble_inlatch[1];
        2'd3: bubble_stream <= bubble_inlatch[0];
    endcase
end

assign  o_BDI = ~bubble_stream & o_BDI_EN;


endmodule