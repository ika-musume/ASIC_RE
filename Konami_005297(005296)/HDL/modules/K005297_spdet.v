module K005297_spdet
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
    input   wire            i_BDI, //bubble input data stream
    input   wire            i_GLCNT_RD, //good loop count
    input   wire            i_BOOTEN_n, //bootloader enable(bubble cartridge)
    input   wire            i_BSEN_n, //bubble shift enable(bc)
    input   wire            i_4BEN_n,

    //output
    output  wire            o_SYNCTIP_n,
    output  wire            o_SYNCED_FLAG,
    output  wire            o_SYNCED_FLAG_SET_n
);




//zero bit counter: needs 128 zero bits + 1 "one" bit
reg     [7:0]   zerobit_cntr = 8'd255;
wire            zerobit_cntr_rst;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(zerobit_cntr_rst == 1'b1) begin
            zerobit_cntr <= 8'd255;
        end
        else begin
            if(i_GLCNT_RD == 1'b1) begin
                if(zerobit_cntr == 8'd0) begin //loop counter
                    zerobit_cntr <= 8'd255;
                end
                else begin
                    zerobit_cntr <= zerobit_cntr - 8'd1;
                end
            end
            else begin //hold
                zerobit_cntr <= zerobit_cntr;
            end
        end
    end
end


//invalid pattern: reset the counter if "one" comes in before a complete pattern is detected
reg             invalid_pattern = 1'b1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        invalid_pattern <= (i_GLCNT_RD == 1'b0) ? invalid_pattern : i_BDI; //0:1
    end
end


//zero bit counter reset and synced flag SR latch
wire            synced_flag;
assign  o_SYNCED_FLAG_SET_n = i_BOOTEN_n | o_SYNCTIP_n;

assign  zerobit_cntr_rst = i_BSEN_n | synced_flag | invalid_pattern; //resets zerobit counter
assign  o_SYNCED_FLAG = synced_flag;

SRNAND D60 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_SYNCED_FLAG_SET_n), .i_R_n(i_SYS_RST_n), .o_Q(synced_flag), .o_Q_n());


//sync tip
wire            synctip_en = (i_4BEN_n == 1'b0) ? ~i_ROT20_n[18] : ~i_ROT20_n[8]; //4bit mode : 2bit mode
wire            synctip_4b = ~&{synctip_en, i_BDI, ~zerobit_cntr[7]}; //D51 TFF
reg     [7:0]   synctip_2b_dlyd;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        synctip_2b_dlyd[7] <= synctip_4b;
        synctip_2b_dlyd[6:0] <= synctip_2b_dlyd[7:1];
    end
end

assign  o_SYNCTIP_n = (i_4BEN_n == 1'b0) ? synctip_4b : synctip_2b_dlyd[0]; //4bit mode : 2bit mode

endmodule