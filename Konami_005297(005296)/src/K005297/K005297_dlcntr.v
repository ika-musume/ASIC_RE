module K005297_dlcntr
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_DLCNT_START_n, //data length count start
    input   wire            i_SUPBD_START_n, //data length count end
    input   wire            i_DLCNT_EN, //data length + 1

    output  wire            o_DLCNTR_LSB, //data length counter lsb
    output  wire            o_DLCNTR_CFLAG //carry of data length's msb
);



///////////////////////////////////////////////////////////
//////  DATA LENGTH COUNTER
////

/*
    +1 serial up counter
*/

//reset flag(load 0)
wire            dlcntr_rst_n; 
SRNAND I46 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_START_n), .i_R_n(i_DLCNT_START_n), .o_Q(), .o_Q_n(dlcntr_rst_n));

//shift flag
wire            dlcntr_shift; 
SRNAND J67 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[10]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(dlcntr_shift));


reg     [9:0]   dlcntr = 10'd0; //data length counter
wire            dlcntr_fa_sum; //msb input
wire            dlcntr_fa_cout; //FA carry out
reg             dlcntr_fa_cflag = 1'b0; //FA carry storage
assign          o_DLCNTR_LSB = dlcntr[0];
assign          o_DLCNTR_CFLAG = dlcntr_fa_cflag;

//serial full adder cell
FA I61 (.i_A(dlcntr[0]), .i_B(dlcntr_fa_cflag), .i_CIN(i_DLCNT_EN), .o_S(dlcntr_fa_sum), .o_COUT(dlcntr_fa_cout));

//previous carry bit storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        dlcntr_fa_cflag <= dlcntr_fa_cout & i_ROT20_n[19];
    end
end

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(dlcntr_shift == 1'b1) begin
            dlcntr[9] <= dlcntr_fa_sum & dlcntr_rst_n;
            dlcntr[8:0] <= dlcntr[9:1];
        end
        else begin
            dlcntr <= dlcntr;
        end
    end
end


endmodule