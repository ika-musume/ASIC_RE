module K005297_sumcmp
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //data in
    input   wire            i_EFF_MUXED_BDI,

    //control
    input   wire            i_UMODE_n,
    input   wire            i_BDO_EN_n,
    input   wire            i_EFFBDO_EN,
    input   wire            i_GLCNT_RD,
    input   wire            i_PGREG_SR_SHIFT,
    input   wire            i_DMADREG_BDLD_EN,

    input   wire            i_MUXED_BDO_EN_DLYD,
    input   wire            i_SUPBD_ACT_n,
    input   wire            i_ALD_nB_U,

    //output
    output  wire            o_INVALPG_LSB,
    output  reg             o_SUMEQ_n
);




//
//  VARIABLE
//

//variable shift register
reg     [11:0]  sr_var = 12'h000;
wire            sr_var_shift = (i_EFFBDO_EN & i_GLCNT_RD) | (i_BDO_EN_n & i_PGREG_SR_SHIFT);

//sr_var serial FA
wire            sr_var_fa_sum, sr_var_fa_cout; //FA carry out
reg             sr_var_fa_cflag = 1'b0; //FA carry storage

//msb/lsb
wire            sr_var_msb = sr_var_fa_sum & i_MUXED_BDO_EN_DLYD;
wire            sr_var_lsb = (i_UMODE_n == 1'b1) ? sr_var[0] : sr_var[4]; //bootloader:user page


//Full adder
FA N48 (.i_A(i_EFF_MUXED_BDI), .i_B(sr_var_fa_cflag), .i_CIN(sr_var_lsb), .o_S(sr_var_fa_sum), .o_COUT(sr_var_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        sr_var_fa_cflag <= (sr_var_shift == 1'b1) ? (sr_var_fa_cout & ~i_DMADREG_BDLD_EN) : (sr_var_fa_cflag & ~i_DMADREG_BDLD_EN); //update:hold
    end
end


//sr
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr_var_shift == 1'b1) begin
            sr_var[11] <= sr_var_msb;
            sr_var[10:0] <= sr_var[11:1];
        end
        else begin
            sr_var <= sr_var;
        end
    end
end



//
//  CONSTANT
//

//constant shift register
reg     [11:0]  sr_const = 12'h000;
wire            sr_const_shift;

//msb in
wire            sr_const_msb = (&{i_MUXED_BDO_EN_DLYD, i_PGREG_SR_SHIFT, ~i_SUPBD_ACT_n, ~i_ALD_nB_U} == 1'b1) ? sr_var_lsb : sr_const[0]; //load : hold
wire            sr_const_lsb = sr_const[0];
assign          o_INVALPG_LSB = sr_const_lsb;

//shift
SRNAND O35 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(sr_const_shift));


//sr
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr_const_shift == 1'b1) begin
            sr_const[11] <= sr_const_msb;
            sr_const[10:0] <= sr_const[11:1];
        end
        else begin
            sr_const <= sr_const;
        end
    end
end



//
//  COMPARATOR
//

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        o_SUMEQ_n <= ((sr_var_lsb ^ sr_const_lsb) | o_SUMEQ_n) & i_ROT20_n[19];
    end
end




endmodule