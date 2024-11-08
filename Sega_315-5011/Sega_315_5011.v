module Sega_315_5011 (
    input   wire            i_MCLK,
    input   wire            i_CLK5MNCEN, //5M on schematics, the actual chip inverts the clock internally

    input   wire    [7:0]   i_V,

    input   wire    [15:0]  i_RO_DI,
    output  wire    [15:0]  o_RO_DO,
    output  wire            o_RO_DO_OE,

    input   wire            i_CWEN,
    input   wire            i_VCUL_n,
    input   wire            i_DELTAX_n,
    input   wire            i_ALULO_n,
    input   wire            i_ONTRF,

    output  wire            o_VEN_n,
    output  wire            o_SWAP
);


///////////////////////////////////////////////////////////
//////  Sprite line comparator and index counter
////

wire    [7:0]   lomux, himux;
wire    [8:0]   loadder, hiadder;
reg     [7:0]   locntr, hicntr;
assign  o_RO_DO = {hicntr, locntr};

//MUX
assign  lomux = i_DELTAX_n ? (i_VCUL_n ? locntr : ~i_V) : 8'h00;
assign  himux = i_DELTAX_n ? (i_VCUL_n ? hicntr : ~i_V) : 8'h00;

//adders
assign  loadder = lomux + i_RO_DI[7:0];
assign  hiadder = himux + i_RO_DI[15:8] + loadder[8];
wire    [15:0]  adder = {hiadder[7:0], loadder[7:0]};

//counters
always @(posedge i_MCLK) if(i_CLK5MNCEN) begin
    if(!i_ALULO_n) {hicntr, locntr} <= adder;
    else begin
        if(i_CWEN) begin
            if(~hicntr[7]) begin
                {hicntr, locntr} <= {hicntr, locntr} + 16'd1; //count up
            end
            else begin
                {hicntr, locntr} <= {hicntr, locntr} - 16'd1; //count down
            end
        end
    end
end

//misc
assign  o_RO_DO_OE = i_ONTRF;
assign  o_SWAP = hicntr[7] ^ ~i_CWEN;
assign  o_VEN_n = ~(hiadder[8] & ~loadder[8] & ~i_VCUL_n);

endmodule