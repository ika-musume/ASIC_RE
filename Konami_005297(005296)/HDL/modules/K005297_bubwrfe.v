module K005297_bubwrfe
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_TST, //TST5
    input   wire            i_4BEN_n,

    input   wire            i_MUXED_BDO,
    input   wire            i_MUXED_BDO_EN,
    input   wire            i_SUPBD_END_n,

    output  wire    [3:0]   o_BDOUT_n,

    //test mode
    input   wire            i_ABSPGCNTR_LSB,
    input   wire            i_PGREG_SR_LSB,
    input   wire            i_DLCNTR_LSB,
    input   wire            i_CYCLECNTR_LSB
);


//output enable
wire            bubble_output_en;
SRNAND K22 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_END_n), .i_R_n(~(i_MUXED_BDO_EN & ~i_ROT20_n[17])), .o_Q(), .o_Q_n(bubble_output_en));

//bubble shift register
reg     [3:0]   bubble_sr;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) == 1'b1) begin //3-8_13-18
            bubble_sr[0] <= i_MUXED_BDO;
            bubble_sr[3:1] <= bubble_sr[2:0];
        end
        else begin
            bubble_sr <= bubble_sr;
        end
    end
end

//bubble outlatch
reg     [3:0]   bubble_outlatch;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[0] == 1'b0) begin //d-latch latches SR data at ROT20_n[1]
            if(i_4BEN_n == 1'b1) begin //2bit mode
                bubble_outlatch <= {bubble_sr[3:2], 2'b00};
            end
            else begin //4bit mode
                bubble_outlatch <= bubble_sr;
            end
        end
    end
end

//output mux
assign  o_BDOUT_n = (i_TST == 1'b1) ? ~(bubble_outlatch & {4{bubble_output_en}}) :
                                      {i_CYCLECNTR_LSB, i_DLCNTR_LSB, i_PGREG_SR_LSB, i_ABSPGCNTR_LSB};


endmodule