module K005292 (
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK6MPCEN_n,

    input   wire            i_MRST_n,

    input   wire            i_HFLIP,
    input   wire            i_VFLIP,
    input   wire            i_H288, //set horizontal pixel as 288
    input   wire            i_INTER, //interlaced

    output  reg             o_HBLANK_n,
    output  wire            o_VBLANK_n,
    output  wire            o_VBLANKH_n,

    output  wire    [8:0]   o_ABS_H,
    output  wire    [7:0]   o_ABS_V,
    output  wire    [7:0]   o_FLIP_H,
    output  wire    [7:0]   o_FLIP_V,

    output  reg             o_VCLK,

    output  wire            o_FRAMEPARITY,

    output  reg             o_HSYNC_n,
    output  wire            o_VSYNC_n,
    output  reg             o_CSYNC_n,

    input   wire    [4:0]   i_TEST, //PIN24 23 22 21 20

    output  wire    [8:0]   o_DEBUG_HCNTR,
    output  wire    [8:0]   o_DEBUG_VCNTR
);



///////////////////////////////////////////////////////////
//////  CLOCK AND RESET
////

wire            mrst = ~i_MRST_n;
wire            mclk = i_EMU_MCLK;
wire            clk6m_pcen = ~i_EMU_CLK6MPCEN_n;



///////////////////////////////////////////////////////////
//////  GLOBAL SIGNALS
////

reg     [8:0]   hcntr, vcntr;
reg             vclk_pcen;

assign  o_ABS_H = hcntr;
assign  o_FLIP_H = i_HFLIP ? ~hcntr[7:0] : hcntr[7:0];
assign  o_ABS_V = vcntr[7:0];
assign  o_FLIP_V = i_VFLIP ? ~vcntr[7:0] : vcntr[7:0];
assign  o_DEBUG_HCNTR = hcntr;
assign  o_DEBUG_VCNTR = vcntr;


///////////////////////////////////////////////////////////
//////  HORIZONTAL COUNTER
////

always @(posedge mclk) begin
    if(mrst) hcntr <= 9'd0;
    else begin if(clk6m_pcen) begin
        hcntr <= hcntr == 9'd511 ? 9'd128 : hcntr + 9'd1;
    end end
end



///////////////////////////////////////////////////////////
//////  VIDEO TIMINGS
////

