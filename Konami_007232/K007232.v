module K007232 (
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_PCEN, i_NCEN,

    input   wire            i_RST_n,

    input   wire            i_RCS_n, //sample RAM(optional) CS
    input   wire            i_DACS_n, //register CS

    input   wire            i_RD_n,
    input   wire    [3:0]   i_AB,
    input   wire    [7:0]   i_DB,
    output  wire    [7:0]   o_DB,
    output  wire            o_DB_OE,

    output  wire            o_SLEV_n, //volume latch wr
    output  wire            o_Q_n, //6809 synchronous bus
    output  wire            o_E_n,

    input   wire    [7:0]   i_RAM,
    output  wire    [7:0]   o_RAM,
    output  wire            o_RAM_OE,

    output  wire    [16:0]  o_SA, //sample ROM address
    output  reg     [6:0]   o_ASD,
    output  reg     [6:0]   o_BSD,
    
    output  wire            o_CK2M
);


/*
    A fully synchronous model for Konami 007232 dual-channel PCM player
    based on the Furrtek's die shot based schematics:

    github.com/furrtek/SiliconRE/tree/master/Konami/007232/schematics

    Sehyeon Kim(Raki) 2024
*/

/*
    REGISTER MAP

    Ch.1(A)
    reg0: Mode/Ch1 prescaler MSBs(--MMPPPP)
    reg1: Ch1 prescaler LSBs (PPPPPPPP)
    reg2: Ch1 counter MSBs (CCCCCCCC)
    reg3: Ch1 counter LSBs (CCCCCCCC)
    reg4: Trigger (wr)
    reg5: Ch1 counter MSB (XXXXXXXC)
    
    Ch.2(B)
    reg6: Mode/Ch2 prescaler MSBs(--MMPPPP)
    reg7: Ch2 prescaler LSBs (PPPPPPPP)
    reg8: Ch2 counter MSBs (CCCCCCCC)
    reg9: Ch2 counter LSBs (CCCCCCCC)
    regA: Trigger (wr)
    regB: Ch2 counter MSB (XXXXXXXC)

    Misc
    regC: Loop set (XXXXXXBA)
    regD: SLEV pin (AAAABBBB)
*/


///////////////////////////////////////////////////////////
//////  CLOCK AND RESET
////

wire            mclk = i_EMUCLK;
wire            mrst = ~i_RST_n;
wire            pcen = i_PCEN;
wire            ncen = i_NCEN;



///////////////////////////////////////////////////////////
//////  PRESCALERS
////

//div4 prescaler, ring counter
reg     [3:0]   div4_prescaler = 4'b0001;
always @(posedge mclk) begin
    if(mrst) div4_prescaler <= 4'b0001;
    else begin if(pcen) begin
        div4_prescaler[3:1] <= div4_prescaler[2:0];
        div4_prescaler[0] <= div4_prescaler[3];
    end end
end

//clocks
wire            clk_div2 = div4_prescaler[0] | div4_prescaler[2];
wire            clk_div2_pcen = (div4_prescaler[3] | div4_prescaler[1]) & pcen;
wire            clk_div2_ncen = (div4_prescaler[0] | div4_prescaler[2]) & pcen;

wire            clk_div4 = div4_prescaler[0] | div4_prescaler[1];
wire            clk_div4_pcen = div4_prescaler[3] & pcen;
wire            clk_div4_ncen = div4_prescaler[1] & pcen;

/*
    6809 /Q output negative edge handling:

    Create two sampling schemes for the Q output
    in case this core is used as a drop-in replacement.
*/
reg             nQ_ne, nQ_ncen;
always @(negedge mclk) nQ_ne <= clk_div2;
always @(posedge mclk) if(ncen) nQ_ncen <= clk_div2;
assign  o_Q_n = (pcen && ncen) ? nQ_ne : nQ_ncen;

//nE
assign  o_E_n = clk_div2;

