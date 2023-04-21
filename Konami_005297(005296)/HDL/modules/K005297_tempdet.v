module K005297_tempdet
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //control
    input   wire            i_TEMPLO_n,
    input   wire            i_CLK2M_STOP_n,
    input   wire            i_CLK2M_STOP_DLYD_n,

    output  wire            o_TEMPDROP_SET_n,
    output  wire            o_HEATEN_n
);


//register for edge detection
reg             edgedet_0, edgedet_1;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        edgedet_0 <= i_CLK2M_STOP_n & i_TEMPLO_n;
        edgedet_1 <= i_CLK2M_STOP_DLYD_n;
    end
end

//TEMPDROP flag
assign          o_TEMPDROP_SET_n = ~(edgedet_0 & ~(i_CLK2M_STOP_n & i_TEMPLO_n)); //negative edge detection


wire            heaten_clr_n = ~(~edgedet_0 & (i_CLK2M_STOP_n & i_TEMPLO_n)) & i_CLK2M_STOP_n; //positive edge detection
wire            heaten_set_n = ~((~edgedet_1 & i_CLK2M_STOP_DLYD_n & ~i_TEMPLO_n) & heaten_clr_n);

//delay
reg     [1:0]   heaten_ctrl_n;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        heaten_ctrl_n[1] <= heaten_clr_n;
        heaten_ctrl_n[0] <= heaten_set_n;
    end
end

//HEATEN_n out
SRNAND C20 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(heaten_ctrl_n[1]), .i_R_n(heaten_ctrl_n[0]), .o_Q(o_HEATEN_n), .o_Q_n());


endmodule