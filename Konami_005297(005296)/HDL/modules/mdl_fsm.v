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

module mdl_fsm
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //CMDREG related
    input   wire            i_CMDREG_RDREQ,
    input   wire            i_CMDREG_WRREQ,
    output  wire            o_CMDREG_RST_n,

    //system flags
    input   wire            i_SYS_RUN_FLAG,
    input   wire            i_SYS_ERR_FLAG,
    output  wire            o_FSMERR_RESTART_n,

    input   wire            i_SUPBD_ACT_n,
    input   wire            i_PGCMP_EQ,
    input   wire            i_VALPG_ACC_FLAG,
    input   wire            i_PGREG_SR_SHIFT,
    input   wire            i_SUMEQ_n,
    input   wire            i_MUXED_BDO_EN_DLYD,
    input   wire            i_OP_DONE, //???

    //bubble input enable
    output  wire            o_BDI_EN_SET_n,
    output  wire            o_BDI_EN_RST_n,

    //page register shift register parallel load enable
    output  wire            o_PGREG_SRLD_EN,
    
    //bubble IO related
    output  wire            o_ACC_START,
    output  wire            o_REP_START,
    
    //???
    output  wire            o_CMD_ACCEPTED_n //???
);


/*
        FSM STATE

    0: Initial state
    1: Bootloader Z14(CRC14 zero) flag check state. If nz, hangs on here.
    2: User mode idle
    3: R/W request acceptance
    4: Wait for page swapping
    5: Wait for page replication
    6: Swap start
    7: Page R/W operation

    bootloader:
    0->1->2

    page read:
    2->3->5->7->2

    page write:
    2->3->4->7->2
*/



///////////////////////////////////////////////////////////
//////  FSM STATE REGISTER
////

reg     [2:0]   fsmstat_sr = 3'b000; //state register
wire            fsmstat_shift; //shift flag: 4-5-6, Q38 SRNAND
SRNAND Q38 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[7]), .i_R_n(i_ROT20_n[4]), .o_Q(), .o_Q_n(fsmstat_shift));

//state adder variable
reg     [1:0]   fsmstat_nxtstat = 2'd3; //3: 1'b0, 2: nROT20[5], 1: nROT20[4], 0: nROT20[4, 5]
reg             fsmstat_var;

always @(*) begin
    case(fsmstat_nxtstat)
        2'd0: fsmstat_var <= ~(i_ROT20_n[4] & i_ROT20_n[5]);
        2'd1: fsmstat_var <= ~i_ROT20_n[4];
        2'd2: fsmstat_var <= ~i_ROT20_n[5];
        2'd3: fsmstat_var <= 1'b0;
    endcase
end
//wire            fsmstat_var = (fsmstat_nxtstat[1] == 1'b1) ? ((fsmstat_nxtstat[0] == 1'b1) ? 1'b0 : ~i_ROT20_n[5]) :
//                                                            ((fsmstat_nxtstat[0] == 1'b1) ? ~i_ROT20_n[4] : ~(i_ROT20_n[4] & i_ROT20_n[5]));

