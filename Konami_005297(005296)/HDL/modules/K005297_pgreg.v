module K005297_pgreg
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

    //control
    input   wire            i_PGREG_LD, //async
    input   wire            i_PGREG_SR_LD_EN,
    output  wire            o_PGREG_SR_SHIFT,
    
    //data
    input   wire    [15:0]  i_DIN,

    output  wire            o_PGREG_D2,
    output  wire            o_PGREG_D8,
    output  wire            o_PGREG_SR_LSB
);



///////////////////////////////////////////////////////////
//////  PAGE REGISTER
////

/*
//Pseudo D latch * 12
wire    [11:0]  pgreg_q;
DL #(.dw(12)) PGREG (.i_CLK(MCLK), .i_CEN_n(CLK4P_n), .i_EN(i_PGREG_LD), .i_D(i_DIN[11:0]), .o_Q(pgreg_q), .o_Q_n());
*/

//True D latch primitive
reg     [11:0]  pgreg_q;
always @(i_PGREG_LD) begin
    if(i_PGREG_LD == 1'b1) begin
        pgreg_q <= i_DIN[11:0];
    end
    else begin
        pgreg_q <= pgreg_q;
    end
end

assign          o_PGREG_D2 = pgreg_q[2];
assign          o_PGREG_D8 = pgreg_q[8];

//shift flag
SRNAND N28 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(o_PGREG_SR_SHIFT));


//page shift register
reg     [11:0]  pgsr = 12'h000;
assign          o_PGREG_SR_LSB = pgsr[0];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        case({(i_PGREG_SR_LD_EN & ~i_ROT20_n[19]), o_PGREG_SR_SHIFT})
            2'b00: pgsr <= pgsr; //hold
            2'b01: begin pgsr[10:0] <= pgsr[11:1]; pgsr[11] <= o_PGREG_SR_LSB & i_SYS_RST_n; end //shift
            2'b10: pgsr <= pgreg_q; //load                                              TEST//
            2'b11: pgsr <= pgsr; //hold(invalid)
        endcase
    end
end


endmodule