module K005297_bubctrlfe
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //system flags
    input   wire            i_SYS_RST_n,
    input   wire            i_SYS_RUN_FLAG_SET_n,

    //control
    input   wire            i_ABSPGCNTR_CNT_START,
    input   wire            i_ABSPGCNTR_CNT_STOP,
    input   wire            i_VALPG_ACC_FLAG,
    input   wire            i_BMODE_n,

    input   wire            i_REP_START,
    input   wire            i_SWAP_START,

    output   wire           o_BOOTEN_n,
    output   wire           o_BSS_n,
    output   wire           o_BSEN_n,
    output   wire           o_REPEN_n,
    output   wire           o_SWAPEN_n
);


//Bubble Shift Start
SRNAND T6 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~(i_ABSPGCNTR_CNT_START & ~i_ROT20_n[17])), .i_R_n(i_SYS_RUN_FLAG_SET_n & i_SYS_RST_n), .o_Q(), .o_Q_n(o_BSS_n));

//Bubble Shift Enable
SRNAND H22 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~i_ABSPGCNTR_CNT_STOP & i_SYS_RST_n), .i_R_n(~(i_ABSPGCNTR_CNT_START & ~i_ROT20_n[1])), .o_Q(o_BSEN_n), .o_Q_n());

//Replicator Enable
reg             bootloop_rep_pulse = 1'b1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(o_BOOTEN_n | o_BSEN_n == 1'b1) begin //H25 NAND demorgan
            bootloop_rep_pulse <= 1'b1;
        end
        else begin
            if(i_ROT20_n[1] == 1'b0) begin
                bootloop_rep_pulse <= ~bootloop_rep_pulse;
            end
            else begin
                bootloop_rep_pulse <= bootloop_rep_pulse;
            end
        end
    end
end

wire            replicator_on = ~((~bootloop_rep_pulse | i_REP_START) & ~i_ROT20_n[2]);
SRNAND K24 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SYS_RST_n & i_ROT20_n[16]), .i_R_n(replicator_on), .o_Q(o_REPEN_n), .o_Q_n());

//Swap Gate Enable
SRNAND T15 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SYS_RST_n & i_ROT20_n[17]), .i_R_n(~((i_VALPG_ACC_FLAG & i_SWAP_START) & ~i_ROT20_n[3])), .o_Q(o_SWAPEN_n), .o_Q_n());

//Bootloop Enabe;
SRNAND C27 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SYS_RST_n), .i_R_n(~(i_BMODE_n & ~i_ROT20_n[0])), .o_Q(), .o_Q_n(o_BOOTEN_n));



endmodule