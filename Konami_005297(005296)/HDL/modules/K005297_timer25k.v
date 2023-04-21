module K005297_timer25k
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //timer
    input   wire            i_TIMER25K_CNT,
    input   wire            i_TIMER25K_OUTLATCH_LD_n,
    output  wire            o_TIMER25K_TIMEOVER_n,

    output  reg     [11:0]  o_TIMERREG_LSBS = 12'd0
);



///////////////////////////////////////////////////////////
//////  2556 TIMER(500ns*2556 = 1.278ms)
////

///////////////////////////////////////////////////////////
//////  CYCLE COUNTER
////

/*
    +1 serial up counter
*/

//shift flag
wire            timer25k_shift; 
SRNAND K3 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(timer25k_shift));


reg     [11:0]  timer25k = 12'd0; //timer
wire            timer25k_fa_sum; //msb input
wire            timer25k_fa_cout; //FA carry out
reg             timer25k_fa_cflag = 1'b0; //FA carry storage

//serial full adder cell
FA K4 (.i_A(timer25k[0]), .i_B(timer25k_fa_cflag), .i_CIN((i_TIMER25K_CNT & ~i_ROT20_n[0])), .o_S(timer25k_fa_sum), .o_COUT(timer25k_fa_cout));

//previous carry bit storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        timer25k_fa_cflag <= timer25k_fa_cout & i_ROT20_n[19];
    end
end

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(timer25k_shift == 1'b1) begin
            timer25k[11] <= timer25k_fa_sum & i_TIMER25K_CNT;
            timer25k[10:0] <= timer25k[11:1];
        end
        else begin
            timer25k <= timer25k;
        end
    end
end



/*
    evaluation
*/

wire            const2555 = ~&{i_ROT20_n[11], i_ROT20_n[8], i_ROT20_n[7], i_ROT20_n[6], i_ROT20_n[5], i_ROT20_n[4], i_ROT20_n[3], i_ROT20_n[1], i_ROT20_n[0]};
reg             eq2555_flag_n = 1'b1;
reg             timeover_flag_n = 1'b1;

assign  o_TIMER25K_TIMEOVER_n = ~(~timeover_flag_n & ~i_ROT20_n[13]);

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq2555_flag_n <= ((timer25k_fa_sum ^ const2555) | eq2555_flag_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        timeover_flag_n <= (i_ROT20_n[12] == 1'b0) ? eq2555_flag_n : timeover_flag_n;
    end
end



/*
    counter register
*/

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_TIMER25K_OUTLATCH_LD_n == 1'b0) begin
            o_TIMERREG_LSBS <= timer25k;
        end
    end
end


endmodule