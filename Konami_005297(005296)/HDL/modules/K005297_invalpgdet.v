module K005297_invalpgdet
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_TST, //test pin(normally 1)
    input   wire            i_PGREG_SR_LSB, //page number shift register's lsb
    input   wire            i_INVALPG_LSB, //invalid page reference point
    input   wire            i_UMODE_n,
    input   wire            i_PGCMP_EQ,

    //output
    output  wire            o_ACC_INVAL_n,
    output  wire            o_VALPG_FLAG_SET_n
);


///////////////////////////////////////////////////////////
////// INVALID PAGE DETECTOR
////

//invalid page
reg             invalid_page = 1'b0;
reg             access_invalid_n = 1'b1;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        //TST3 = 1: eq 0
        //TST3 = 0: gte INVALPG
        invalid_page <= ~(~(((i_TST | i_INVALPG_LSB) & i_PGREG_SR_LSB) | ((i_TST | i_INVALPG_LSB | i_PGREG_SR_LSB) & invalid_page)) | ~i_ROT20_n[19]);

        access_invalid_n <= (i_ROT20_n[12] == 1'b0) ? (invalid_page & ~i_UMODE_n) : (access_invalid_n & ~i_UMODE_n);
    end
end

assign  o_ACC_INVAL_n = access_invalid_n & i_PGCMP_EQ;
assign  o_VALPG_FLAG_SET_n = ~(o_ACC_INVAL_n & ~i_ROT20_n[14]);


endmodule