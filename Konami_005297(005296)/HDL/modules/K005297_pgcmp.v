module K005297_pgcmp
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_BDI_EN, //bubble input data enable
    input   wire            i_PGREG_SR_LSB, //page number shift register's lsb
    input   wire            i_ABSPGCNTR_LSB, //absolute page counter's lsb
    input   wire            i_UMODE_n, //user mode flag

    //output
    output  wire            o_PGCMP_EQ
);


///////////////////////////////////////////////////////////
//////  RELPAGE ABSPAGE CONVERTER
////

/*
    use carry of relpg-1299 as a gte flag(>= 1299)
    relative page 0-1298: carry of relpg-1299(unsigned relpg+2979) is 0, use relpg+754 as the abspg
    relative page 1299-4095: carry of relpage-1299 is 1, use relpg-1299 as the abspg

    relpg 1296 -> 1296-1299 C=0 -> 1296+754 = 2050(abspg)
    relpg 1298 -> 1298-1299 C=0 -> 1298+754 = 2052(abspg)

    relpg 1299 -> 1299-1299 C=1 -> 1299-1299 = 0(abspg)
    relpg 1300 -> 1300-1299 C=1 -> 1230-1299 = 1(abspg)

    relpg 2052 -> 2052-1299 C=1 -> 2052-1299 = 753(abspg)
    relpg 2053(invalid) -> 2053-1299 C=1 -> 2053-1299 = 754(abspg)
*/


//sub1299
wire            const2797 = ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[7], i_ROT20_n[6],
                               i_ROT20_n[5], i_ROT20_n[3], i_ROT20_n[2], i_ROT20_n[0]}; //12'b1010_1110_1101 = unsigned 2797/signed -1299
wire            sub1299_cout, sub1299_sum;
reg             sub1299_cflag = 1'b0;
reg             gte1299_flag = 1'b0;

FA O28 (.i_A(i_PGREG_SR_LSB), .i_B(const2797), .i_CIN(sub1299_cflag), .o_S(sub1299_sum), .o_COUT(sub1299_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        sub1299_cflag <= sub1299_cout & i_ROT20_n[19];
    end
end

//gte flag: greater than or equal to 1299
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        gte1299_flag <= (i_ROT20_n[12] == 1'b0) ?  sub1299_cflag : gte1299_flag; //store bit 11's carry
    end
end


//add754
wire            const754 = ~&{i_ROT20_n[9], i_ROT20_n[7], i_ROT20_n[6],
                               i_ROT20_n[5], i_ROT20_n[4], i_ROT20_n[1]}; //12'b0010_1111_0010 = 754
wire            add754_cout, add754_sum;
reg             add754_cflag = 1'b0;

FA O29 (.i_A(const754), .i_B(add754_cflag), .i_CIN(i_PGREG_SR_LSB), .o_S(add754_sum), .o_COUT(add754_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        add754_cflag <= add754_cout & i_ROT20_n[19];
    end
end



///////////////////////////////////////////////////////////
//////  COMPARATOR
////

wire            target_abspg =  (i_BDI_EN == 1'b0) ? i_PGREG_SR_LSB :
                                                     (gte1299_flag == 1'b0) ? add754_sum : sub1299_sum;
wire            abspg_comparator = target_abspg ^ i_ABSPGCNTR_LSB; //goes high if different bit exists(XOR)



///////////////////////////////////////////////////////////
//////  FLAG BIT
////

reg             delay0_n, pgcmp_eq_n;
assign  o_PGCMP_EQ = ~pgcmp_eq_n;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        delay0_n <= (delay0_n | abspg_comparator) & i_ROT20_n[19];

        pgcmp_eq_n <= (i_UMODE_n == 1'b1) ? 1'b1 :
                                           (i_ROT20_n[12] == 1'b0) ? delay0_n : pgcmp_eq_n;
    end
end


endmodule