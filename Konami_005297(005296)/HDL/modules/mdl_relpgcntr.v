module mdl_relpgcntr
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_RELPGCNTR_CNT_STOP,
    input   wire            i_RELPGCNTR_CNT_START,
    input   wire            i_ALD_nB_U,

    output  wire            o_RELPGCNTR_LSB
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
wire            relpgcntr_shift; //shift flag
SRNAND I24 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(relpgcntr_shift));


//const add enable
wire            relpgcntr_add_en;
SRNOR I34 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S(i_RELPGCNTR_CNT_STOP), .i_R(i_RELPGCNTR_CNT_START), .o_Q(), .o_Q_n(relpgcntr_add_en));

 
reg     [11:0]  relpgcntr = 12'd0; //abs page counter
wire            relpgcntr_const, relpgcntr_fa_sum, relpgcntr_fa_cout; //FA carry out
reg             relpgcntr_fa_cflag = 1'b0; //FA carry storage
assign  o_RELPGCNTR_LSB = relpgcntr_fa_sum & i_ALD_nB_U;

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(relpgcntr_shift == 1'b1) begin
            relpgcntr[11] <= o_RELPGCNTR_LSB;
            relpgcntr[10:0] <= relpgcntr[11:1];
        end
        else begin
            relpgcntr <= relpgcntr;
        end
    end
end


//constant generator: +522 or -1531
wire            constP522 = ~&{i_ROT20_n[9], i_ROT20_n[3], i_ROT20_n[1]};
wire            constN1531 = ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]};
reg             gte1531_evalreg = 1'b0;
reg             gte1531_flag = 1'b0;
assign  relpgcntr_const = (gte1531_flag == 1'b0) ? constP522 : constN1531;
                                                //+522 : -1531
//evaluator: greater than or equal to 1531
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        gte1531_evalreg <= ((relpgcntr_fa_sum & ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) | 
                           ((o_RELPGCNTR_LSB | ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) & gte1531_evalreg)) &
                           i_ROT20_n[19];

        gte1531_flag <= (i_ROT20_n[12] == 1'b0) ? gte1531_evalreg : gte1531_flag;
    end
end


//adder
FA J30 (.i_A(relpgcntr_add_en & relpgcntr_const), .i_B(relpgcntr_fa_cflag), .i_CIN(relpgcntr[0]), .o_S(relpgcntr_fa_sum), .o_COUT(relpgcntr_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        relpgcntr_fa_cflag <= relpgcntr_fa_cout & i_ROT20_n[19];
    end
end


endmodule