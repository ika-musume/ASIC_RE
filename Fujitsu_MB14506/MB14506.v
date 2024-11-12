module MB14506 (
    input   wire            i_EMUCLK,       //master clock(original chip uses the negedge)
    input   wire            i_CLK12M_PCEN,  //12MHz clock positive edge
    input   wire            i_CLK12M_NCEN,  //12MHz clock negative edge
    input   wire            i_RST_n,

    //bubble memory access control
    input   wire            i_BSS_n,        //bubble shift start
    input   wire            i_BSEN_n,       //bubble shift enable
    input   wire            i_REPEN_n,      //replicator enable
    input   wire            i_SWAPEN_n,     //swap gate enable

    //misc
    input   wire            i_WRDATA_n,     //1-bit width mode write data
    input   wire            i_BMCHALT,      //BMC clock stop

    //BMC clock
    output  wire            o_BMCCLK,       //bubble memory controller clock
    output  wire            o_BMCCLK_PCEN,  //BMC clock positive edge enable
    output  wire            o_BMCCLK_NCEN,  //BMC clock negative edge enable

    //MB3908 sense amplifier control
    output  reg             o_CLAMP_n,      //MB3908 sense amp clamp signal
    output  reg             o_STROBE,       //MB3908 sense amp data strobe signal

    //MB3910 function driver control
    output  wire            o_REP_n,        //MB3910 replicator enable
    output  wire            o_CUT_n,        //MB3910 bubble cut signal(double the replicator current)
    output  wire            o_SWAP_n,       //MB3910 swap gate enable
    output  wire            o_GEN_n,        //MB3910 generator enable

    //MB466 coil driver control
    output  wire    [3:0]   o_COIL_n        //MB466 coil driver enable, {+X, -X, +Y, -Y}
);



///////////////////////////////////////////////////////////
//////  Clock enables
////

wire            ncen = i_CLK12M_NCEN;
wire            pcen = i_CLK12M_PCEN;



///////////////////////////////////////////////////////////
//////  BMC clock generator
////

reg     [1:0]   bmcclk_sr;
reg             bmcclk_sr_z;
assign  o_BMCCLK = bmcclk_sr[0] & bmcclk_sr_z;
always @(posedge i_EMUCLK) begin
    if(!i_RST_n) bmcclk_sr <= 2'b00;
    else begin
        if(i_BMCHALT) bmcclk_sr <= 2'b00;
        else begin if(ncen) begin
            bmcclk_sr[0] <= bmcclk_sr[1];
            bmcclk_sr[1] <= ~&{bmcclk_sr};
        end end
    end

    if(pcen) bmcclk_sr_z <= bmcclk_sr[0];
end

