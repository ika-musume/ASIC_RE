module K005297_fsm
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

K005297_fsm_pla pla_main
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


module K005297_fsm_pla
(
    input   wire            i_A,
    input   wire            i_B,
    input   wire            i_C,
    input   wire            i_D,
    input   wire            i_E,
    input   wire            i_F,
    input   wire            i_G,
    input   wire            i_H,

    output  wire            o_S,
    output  wire            o_T,
    output  wire            o_U,
    output  wire            o_V,
    output  wire            o_W,
    output  wire            o_X,
    output  wire            o_Y,
    output  wire            o_Z
);

//internal wires
wire    A = i_A; //CMDREG.RDREQ
wire    B = i_B; //CMDREG.WRREQ
wire    C = i_C; //FSMSTAT.D0
wire    D = i_D; //FSMSTAT.D1
wire    E = i_E; //FSMSTAT.D2
wire    F = i_F; //F25/Q
wire    G = i_G; //FSMFLAGIN
wire    H = i_H; //SYS_ERR_FLAG


//AND array 1
wire    S36 =   &{    A, ~B,  C, ~D,  E, ~F,     ~H   };
wire    S44 =   &{   ~A,  B,             ~F, ~G       };
wire    S43 =   &{   ~A,  B, ~C, ~D,  E, ~F,     ~H   };
wire    R49 =   &{           ~C,  D, ~E,         ~H   };
wire    S42 =   &{   ~A,  B, ~C,  D,  E, ~F,     ~H   };
wire    R50 =   &{            C,  D, ~E,         ~H   };
wire    S41 =   &{    A, ~B,             ~F, ~G       };
wire    S29 =   &{   ~A, ~B,             ~F, ~G       };
wire    R36 =   &{            C,  D,  E,         ~H   };
wire    S37 =   &{   ~A, ~B,              F,  G       };

//misc
wire    S45 = S44 | S37; //~A
wire    R33 = A ^ B;

//AND array 2
wire    R35 =   &{               ~D, ~E,         ~H   } & S29;
wire    R32 =   &{   ~A,  B                           } & R36;
wire    S31 =   &{                           ~G       } & S43;
wire    R29 =   &{    A, ~B,             ~F           } & R36;
wire    S30 =   &{                           ~G       } & S36;
wire    S27 =                                             R49 & S29;
wire    S50 =   &{   ~A, ~B, ~C, ~D, ~E,          H   };
wire    S49 =   &{   ~A, ~B, ~C, ~D, ~E, ~F,  G, ~H   };
wire    S46 =                                             S44 & R50;
wire    S38 =   &{                            G       } & S36;
wire    T42 =   &{                           ~G       } & S42;
wire    T40 =   &{                            G       } & S43;
wire    S48 =                                             R49 & S41;
wire    S47 =                                             S44 & R49;
wire    R52 =                                             R50 & S41;
wire    S51 =   &{            C, ~D, ~E,         ~H   } & S45;
wire    T41 =   &{                            G       } & S42;
wire    R34 =                                             S29 & R36;
wire    R37 =   &{            C,  D,  E,          H   } & R33;
wire    R30 =   &{    A, ~B,              F           } & R36;
wire    S40 =   &{            C, ~D, ~E,          H   } & S29;

//OR array
wire    S28 = |{R35, R32, S31, R29, S30, S27};

assign  o_S  = ~(|{S50, S49, S46, S38, T42, T40, R52, T41, R34} | S28);
assign  o_T  = ~ S40;
assign  o_U  = ~|{S48, S47};

assign  o_V  = ~(|{S49, T42, T40, T41, R34, S40} | S28);
assign  o_W  = ~|{S38, S47};
assign  o_X  = ~|{S46, S38, R52};

assign  o_Y  = ~|{S49, S46, T42, S48, S47, S51, T41, R34, R37, R30};
assign  o_Z  = ~|{S38, T40, R52, T41, R34, R37, R30, S40};

endmodule