//div256 prescaler, tff DOWN COUNTER
reg     [7:0]   div256_prescaler;
always @(posedge mclk) begin
    if(mrst) div256_prescaler <= 8'd1; //for convenience
    else begin if(clk_div4_pcen) begin
        div256_prescaler <= div256_prescaler == 8'd0 ? 8'd255 : div256_prescaler - 8'd1;
    end end
end

//div1024
wire            clk_div1024 = div256_prescaler[7];
wire            clk_div1024_ncen = div256_prescaler == 8'd128 & clk_div4_pcen;
wire            clk_div1024_pcen = div256_prescaler == 8'd0 & clk_div4_pcen;



///////////////////////////////////////////////////////////
//////  ADDRESS DECODER
////

wire            reg0_wr  = (i_AB == 4'd0) && !i_DACS_n; //Ch1 prescaler select/high byte(2/4)
wire            reg1_wr  = (i_AB == 4'd1) && !i_DACS_n; //Ch1 prescaler low byte(8)
wire            reg2_wr  = (i_AB == 4'd2) && !i_DACS_n; //Ch1 counter high byte(8)
wire            reg3_wr  = (i_AB == 4'd3) && !i_DACS_n; //Ch1 counter low byte(8)
wire            reg4_wr  = (i_AB == 4'd4) && !i_DACS_n; //Ch1 Trigger
wire            reg5_wr  = (i_AB == 4'd5) && !i_DACS_n; //Ch1 counter most significant bit(1)

wire            reg6_wr  = (i_AB == 4'd6) && !i_DACS_n;  //same as above
wire            reg7_wr  = (i_AB == 4'd7) && !i_DACS_n;  //|
wire            reg8_wr  = (i_AB == 4'd8) && !i_DACS_n;  //|
wire            reg9_wr  = (i_AB == 4'd9) && !i_DACS_n;  //|
wire            reg10_wr = (i_AB == 4'd10) && !i_DACS_n; //|
wire            reg11_wr = (i_AB == 4'd11) && !i_DACS_n; //|

wire            reg12_wr = (i_AB == 4'd12) && !i_DACS_n; //loop bits
assign          o_SLEV_n = !((i_AB == 4'd13) && !i_DACS_n); //external volume latch



///////////////////////////////////////////////////////////
//////  REGISTERS
////

//registers
reg     [5:0]   reg0, reg6;
reg     [7:0]   reg1, reg2, reg3, reg7, reg8, reg9;
reg             reg5, reg11;
reg     [1:0]   reg12;
always @(posedge mclk) begin
    if(reg0_wr) reg0 <= i_DB[5:0];
    if(reg1_wr) reg1 <= i_DB;
    if(reg2_wr) reg2 <= i_DB;
    if(reg3_wr) reg3 <= i_DB;
    if(reg5_wr) reg5 <= i_DB[0];

    if(reg6_wr) reg6 <= i_DB[5:0];
    if(reg7_wr) reg7 <= i_DB;
    if(reg8_wr) reg8 <= i_DB;
    if(reg9_wr) reg9 <= i_DB;
    if(reg11_wr) reg11 <= i_DB[0];

    if(reg12_wr) reg12 <= i_DB[1:0];
end



///////////////////////////////////////////////////////////
//////  CHANNEL 1
////

//prescaler dirty bit(reset the prescaler)
reg             ch1_pre_dirty;
always @(posedge mclk) begin
    if(reg0_wr || reg1_wr) ch1_pre_dirty <= 1'b1;
    else begin if(clk_div2) begin
        ch1_pre_dirty <= 1'b0;
    end end
end

//prescaler counter macros
wire    [3:0]   ch1_pre0_q, ch1_pre1_q, ch1_pre2_q;
wire    [11:0]  ch1_pre_q = {ch1_pre2_q, ch1_pre1_q, ch1_pre0_q};
wire            ch1_pre1_cnt = (ch1_pre0_q == 4'd15) & clk_div4; //M49
wire            ch1_pre2_cnt = reg0[5] ? clk_div4 : ch1_pre1_cnt & (ch1_pre1_q == 4'd15); //H97
wire            ch1_pre_co = reg0[4] ? ch1_pre1_cnt & (ch1_pre1_q == 4'd15) : ch1_pre2_cnt & (ch1_pre2_q == 4'd15); //J94 = J33 : J83
wire            ch1_pre_ld = ch1_pre_co | ch1_pre_dirty;

K007232_cntr #(.DW(4)) u_ch1pre0 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(mrst), .i_LD(ch1_pre_ld), .i_CNT(clk_div4), .i_D(reg1[3:0]), .o_Q(ch1_pre0_q)
);

K007232_cntr #(.DW(4)) u_ch1pre1 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(mrst), .i_LD(ch1_pre_ld), .i_CNT(ch1_pre1_cnt), .i_D(reg1[7:4]), .o_Q(ch1_pre1_q)
);

K007232_cntr #(.DW(4)) u_ch1pre2 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(mrst), .i_LD(ch1_pre_ld), .i_CNT(ch1_pre2_cnt), .i_D(reg0[3:0]), .o_Q(ch1_pre2_q)
);

//Ch1 counter trigger latch
wire            ch1_cntr_loop_en = reg12[0];
reg             ch1_cntr_autoctrl_en; //H71
reg             ch1_cntr_stbit; //T72
reg             ch1_cntr_rst; //R95, P95, L97 comb loop
wire            ch1_cntr_ld = ~ch1_cntr_autoctrl_en | (ch1_cntr_loop_en & ch1_cntr_stbit);
always @(posedge mclk) begin
    //H71
    if(mrst) ch1_cntr_autoctrl_en <= 1'b1;
    else begin
        if(reg4_wr) ch1_cntr_autoctrl_en <= 1'b0;
        else begin
            if(clk_div2_pcen) ch1_cntr_autoctrl_en <= 1'b1;
        end
    end

    //T72
    if(clk_div4_pcen) ch1_cntr_stbit <= i_RAM[7];

    //this block emulates the combinational loop synchronouly
    if(mrst) ch1_cntr_rst <= 1'b1;
    else begin
        if(reg4_wr) ch1_cntr_rst <= 1'b0;
        else begin
            if(clk_div4_pcen) if(!ch1_cntr_loop_en && i_RAM[7] && !ch1_cntr_rst) ch1_cntr_rst <= 1'b1;
        end
    end
end

//address counter macros
wire    [3:0]   ch1_cntr0_q, ch1_cntr1_q, ch1_cntr2_q;
wire    [4:0]   ch1_cntr3_q;
wire            ch1_cntr1_cnt = reg0[5] ? ch1_pre_co : (ch1_cntr0_q == 4'd15) & ch1_pre_co;
wire            ch1_cntr2_cnt = reg0[5] ? ch1_pre_co : (ch1_cntr1_q == 4'd15) & ch1_cntr1_cnt;
wire            ch1_cntr3_cnt = reg0[5] ? ch1_pre_co : (ch1_cntr2_q == 4'd15) & ch1_cntr2_cnt;
wire    [16:0]  ch1_rom_addr = {ch1_cntr3_q, ch1_cntr2_q, ch1_cntr1_q, ch1_cntr0_q};

K007232_cntr #(.DW(4)) u_ch1cntr0 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch1_cntr_rst), .i_LD(ch1_cntr_ld), .i_CNT(ch1_pre_co), .i_D(reg3[3:0]), .o_Q(ch1_cntr0_q)
);

K007232_cntr #(.DW(4)) u_ch1cntr1 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch1_cntr_rst), .i_LD(ch1_cntr_ld), .i_CNT(ch1_cntr1_cnt), .i_D(reg3[7:4]), .o_Q(ch1_cntr1_q)
);

K007232_cntr #(.DW(4)) u_ch1cntr2 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch1_cntr_rst), .i_LD(ch1_cntr_ld), .i_CNT(ch1_cntr2_cnt), .i_D(reg2[3:0]), .o_Q(ch1_cntr2_q)
);

K007232_cntr #(.DW(5)) u_ch1cntr3 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch1_cntr_rst), .i_LD(ch1_cntr_ld), .i_CNT(ch1_cntr3_cnt), .i_D({reg5, reg2[7:4]}), .o_Q(ch1_cntr3_q)
);



///////////////////////////////////////////////////////////
//////  CHANNEL 2
////

//prescaler dirty bit(reset the prescaler)
reg             ch2_pre_dirty;
always @(posedge mclk) begin
    if(reg6_wr || reg7_wr) ch2_pre_dirty <= 1'b1;
    else begin if(clk_div2) begin
        ch2_pre_dirty <= 1'b0;
    end end
end

//prescaler counter macros
wire    [3:0]   ch2_pre0_q, ch2_pre1_q, ch2_pre2_q;
wire    [11:0]  ch2_pre_q = {ch2_pre2_q, ch2_pre1_q, ch2_pre0_q};
wire            ch2_pre1_cnt = (ch2_pre0_q == 4'd15) & clk_div4;
wire            ch2_pre2_cnt = reg6[5] ? clk_div4 : ch2_pre1_cnt & (ch2_pre1_q == 4'd15);
wire            ch2_pre_co = reg6[4] ? ch2_pre1_cnt & (ch2_pre1_q == 4'd15) : ch2_pre2_cnt & (ch2_pre2_q == 4'd15);
wire            ch2_pre_ld = ch2_pre_co | ch2_pre_dirty;

K007232_cntr #(.DW(4)) u_ch2pre0 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(mrst), .i_LD(ch2_pre_ld), .i_CNT(clk_div4), .i_D(reg7[3:0]), .o_Q(ch2_pre0_q)
);

K007232_cntr #(.DW(4)) u_ch2pre1 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(mrst), .i_LD(ch2_pre_ld), .i_CNT(ch2_pre1_cnt), .i_D(reg7[7:4]), .o_Q(ch2_pre1_q)
);

K007232_cntr #(.DW(4)) u_ch2pre2 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(mrst), .i_LD(ch2_pre_ld), .i_CNT(ch2_pre2_cnt), .i_D(reg6[3:0]), .o_Q(ch2_pre2_q)
);

//Ch2 counter trigger latch
wire            ch2_cntr_loop_en = reg12[1];
reg             ch2_cntr_autoctrl_en;
reg             ch2_cntr_stbit;
reg             ch2_cntr_rst;
wire            ch2_cntr_ld = ~ch2_cntr_autoctrl_en | (ch2_cntr_loop_en & ch2_cntr_stbit);
always @(posedge mclk) begin
    if(mrst) ch2_cntr_autoctrl_en <= 1'b1;
    else begin
        if(reg10_wr) ch2_cntr_autoctrl_en <= 1'b0;
        else begin
            if(clk_div2_pcen) ch2_cntr_autoctrl_en <= 1'b1;
        end
    end

    if(clk_div4_ncen) ch2_cntr_stbit <= i_RAM[7];

    //this block emulates the combinational loop synchronouly
    if(mrst) ch2_cntr_rst <= 1'b1;
    else begin
        if(reg10_wr) ch2_cntr_rst <= 1'b0;
        else begin
            if(clk_div4_ncen) if(!ch2_cntr_loop_en && i_RAM[7] && !ch2_cntr_rst) ch2_cntr_rst <= 1'b1;
        end
    end
end

//address counter macros
wire    [3:0]   ch2_cntr0_q, ch2_cntr1_q, ch2_cntr2_q;
wire    [4:0]   ch2_cntr3_q;
wire            ch2_cntr1_cnt = reg6[5] ? ch2_pre_co : (ch2_cntr0_q == 4'd15) & ch2_pre_co;
wire            ch2_cntr2_cnt = reg6[5] ? ch2_pre_co : (ch2_cntr1_q == 4'd15) & ch2_cntr1_cnt;
wire            ch2_cntr3_cnt = reg6[5] ? ch2_pre_co : (ch2_cntr2_q == 4'd15) & ch2_cntr2_cnt;
wire    [16:0]  ch2_rom_addr = {ch2_cntr3_q, ch2_cntr2_q, ch2_cntr1_q, ch2_cntr0_q};

K007232_cntr #(.DW(4)) u_ch2cntr0 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch2_cntr_rst), .i_LD(ch2_cntr_ld), .i_CNT(ch2_pre_co), .i_D(reg9[3:0]), .o_Q(ch2_cntr0_q)
);

K007232_cntr #(.DW(4)) u_ch2cntr1 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch2_cntr_rst), .i_LD(ch2_cntr_ld), .i_CNT(ch2_cntr1_cnt), .i_D(reg9[7:4]), .o_Q(ch2_cntr1_q)
);

K007232_cntr #(.DW(4)) u_ch2cntr2 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch2_cntr_rst), .i_LD(ch2_cntr_ld), .i_CNT(ch2_cntr2_cnt), .i_D(reg8[3:0]), .o_Q(ch2_cntr2_q)
);

K007232_cntr #(.DW(5)) u_ch2cntr3 (
    .i_EMUCLK(mclk), .i_PCEN(clk_div2_pcen), .i_RST(ch2_cntr_rst), .i_LD(ch2_cntr_ld), .i_CNT(ch2_cntr3_cnt), .i_D({reg11, reg8[7:4]}), .o_Q(ch2_cntr3_q)
);



///////////////////////////////////////////////////////////
//////  SAMPLE ROM INTERFACE
////

assign  o_SA = clk_div4 ? ch2_rom_addr : ch1_rom_addr;
always @(posedge mclk) if(clk_div4_pcen) o_ASD <= i_RAM[6:0];
always @(posedge mclk) if(clk_div4_ncen) o_BSD <= i_RAM[6:0];

//for RAM?
assign  o_RAM = i_DB;
assign  o_DB = i_RAM;
assign  o_RAM_OE = ~(~i_RD_n | (clk_div2 | i_RCS_n));
assign  o_DB_OE = ~(i_RD_n | (clk_div2 | i_RCS_n));



///////////////////////////////////////////////////////////
//////  CLK2 GENERATOR
////

wire    [3:0]   ck2m_q;
wire            ck2m_ld = ck2m_q == 4'd15;
K007232_cntr #(.DW(4)) u_ck2m (
    .i_EMUCLK(mclk), .i_PCEN(reg0[4] ? clk_div4_pcen : clk_div1024_pcen), .i_RST(mrst), .i_LD(ck2m_ld), .i_CNT(1'b1), .i_D(4'd9), .o_Q(ck2m_q)
);        

assign  o_CK2M = reg0[5] ? clk_div1024 : ck2m_q == 4'd15;




endmodule



module K007232_cntr #(parameter DW = 4) (
    input   wire                i_EMUCLK, //emulator master clock
    input   wire                i_PCEN,

    input   wire                i_RST, i_LD, i_CNT,
    input   wire    [DW-1:0]    i_D,
    output  reg     [DW-1:0]    o_Q
);

always @(posedge i_EMUCLK) begin
    if(i_RST) o_Q <= {DW{1'b0}};
    else begin if(i_PCEN) begin
        if(i_LD) o_Q <= i_D;
        else begin
            if(i_CNT) o_Q <= &{o_Q} ? {DW{1'b0}} : o_Q + 1'b1;
        end
    end end
end

endmodule