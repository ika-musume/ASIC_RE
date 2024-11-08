module K005297_accmodeflag
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
    input   wire            i_SYS_RUN_FLAG,

    //control
    input   wire            i_CMDREG_RST_n,
    input   wire            i_BDI_EN_SET_n,
    input   wire            i_SYNCED_FLAG_SET_n,

    //mode flag output
    output  wire            o_BMODE_n, //bootloader mode
    output  wire            o_UMODE_n, //user mode
    output  wire            o_ALD_nB_U, //addres latch data BOOTLOADER_n / USER
    output  wire            o_UMODE_SET_n
);


assign  o_UMODE_SET_n = i_CMDREG_RST_n | i_BDI_EN_SET_n;

SRNAND C21 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_UMODE_SET_n), .i_R_n(i_SYS_RST_n), .o_Q(o_BMODE_n), .o_Q_n());
SRNAND C54 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_UMODE_SET_n), .i_R_n(i_SYS_RUN_FLAG), .o_Q(), .o_Q_n(o_UMODE_n));
SRNAND C19 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_UMODE_SET_n & i_SYS_RUN_FLAG), .i_R_n(i_SYNCED_FLAG_SET_n), .o_Q(o_ALD_nB_U), .o_Q_n());


endmodule