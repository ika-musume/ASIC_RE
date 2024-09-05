`timescale 10ps/10ps
module K007232_tb;

//BUS IO wires
reg             EMUCLK = 1'b1;
reg             RST_n = 1'b1;
reg             CS_n = 1'b1;
reg             WR_n = 1'b1;
reg     [3:0]   ADDR = 4'd0;
reg     [7:0]   DIN = 8'hZZ;

//generate clock
always #1 EMUCLK = ~EMUCLK;

reg     [1:0]   clkdiv = 2'd0;
reg             phiMref = 1'b0;
wire            phiM_PCEN = clkdiv[1:0] == 2'd3;
wire            phiM_NCEN = clkdiv[1:0] == 2'd1;
always @(posedge EMUCLK) begin
    if(clkdiv == 2'd3) begin clkdiv <= 2'd0; phiMref <= 1'b1; end
    else clkdiv <= clkdiv + 2'd1;

    if(clkdiv[1:0] == 2'd1) phiMref <= 1'b0;
end


//async reset
initial begin
    #30   RST_n <= 1'b0;
    #1300 RST_n <= 1'b1;
end

wire    [16:0]  pcm_addr;
wire    [7:0]   pcm_q;

//main chip
K007232 u_dut (
    .i_EMUCLK(EMUCLK), .i_PCEN(phiM_PCEN), .i_NCEN(phiM_NCEN),
    .i_RST_n(RST_n),

    .i_RCS_n(1'b1), .i_DACS_n(CS_n),
    .i_RD_n(1'b1), .i_AB(ADDR), .i_DB(DIN),
    .o_DB(), .o_DB_OE(),

    .o_SLEV_n(), .o_Q_n(), .o_E_n(),

    .i_RAM(pcm_q), .o_RAM(), .o_RAM_OE(),

    .o_SA(pcm_addr), .o_ASD(), .o_BSD(),
    .o_CK2M()
);


K007232_SRAM #(.AW(17), .DW(8), .simhexfile("rom_10a.txt")) u_pcmrom (
    .i_MCLK                     (EMUCLK                     ),
    .i_ADDR                     (pcm_addr                   ),
    .i_DIN                      (                           ),
    .o_DOUT                     (pcm_q                      ),
    .i_WR                       (1'b0                       ),
    .i_RD                       (1'b1                       )
);



task automatic K007232_write (
    input       [3:0]   i_TARGET_ADDR,
    input       [7:0]   i_WRITE_DATA,
    ref logic           i_CLK,
    ref logic           o_CS_n,
    ref logic           o_WR_n,
    ref logic   [3:0]   o_ADDR,
    ref logic   [7:0]   o_DATA
); begin
    @(posedge i_CLK) o_ADDR = i_TARGET_ADDR;
    @(negedge i_CLK) o_CS_n = 1'b0;
    
    @(posedge i_CLK) o_DATA = i_WRITE_DATA;
    @(negedge i_CLK) o_WR_n = 1'b0;
    @(posedge i_CLK) ;
    @(negedge i_CLK) o_WR_n = 1'b1;
                     o_CS_n = 1'b1;
    @(posedge i_CLK) o_DATA = 8'hZZ;
end endtask

initial begin
    #1500;

    #10 K007232_write(4'hC, 8'h03, phiMref, CS_n, WR_n, ADDR, DIN); //set loop bit

    #10 K007232_write(4'h0, 8'h0F, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h1, 8'hEA, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h5, 8'h00, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h2, 8'h00, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h3, 8'h00, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h4, 8'hFF, phiMref, CS_n, WR_n, ADDR, DIN);

    #10 K007232_write(4'h6, 8'h0F, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h7, 8'hF1, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'hB, 8'h00, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h8, 8'h00, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'h9, 8'hF5, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'hA, 8'hFF, phiMref, CS_n, WR_n, ADDR, DIN);

    #274911 K007232_write(4'hC, 8'h00, phiMref, CS_n, WR_n, ADDR, DIN); //set loop bit
    #390000 K007232_write(4'h4, 8'hFF, phiMref, CS_n, WR_n, ADDR, DIN);
    #10 K007232_write(4'hA, 8'hFF, phiMref, CS_n, WR_n, ADDR, DIN);
end

endmodule


module K007232_SRAM #(parameter AW=10, parameter DW=8, parameter simhexfile="") (
    input   wire            i_MCLK,
    
    input   wire   [AW-1:0] i_ADDR,
    input   wire   [DW-1:0] i_DIN,
    output  reg    [DW-1:0] o_DOUT,
    input   wire            i_RD,
    input   wire            i_WR
);

reg     [DW-1:0]   RAM [0:(2**AW)-1];
always @(posedge i_MCLK) begin
    if(i_WR) RAM[i_ADDR] <= i_DIN;
    else begin
        if(i_RD) o_DOUT <= RAM[i_ADDR];
    end
end

integer i;
initial begin
    if( simhexfile != "" ) begin
        $readmemh(simhexfile, RAM);
    end
    else begin
        for(i=0; i<2**AW; i=i+1) RAM[i] = {DW{1'b0}};
    end
end

endmodule