//full adder
wire            fsmstat_fa_sum, fsmstat_fa_cout;
reg             fsmstat_fa_cflag;
FA P56 (.i_A(fsmstat_var), .i_B(fsmstat_sr[0]), .i_CIN(fsmstat_fa_cflag), .o_S(fsmstat_fa_sum), .o_COUT(fsmstat_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        fsmstat_fa_cflag <= fsmstat_fa_cout & i_ROT20_n[19];
    end
end

//fsm state shift
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(fsmstat_shift == 1'b1) begin //shift
            fsmstat_sr[2] <= fsmstat_fa_sum & i_SYS_RUN_FLAG;
            fsmstat_sr[1:0] <= fsmstat_sr[2:1];
        end
        else begin //hold
            fsmstat_sr[2] <= fsmstat_sr[2] & i_SYS_RUN_FLAG;
            fsmstat_sr[1:0] <= fsmstat_sr[1:0];
        end
    end
end

//parallel load
reg     [2:0]   fsmstat_parallel = 3'b000;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[7] == 1'b0) begin //D-latch loads at nROT20[8]
            fsmstat_parallel <= fsmstat_sr;
        end
        else begin
            fsmstat_parallel <= fsmstat_parallel;
        end
    end
end






///////////////////////////////////////////////////////////
//////  FSM FLAG
////

reg             fsmflag;
always @(*) begin
    case(fsmstat_parallel)
        3'd0: fsmflag <= ~i_SUPBD_ACT_n;
        3'd1: fsmflag <= i_OP_DONE;
        3'd2: fsmflag <= 1'b0;
        3'd3: fsmflag <= 1'b0;
        3'd4: fsmflag <= i_PGCMP_EQ;
        3'd5: fsmflag <= i_PGCMP_EQ;
        3'd6: fsmflag <= 1'b0;
        3'd7: fsmflag <= &{~i_ROT20_n[8], ~i_SUPBD_ACT_n, ~i_VALPG_ACC_FLAG, (i_PGREG_SR_SHIFT & i_MUXED_BDO_EN_DLYD), i_SUMEQ_n};
    endcase
end






///////////////////////////////////////////////////////////
//////  AND-OR MATRIX
////

wire    [7:0]   pla_output;

reg     [1:0]   command_a_en = 2'b00; //initialize output register
reg     [1:0]   command_b_en = 2'b00;

reg     [1:0]   command_a_0 = 2'b00; //command synchronizer chain: async input from CPU(RD/WR commands)
reg     [1:0]   command_b_0 = 2'b00;

reg     [1:0]   command_a_1 = 2'b00;
reg     [1:0]   command_b_1 = 2'b00;

submdl_pla pla_main
(
    .i_A                        (i_CMDREG_RDREQ             ), //CMDREG.RDREQ
    .i_B                        (i_CMDREG_WRREQ             ), //CMDREG.WRREQ
    .i_C                        (fsmstat_parallel[0]        ), //FSMSTAT.D0
    .i_D                        (fsmstat_parallel[1]        ), //FSMSTAT.D1
    .i_E                        (fsmstat_parallel[2]        ), //FSMSTAT.D2
    .i_F                        (i_OP_DONE                  ), //OP_DONE
    .i_G                        (fsmflag                    ), //FSMFLAGIN
    .i_H                        (i_SYS_ERR_FLAG             ), //SYS_ERR_FLAG

    .o_S                        (pla_output[5]               ),
    .o_T                        (pla_output[4]               ),
    .o_U                        (pla_output[3]               ),

    .o_V                        (pla_output[2]               ),
    .o_W                        (pla_output[1]               ),
    .o_X                        (pla_output[0]               ),

    .o_Y                        (pla_output[7]               ),
    .o_Z                        (pla_output[6]               )
);

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[9] == 1'b0) begin //D-latch loads at nROT20[10]
            fsmstat_nxtstat <= pla_output[7:6];
        end
    end
end


wire            r59 = pla_output[5] & ~pla_output[4] & ~pla_output[3];




//
//  FSM COMMAND/ENABLE SYNCHRONIZER CHAIN(2)
//

//The FSM gets bubble RW command from the asynchronous latch and decodes it.
//Sample the value @ negedge ROT20_n[10] and shift it @ posedge ROT20_n[10].
//RW command output automatically disabled @ ROT20_n[10], so shifter's output
//can be presented @ posedge ROT20_n[10].

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[9] == 1'b0) begin //D-latch loads at nROT20[10]
            command_a_en[0] <= pla_output[5];
            command_a_en[1] <= 1'b0;

            command_b_en[0] <= pla_output[2];
            command_b_en[1] <= 1'b0;
        end
        else if(i_ROT20_n[10] == 1'b0) begin
            command_a_en[1] <= command_a_en[0];

            command_b_en[1] <= command_b_en[0];
        end
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[9] == 1'b0) begin //D-latch loads at nROT20[10]
            command_a_0 <= pla_output[4:3];

            command_b_0 <= pla_output[1:0];
        end
        else if(i_ROT20_n[10] == 1'b0) begin
            command_a_1 <= command_a_0;

            command_b_1 <= command_b_0;
        end
    end
end






///////////////////////////////////////////////////////////
//////  COMMAND DECODER
////


assign  o_CMDREG_RST_n =      ~&{ command_a_1[1],  command_a_1[0], command_a_en[1]}; //NAND /3'b111

assign  o_FSMERR_RESTART_n =  ~&{~command_a_1[1],  command_a_1[0], command_a_en[1]}; //NAND /3'b101

assign  o_BDI_EN_SET_n =      ~&{ command_b_1[1],  command_b_1[0], command_b_en[1]}; //NAND /3'b111
assign  o_BDI_EN_RST_n =      ~&{~command_b_1[1],  command_b_1[0], command_b_en[1]}; //NAND /3'b101

assign  o_PGREG_SRLD_EN =      &{ command_a_1[1], ~command_a_1[0], command_a_en[1]}; //AND 3'b110

assign  o_ACC_START =          &{ command_b_1[1], ~command_b_1[0], command_b_en[1]}; //AND 3'b110
assign  o_REP_START =          &{~command_b_1[1], ~command_b_1[0], command_b_en[1]}; //AND 3'b100

assign  o_CMD_ACCEPTED_n =    ~&{~command_a_1[1], ~command_a_1[0], command_a_en[1]}; //NAND 3'b100 //NOR??


endmodule