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

module mdl_supervisor
(
    //master clock
    input   wire            i_MCLK,

    //chip clock from bubble cart, synchronized to i_MCLK
    input   wire            i_CLK4M_PCEN_n,

    //master reset
    input   wire            i_MRST_n,

    //halt
    input   wire            i_HALT_n,

    //subclock control
    input   wire            i_CLK2M_STOPRQ0_n,
    input   wire            i_CLK2M_STOPRQ1_n,
    output  wire            o_CLK2M_STOP_n,
    output  wire            o_CLK2M_STOP_DLYD_n,
    output  wire            o_CLK2M_PCEN_n,

    //rotators
    output  wire    [7:0]   o_ROT8,
    output  wire    [19:0]  o_ROT20_n,

    //system flags
    output  wire            o_SYS_RST_n,
    output  wire            o_SYS_RUN_FLAG,
    output  wire            o_SYS_RUN_FLAG_SET_n
);





/*
    CLOCKING INFORMATION

    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|


    NCLK
    orig in     _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|

    stage 0     ¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|________
    stage 5     __________|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯
    0 AND 5     _______________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|


    PCLK
    orig in     ¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|________

    stage 0     _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    stage 5     ¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_____
    0 AND 5     _______|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|_____


    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    4M NCLK     _______________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|
    4M PCLK     _______|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|_____

    ROT8        -(7)---|------(0)------|------(1)------|------(2)------|------(3)------|------(4)------|------(5)------|----(6)-
    ROT8[0]     _______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________________________________________________________

    C2STOPDLYn  _______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    A59 OUT     ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯
    A60 OUT     _______________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________

    A62 EN      _______________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|
    A62 OUT     _______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|

    A60         _______________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________
    A62         _______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|

    A64(01)PCLK _______________________________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|
    A66(10)NCLK _______________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|________________

    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    2MHz        ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯


    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    2MHz        ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________

    ROT8        -(7)---|------(0)------|------(1)------|------(2)------|------(3)------|------(4)------|------(5)------|----(6)-
    PORCNTR     -----------------(7)-------------------|-------------------------------------(6)--------------------------------
    4M PCLK     _______|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|_____

    C2RDYn      ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|__|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    OPSTOP      ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________________________________________
    ROT20n      -----------------------(invalid)-----------------------|--------------(0)--------------|--------------(1)-------
*/


///////////////////////////////////////////////////////////
//////  GLOBAL CLOCKS / FLAGS
////

//all stoarge elements works at falling edge of 4M/2M
wire            CLK4P_n = i_CLK4M_PCEN_n;   //4MHz clock from bubble memory cartridge 12MHz/3
wire            CLK2P_n;                    //2MHz internal subclock that can be controlled by start/stop logic






///////////////////////////////////////////////////////////
//////  MODULE ROT8
////

submdl_rot8 rot8_main (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_STOP_n(i_HALT_n), .o_ROT8(o_ROT8)); //FREE-RUNNING 8-BIT ROTATOR, rotates bit 1 from LSB to MSB 



///////////////////////////////////////////////////////////
//////  CLK2M(SUBCLK) CONTROL/GENERATOR
////

//subclk control
//SYS_RUN_FLAG가 0이면 clk2m시동을 걸어줌, 1로 올라간 후에는 clk2m정지 플래그들이 제어
wire            clk2m_ctrl = &{i_MRST_n, i_CLK2M_STOPRQ0_n, i_CLK2M_STOPRQ1_n} | ~o_SYS_RUN_FLAG; //A37 A36 A38

reg             A41 = 1'b0;
wire            clk2m_stop_n = i_MRST_n & A41;
wire            clk2m_stop_dlyd_n;
assign  o_CLK2M_STOP_n = clk2m_stop_n;
assign  o_CLK2M_STOP_DLYD_n = clk2m_stop_dlyd_n;

always @(posedge i_MCLK) begin
    if(!CLK4P_n) begin
        A41 <= (o_ROT8[5] == 1'b0) ? A41 : clk2m_ctrl; //MUX 0:1
    end
end

DL A42 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_EN(o_ROT8[0]), .i_D(clk2m_stop_n), .o_Q(clk2m_stop_dlyd_n), .o_Q_n());

//subclk generator
//negative clock enable신호 생성
reg             A59 = 1'b0;
always @(posedge i_MCLK) begin
    if(!CLK4P_n) begin
        A59 <= ~(A59 & clk2m_stop_dlyd_n); //1이면 flip, 0이면 1유지
    end
end

assign  CLK2P_n = ~(A59 | CLK4P_n);
assign  o_CLK2M_PCEN_n = CLK2P_n;



///////////////////////////////////////////////////////////
//////  POR CONTROL
////

//this counter is for ring counter synchronization; they follow the order below:
//rot8    3 4 5 6 7 0 1 2 3 4 5 6
//rot20   0   1   2   3   4   5