reg     [5:0]   bmcclk_cen_sr;
assign  o_BMCCLK_NCEN = bmcclk_cen_sr[2] & ncen;
assign  o_BMCCLK_PCEN = bmcclk_cen_sr[5] & pcen;
always @(posedge i_EMUCLK) if(ncen || pcen) begin
    if(!i_RST_n) bmcclk_cen_sr <= 6'b000000;
    else begin
        bmcclk_cen_sr[0] <= ({bmcclk_sr[0], bmcclk_sr_z} == 2'b10);
        bmcclk_cen_sr[5:1] <= bmcclk_cen_sr[4:0];
    end
end



///////////////////////////////////////////////////////////
//////  Cycle counter
////

/*
    0, 1
    2, 3
    4, 5...
    116, 117
    118, 127
    0, 1...
*/

reg             cyccntr_cnt;
reg     [5:0]   cyccntr;
wire    [6:0]   mcyc = {cyccntr, cyccntr_cnt}; 

always @(posedge i_EMUCLK) begin
    if(pcen) begin
        if(!i_BSS_n) cyccntr_cnt <= 1'b1;
    end
    else begin if(ncen) begin
        cyccntr_cnt <= ~cyccntr_cnt;
    end end

    if(pcen) begin
        if(!i_BSS_n) cyccntr <= 6'd63;
    end
    else begin if(ncen) begin
        if(cyccntr == 6'd59 && !cyccntr_cnt) cyccntr <= 6'd63;
        else begin
            if(cyccntr_cnt) cyccntr <= cyccntr == 6'd63 ? 6'd0 : cyccntr + 6'd1;
        end
    end end
end



///////////////////////////////////////////////////////////
//////  MB3908 sense amplifier timings
////

always @(posedge i_EMUCLK) begin
    if(!i_RST_n) begin
        o_CLAMP_n <= 1'b1;
        o_STROBE <= 1'b0;
    end
    else begin if(pcen) begin
        if(!i_BSS_n) o_CLAMP_n <= 1'b1;
        else begin
                 if(mcyc == 7'd70)                      o_CLAMP_n <= 1'b0;
            else if(mcyc >= 7'd108 && mcyc <= 7'd111)   o_CLAMP_n <= 1'b1;
        end

        if(!i_BSS_n) o_STROBE <= 1'b0;
        else begin
                 if(mcyc >= 7'd92 && mcyc <= 7'd95)     o_STROBE <= 1'b1;
            else if(mcyc >= 7'd108 && mcyc <= 7'd111)   o_STROBE <= 1'b0;
        end
    end end
end



///////////////////////////////////////////////////////////
//////  MB3910 function driver timings
////

reg             swap_n, gen_n, rep_n, cut_n;
assign  o_SWAP_n = i_RST_n ? swap_n : 1'b1;
assign  o_GEN_n  = i_RST_n ? gen_n : 1'b1;
assign  o_REP_n  = i_RST_n ? rep_n : 1'b1;
assign  o_CUT_n  = i_RST_n ? cut_n : 1'b1;

always @(posedge i_EMUCLK) begin
    //swap gate
    if(!i_RST_n) swap_n <= 1'b1;
    else begin if(pcen) begin
        if(mcyc == 7'd72)                           swap_n <= ~(o_SWAP_n & ~i_SWAPEN_n);
    end end

    //generator enable
    if(!i_RST_n) gen_n <= 1'b1;
    else begin if(pcen) begin
             if(mcyc == 7'd30 || mcyc == 7'd31)     gen_n <= i_WRDATA_n;
        else if(mcyc == 7'd33)                      gen_n <= 1'b1;
    end end

    //replicator
    if(!i_RST_n) rep_n <= 1'b1;
    else begin if(pcen) begin
             if(mcyc == 7'd33)                      rep_n <= i_REPEN_n;
        else if(mcyc == 7'd69)                      rep_n <= 1'b1;
    end end

    //bubble cut
    if(!i_RST_n) cut_n <= 1'b1;
    else begin if(pcen) begin
             if(!rep_n && mcyc == 7'd35)            cut_n <= 1'b0;
        else if(mcyc == 7'd38 || mcyc == 7'd39)     cut_n <= 1'b1;
    end end
end



///////////////////////////////////////////////////////////
//////  MB466 coil driver timings
////

reg             nY; //270 degree
reg             pY; //90  degree
reg             nX; //180 degree
reg             pX; //0   degree

always @(posedge i_EMUCLK) if(pcen) begin
    //-Y enable
    if(!i_BSS_n) nY <= 1'b0;
    else begin
             if(mcyc >= 7'd60 && mcyc <= 7'd63)     nY <= 1'b1;
        else if(mcyc == 7'd94)                      nY <= 1'b0;
    end
    
    //+Y enable
         if(mcyc >= 7'd0 && mcyc <= 7'd31)          pY <= 1'b1;
    else if(mcyc == 7'd34 || mcyc == 7'd35)         pY <= 1'b0;

    //-X enable
    if(!i_BSS_n) nX <= 1'b0;
    else begin
             if(mcyc >= 7'd32 && mcyc <= 7'd47)     nX <= 1'b1;
        else if(mcyc == 7'd63)                      nX <= 1'b0;
    end

    //+X enable
         if(mcyc == 7'd87)                          pX <= 1'b1;
    else if(mcyc >= 7'd4 && mcyc <= 7'd7)           pX <= 1'b0;
end

reg             BSEN_z, BSEN_zz, BSEN_zzz;

always @(posedge i_EMUCLK) begin
    if(!i_RST_n) begin
        BSEN_z   <= 1'b0;
        BSEN_zz  <= 1'b0;
        BSEN_zzz <= 1'b0;
    end
    else begin if(pcen) begin
        if(mcyc == 7'd20) BSEN_z   <= ~i_BSEN_n;
        if(mcyc == 7'd34) BSEN_zz  <= BSEN_z;
        if(mcyc == 7'd63) BSEN_zzz <= BSEN_zz;
    end end
end

assign  o_COIL_n[0] = i_RST_n ? ~(nY & BSEN_zz) : 1'b1;
assign  o_COIL_n[1] = i_RST_n ? ~(pY & BSEN_zz) : 1'b1;
assign  o_COIL_n[2] = i_RST_n ? ~(nX & (BSEN_z | BSEN_zzz)) : 1'b1;
assign  o_COIL_n[3] = i_RST_n ? ~(pX & (BSEN_z | BSEN_zzz)) : 1'b1;



endmodule