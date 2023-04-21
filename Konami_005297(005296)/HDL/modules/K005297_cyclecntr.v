module K005297_cyclecntr
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_CYCLECNTR_EN,
    output  wire            o_CYCLECNTR_LSB
);



///////////////////////////////////////////////////////////
//////  CYCLE COUNTER
////

/*
    +1 serial up counter
*/

//shift flag
wire            cyclecntr_shift; 
SRNAND Q67 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[10]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(cyclecntr_shift));


reg     [9:0]   cyclecntr = 10'd0; //cycle counter
wire            cyclecntr_fa_sum; //msb input
wire            cyclecntr_fa_cout; //FA carry out
reg             cyclecntr_fa_cflag = 1'b0; //FA carry storage
assign  o_CYCLECNTR_LSB = cyclecntr[0];

//serial full adder cell
FA K20 (.i_A(~i_ROT20_n[0]), .i_B(cyclecntr[0]), .i_CIN(cyclecntr_fa_cflag), .o_S(cyclecntr_fa_sum), .o_COUT(cyclecntr_fa_cout));

//previous carry bit storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        cyclecntr_fa_cflag <= cyclecntr_fa_cout & i_ROT20_n[19];
    end
end

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(cyclecntr_shift == 1'b1) begin
            cyclecntr[9] <= cyclecntr_fa_sum & i_CYCLECNTR_EN;
            cyclecntr[8:0] <= cyclecntr[9:1];
        end
        else begin
            cyclecntr <= cyclecntr;
        end
    end
end


endmodule