//VERTICAL VIDEO TIMINGS
reg             dff_D8, dff_D19, dff_C28;
wire            dff_D19_pcen = vclk_pcen & (vcntr[4:0] == 5'd15) & ~(vcntr[7:5] == 3'b111) & (dff_D19 == 1'b0);
wire            dff_C28_pcen = vclk_pcen & (vcntr[4:0] == 5'd15) & (dff_D19 == 1'b0 && vcntr[7:5] != 3'b111) & (dff_C28 == 1'b0);
always @(posedge mclk) begin
    //D8
    if(mrst) dff_D8 <= 1'b0;
    else begin if(vclk_pcen) begin
        if(vcntr[0] == 1'b0) dff_D8 <= ~vcntr[8];
    end end

    //D19
    if(mrst) dff_D19 <= 1'b0;
    else begin if(vclk_pcen) begin
        if(vcntr[4:0] == 5'd15) dff_D19 <= ~(vcntr[7:5] == 3'b111);
    end end

    if(mrst) dff_C28 <= 1'b0;
    else begin if(vclk_pcen) begin
        if(vcntr[4:0] == 5'd15) if(dff_D19 == 1'b1 && vcntr[7:5] == 3'b111) dff_C28 <= ~dff_C28;
    end end
end

assign  o_VBLANK_n = dff_D19;
assign  o_VSYNC_n = vcntr[8];
assign  o_VBLANKH_n = (~vcntr[8] & ~dff_D8) | dff_D19;
assign  o_FRAMEPARITY = dff_C28; //256V


//MODE0 VCLK/SYNC
reg             vclk_mode0;
wire            vclk_mode0_pcen = (hcntr[8] == 1'b0 && hcntr[6:0] == 7'd47) & clk6m_pcen;
always @(posedge mclk) begin
    if(mrst) begin
        vclk_mode0 <= 1'b1;
    end
    else begin if(clk6m_pcen) begin
        if(hcntr == 9'd255 || hcntr[8]) vclk_mode0 <= 1'b0;
        else begin
            if(hcntr[3:0] == 4'd15) begin
                vclk_mode0 <= ~hcntr[6] & hcntr[5];
            end
        end
    end end
end

wire            sync_mode0_n = ~vclk_mode0 & (vcntr[8] | ~i_TEST[4]);


//MODE2/3 VCLK/SYNC
reg             vclk_mode23;
wire            vclk_mode23_pcen = (hcntr[4:0] == 5'd31 && vclk_mode0) & clk6m_pcen;
always @(posedge mclk) begin
    if(mrst) begin
        vclk_mode23 <= 1'b0;
    end
    else begin if(clk6m_pcen) begin
        if(hcntr[4:0] == 5'd31) vclk_mode23 <= vclk_mode0;
    end end
end

reg             dff_D41;
wire            hblank_mode23_n = dff_D41 | hcntr[8];
always @(posedge mclk) begin
    if(mrst) begin
        dff_D41 <= 1'b0;
    end
    else begin if(clk6m_pcen) begin
        if(hcntr[5:0] == 6'd31) dff_D41 <= hcntr[8];
    end end
end

wire            sync_mode23_n = ~vclk_mode23 & (vcntr[8] | ~i_TEST[4]);


//MODE1 VCLK/SYNC
reg             dff_C2, dff_A44, dff_B43, dff_C14, dff_C8, dff_C8_censel;
wire            dff_B43_ncen = (hcntr[5:0] == 6'd47 && (hcntr[8:6] == 3'b101 || hcntr[8:6] == 3'b010)) & clk6m_pcen;
wire            debug_dff_C8_clk = ~dff_C14 && vcntr[7:0] == 8'b11110111 && i_TEST[4] && vclk_mode0;
wire            debug_dff_C8_clk_pcen = ~dff_C14 && vcntr[7:0] == 8'b11110111 && i_TEST[4] && vclk_mode0_pcen;
wire            debug_something_long = (hcntr[8:6] == 3'b101 || hcntr[8:6] == 3'b010);
always @(posedge mclk) begin
    //B43
    if(clk6m_pcen) begin
        if(hcntr[5:0] == 6'd63 || ~hcntr[5]) dff_B43 <= 1'b1;
        else begin
            if(hcntr[4:0] == 5'd15) dff_B43 <= ~(hcntr[8:6] == 3'b101 || hcntr[8:6] == 3'b010);
        end
    end

    //C14
    if(mrst) dff_C14 <= 1'b1;
    else begin
        if(clk6m_pcen) begin
            if(dff_D19_pcen || dff_D19) dff_C14 <= 1'b0;
            else begin if(vclk_pcen) begin
                if(vcntr[3:0] == 4'd7) dff_C14 <= ~dff_C14;
            end end
        end
    end

    //C8
    if(mrst) dff_C8 <= 1'b0;
    else begin
        if(clk6m_pcen) begin
            if(dff_C28_pcen || dff_C28) dff_C8 <= 1'b1;
            else begin
                if(vcntr[7:0] == 8'd247 && !dff_C14 && i_TEST[4] && vclk_mode0_pcen) dff_C8 <= ~dff_C8;
            end
        end
    end

    //C8_pre: NOT an original signal
    if(mrst) dff_C8_censel <= 1'b0;
    else begin if(clk6m_pcen) begin
        if(hcntr == 9'd511 && vcntr == 9'd502) dff_C8_censel <= 1'b0;
        else if(hcntr == 9'd511 && vcntr == 9'd271) dff_C8_censel <= 1'b1;
    end end

    //C2
    if(mrst) dff_C2 <= 1'b0;
    else begin
        if(clk6m_pcen) begin
            if(dff_D19_pcen || dff_D19) dff_C2 <= 1'b1;
            else begin if(vclk_pcen) begin
                if(vcntr[2:0] == 3'd7) dff_C2 <= ~dff_C2;
            end end
        end
    end

    //A44
    if(clk6m_pcen) begin
        if(!((hcntr == 9'd191 || hcntr[8:6] == 3'b010 || hcntr == 9'd383 || hcntr[8:6] == 3'b101) && !i_TEST[2])) dff_A44 <= 1'b0;
        else begin
            if(hcntr[4:0] == 5'd15) dff_A44 <= ~dff_A44;
        end
    end
end

reg             vclk_mode1, vclk_mode1_pcen;
always @(*) begin
    case(i_TEST[3:2])
        2'b00: vclk_mode1 = dff_C8 ? vclk_mode0 : (~dff_B43 & hcntr[8]);
        2'b01: vclk_mode1 = (~dff_B43 & hcntr[8]);
        2'b10: vclk_mode1 = (vclk_mode0 & dff_C8);
        2'b11: vclk_mode1 = 1'b0;
    endcase

    case(i_TEST[3:2])
        2'b00: vclk_mode1_pcen = dff_C8_censel ? vclk_mode0_pcen : (dff_B43_ncen & hcntr[8]);
        2'b01: vclk_mode1_pcen = (dff_B43_ncen & hcntr[8]);
        2'b10: vclk_mode1_pcen = (vclk_mode0_pcen & dff_C8_censel);
        2'b11: vclk_mode1_pcen = 1'b0;
    endcase
end

wire            gate_A12 = (~i_TEST[0] & dff_C2) | (i_TEST[3] | dff_B43) | (~i_TEST[0] & ~dff_C14);
wire            gate_A29 = dff_A44 | (vcntr[8] | ~i_TEST[4]);
wire            gate_B21 = dff_C14 | (~vclk_mode0 | i_TEST[3]);
wire            sync_mode1_n = gate_A12 & gate_A29 & gate_B21;



///////////////////////////////////////////////////////////
//////  TIMING MUX
////

always @(*) begin
    case({i_H288, i_INTER})
        2'b00: o_VCLK = vclk_mode0;
        2'b01: o_VCLK = vclk_mode1;
        2'b10: o_VCLK = vclk_mode23;
        2'b11: o_VCLK = vclk_mode23;
    endcase

    case({i_H288, i_INTER})
        2'b00: vclk_pcen = vclk_mode0_pcen;
        2'b01: vclk_pcen = vclk_mode1_pcen;
        2'b10: vclk_pcen = vclk_mode23_pcen;
        2'b11: vclk_pcen = vclk_mode23_pcen;
    endcase

    o_HBLANK_n = i_H288 ? hblank_mode23_n : hcntr[8];

    case({i_H288, i_INTER})
        2'b00: o_CSYNC_n = sync_mode0_n;
        2'b01: o_CSYNC_n = sync_mode1_n;
        2'b10: o_CSYNC_n = sync_mode23_n;
        2'b11: o_CSYNC_n = sync_mode23_n;
    endcase

    //for emulation
    case({i_H288, i_INTER})
        2'b00: o_HSYNC_n = ~vclk_mode0;
        2'b01: o_HSYNC_n = gate_B21 & gate_A12 & ~(dff_A44 & ~vcntr[8]);
        2'b10: o_HSYNC_n = ~vclk_mode23;
        2'b11: o_HSYNC_n = ~vclk_mode23;
    endcase
end



///////////////////////////////////////////////////////////
//////  VERTICAL COUNTER
////

//async
//always @(posedge (vclk & i_TEST[1]) or posedge mrst) begin
//    if(mrst) vcntr <= 9'd0;
//    else begin
//        vcntr <= vcntr == 9'd511 ? 9'd248 : vcntr + 9'd1;
//    end
//end

//sync
always @(posedge mclk) begin
    if(mrst) vcntr <= 9'd0;
    else begin if(vclk_pcen) begin
        if(i_TEST[1]) vcntr <= vcntr == 9'd511 ? 9'd248 : vcntr + 9'd1;
    end end
end

endmodule