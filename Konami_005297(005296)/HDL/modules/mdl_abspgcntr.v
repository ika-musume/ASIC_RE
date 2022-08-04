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

module mdl_abspgcntr
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_ABSPGCNTR_CNT_STOP,
    input   wire            i_ABSPGCNTR_CNT_START,
    input   wire            i_ALD_nB_U,

    output  wire            o_ABSPGCNTR_LSB
);



///////////////////////////////////////////////////////////
//////  RELATIVE PAGE COUNTER
////

/*
    gte(greater than or equal) flag(>= 1531 evaluation)
    relative page 0-1530: +522
    relative page 1531-2052: -1531(loop)
*/


//SR shift enable
wire            abspgcntr_shift; //shift flag
SRNAND I24 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(abspgcntr_shift));


//const add enable
wire            abspgcntr_add_en;
SRNOR I34 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S(i_ABSPGCNTR_CNT_STOP), .i_R(i_ABSPGCNTR_CNT_START), .o_Q(), .o_Q_n(abspgcntr_add_en));

 
reg     [11:0]  abspgcntr = 12'd0; //abs page counter
wire            abspgcntr_const, abspgcntr_fa_sum, abspgcntr_fa_cout; //FA carry out
reg             abspgcntr_fa_cflag = 1'b0; //FA carry storage
assign  o_ABSPGCNTR_LSB = abspgcntr_fa_sum & i_ALD_nB_U;

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(abspgcntr_shift == 1'b1) begin
            abspgcntr[11] <= o_ABSPGCNTR_LSB;
            abspgcntr[10:0] <= abspgcntr[11:1];
        end
        else begin
            abspgcntr <= abspgcntr;
        end
    end
end


//constant generator: +522 or -1531
wire            constP522 = ~&{i_ROT20_n[9], i_ROT20_n[3], i_ROT20_n[1]};
wire            constN1531 = ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]};
reg             gte1531_evalreg = 1'b0;
reg             gte1531_flag = 1'b0;
assign  abspgcntr_const = (gte1531_flag == 1'b0) ? constP522 : constN1531;
                                                //+522 : -1531
//evaluator: greater than or equal to 1531
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        gte1531_evalreg <= ((abspgcntr_fa_sum & ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) | 
                           ((o_ABSPGCNTR_LSB | ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) & gte1531_evalreg)) &
                           i_ROT20_n[19];

        gte1531_flag <= (i_ROT20_n[12] == 1'b0) ? gte1531_evalreg : gte1531_flag;
    end
end


//adder
FA J30 (.i_A(abspgcntr_add_en & abspgcntr_const), .i_B(abspgcntr_fa_cflag), .i_CIN(abspgcntr[0]), .o_S(abspgcntr_fa_sum), .o_COUT(abspgcntr_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        abspgcntr_fa_cflag <= abspgcntr_fa_cout & i_ROT20_n[19];
    end
end


endmodule