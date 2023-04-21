module K005297_z14eval
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //lock control
    input   wire            i_TIMER25K_TIMEOVER_n,
    input   wire            i_Z14_ERR_n,

    //lock flag related
    output  wire            o_Z14_UNLOCK_n,
    output  wire            o_Z14_LOCKED_n,

    //control
    input   wire            i_BDI_EN,

    input   wire            i_SUPBD_ACT_n,
    input   wire            i_SUPBD_END_n,

    input   wire            i_DLCNT_START_n,
    input   wire            i_SUPBDLCNTR_CNT,
    input   wire            i_ACQ_START,

    input   wire            i_MSKREG_SR_LSB,
    
    input   wire            i_BDI,
    input   wire            i_EFF_BDO,
    output  wire            o_MUXED_BDO,

    output  wire            o_TIMER25K_CNT,
    output  wire            o_TIMER25K_OUTLATCH_LD_n,

    //flags output
    output  wire            o_Z14_n,
    output  wire            o_Z11_d13_n,

    output  wire    [3:0]   o_TIMERREG_MSBS
);


reg             rot20_d18_dlyd1, rot20_d18_dlyd2;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        rot20_d18_dlyd1 <= ~i_ROT20_n[18];
        rot20_d18_dlyd2 <= rot20_d18_dlyd1;
    end
end


///////////////////////////////////////////////////////////
//////  Z14 FLAG EVALUATOR
////

//Actually, this is a CRC14 calculator

//Z14 lock flag bit
assign  o_Z14_UNLOCK_n = i_TIMER25K_TIMEOVER_n & o_Z11_d13_n;

//original implementation
assign  o_TIMER25K_OUTLATCH_LD_n = o_Z14_LOCKED_n | o_Z11_d13_n;

SRNAND I7 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_Z14_UNLOCK_n), .i_R_n(i_Z14_ERR_n), .o_Q(o_Z14_LOCKED_n), .o_Q_n(o_TIMER25K_CNT));


//SR14 control
wire            bdi_act, srctrl_en_n;
wire            srctrl_shift = (bdi_act == 1'b1) ? i_SUPBDLCNTR_CNT : rot20_d18_dlyd2; //J47 AO22

SRNAND J48 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_END_n), .i_R_n(i_DLCNT_START_n), .o_Q(), .o_Q_n(bdi_act));
SRNAND F47 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~(i_ACQ_START & ~i_ROT20_n[0]) & i_SYS_RST_n), .i_R_n(i_DLCNT_START_n), .o_Q(srctrl_en_n), .o_Q_n());


//SR14 data in
wire            output_data_n = ~((~i_BDI_EN & i_EFF_BDO) | i_BDI); //M35
wire            output_data_n_gated = ~(output_data_n | ~o_Z14_LOCKED_n); //M7
wire            sr14_msb;
wire            sr14_lsb = (sr14_msb ^ output_data_n_gated) & ~(~i_BDI_EN & ~i_SUPBD_ACT_n);


//SR14
reg     [3:0]   sr14_4;
reg             sr14_1;
reg     [8:0]   sr14_9;
wire    [13:0]  sr14 = {sr14_9, sr14_1, sr14_4};
                       //MSB                  //LSB <- INPUT
wire    [15:0]  __DEBUG_CRC12_VAL = {sr14, 2'b00};

assign  sr14_msb = sr14[13];
assign  o_Z11_d13_n = |{sr14[13:3]} | i_ROT20_n[13];
assign  o_Z14_n = |{sr14};
assign  o_TIMERREG_MSBS = sr14[13:10];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(srctrl_en_n == 1'b1) begin //reset
            sr14_4 <= 4'b0000;
            sr14_1 <= 1'b0;
            sr14_9 <= 9'b0_0000_0000;
        end
        else begin
            if(srctrl_shift == 1'b1) begin //shift
                //sr14_4
                sr14_4[0] <= sr14_lsb;
                sr14_4[3:1] <= sr14_4[2:0];

                //sr14_1
                sr14_1 <= sr14_4[3] ^ sr14_lsb;

                //sr14_9
                sr14_9[0] <= sr14_1 ^ sr14_lsb;
                sr14_9[8:1] <= sr14_9[7:0];
            end 
            else begin //hold
                sr14_4 <= sr14_4;
                sr14_1 <= sr14_1;
                sr14_9 <= sr14_9;
            end
        end
    end
end


//bubble data output
assign  o_MUXED_BDO = ((~i_BDI_EN & ~i_SUPBD_ACT_n) == 1'b0) ? output_data_n_gated & i_MSKREG_SR_LSB : sr14_msb & i_MSKREG_SR_LSB;



endmodule