reg     [3:0]   por_cntr = 4'b1111; //cascaded T flip flops; A23 A24 A25 A27
always @(posedge i_MCLK) begin
    if(!CLK4P_n) begin
        if(~clk2m_stop_dlyd_n == 1'b1) begin //set
            por_cntr <= 4'b1111;
        end
        else begin
            if(~o_ROT8[1] == 1'b0) begin //count
                if(por_cntr == 4'b0000) begin
                    por_cntr <= 4'b1111; //loop
                end
                else begin
                    por_cntr <= por_cntr - 4'b1;
                end
            end
            else begin
                por_cntr <= por_cntr; //hold
            end
        end
    end
end

wire            op_start_n = ~&{o_ROT8[0], por_cntr[3:1], ~por_cntr[0]}; //A22
wire            op_stop;
wire            clk2m_ready_n = ~&{~por_cntr[3], ~por_cntr[0]}; //A29

wire            A30Q;
assign  op_stop = ~A30Q;

SRNAND A30 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_S_n(clk2m_ready_n), .i_R_n(clk2m_stop_n), .o_Q(A30Q), .o_Q_n());
SRNAND A21 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_S_n(op_start_n), .i_R_n(A30Q), .o_Q(o_SYS_RST_n), .o_Q_n());



///////////////////////////////////////////////////////////
//////  MODULE ROT20
////

submdl_rot20 rot20_main (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_STOP(op_stop), .o_ROT20_n(o_ROT20_n)); //20-BIT ROTATOR, rotates bit 1 from LSB to MSB 



///////////////////////////////////////////////////////////
//////  SYS_RUN_FLAG_n
////

assign  o_SYS_RUN_FLAG_SET_n = ~(o_SYS_RST_n & ~o_ROT20_n[19]);

SRNAND C30 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_S_n(o_SYS_RST_n), .i_R_n(o_SYS_RUN_FLAG_SET_n), .o_Q(), .o_Q_n(o_SYS_RUN_FLAG));



///////////////////////////////////////////////////////////
//////  RING COUNTER DECODER
////

wire            __REF_4M = ~i_MCLK;
reg     [4:0]   __ROT20_VALUE;
reg     [2:0]   __ROT8_VALUE;

always @(*) begin
    case(o_ROT20_n)
        20'b1111_1111_1111_1111_1110: __ROT20_VALUE <= 5'd0;
        20'b1111_1111_1111_1111_1101: __ROT20_VALUE <= 5'd1;
        20'b1111_1111_1111_1111_1011: __ROT20_VALUE <= 5'd2;
        20'b1111_1111_1111_1111_0111: __ROT20_VALUE <= 5'd3;
        20'b1111_1111_1111_1110_1111: __ROT20_VALUE <= 5'd4;
        20'b1111_1111_1111_1101_1111: __ROT20_VALUE <= 5'd5;
        20'b1111_1111_1111_1011_1111: __ROT20_VALUE <= 5'd6;
        20'b1111_1111_1111_0111_1111: __ROT20_VALUE <= 5'd7;
        20'b1111_1111_1110_1111_1111: __ROT20_VALUE <= 5'd8;
        20'b1111_1111_1101_1111_1111: __ROT20_VALUE <= 5'd9;
        20'b1111_1111_1011_1111_1111: __ROT20_VALUE <= 5'd10;
        20'b1111_1111_0111_1111_1111: __ROT20_VALUE <= 5'd11;
        20'b1111_1110_1111_1111_1111: __ROT20_VALUE <= 5'd12;
        20'b1111_1101_1111_1111_1111: __ROT20_VALUE <= 5'd13;
        20'b1111_1011_1111_1111_1111: __ROT20_VALUE <= 5'd14;
        20'b1111_0111_1111_1111_1111: __ROT20_VALUE <= 5'd15;
        20'b1110_1111_1111_1111_1111: __ROT20_VALUE <= 5'd16;
        20'b1101_1111_1111_1111_1111: __ROT20_VALUE <= 5'd17;
        20'b1011_1111_1111_1111_1111: __ROT20_VALUE <= 5'd18;
        20'b0111_1111_1111_1111_1111: __ROT20_VALUE <= 5'd19;
    endcase

    case(o_ROT8)
        8'b0000_0001: __ROT8_VALUE <= 3'd0;
        8'b0000_0010: __ROT8_VALUE <= 3'd1;
        8'b0000_0100: __ROT8_VALUE <= 3'd2;
        8'b0000_1000: __ROT8_VALUE <= 3'd3;
        8'b0001_0000: __ROT8_VALUE <= 3'd4;
        8'b0010_0000: __ROT8_VALUE <= 3'd5;
        8'b0100_0000: __ROT8_VALUE <= 3'd6;
        8'b1000_0000: __ROT8_VALUE <= 3'd7;
    endcase
end



endmodule