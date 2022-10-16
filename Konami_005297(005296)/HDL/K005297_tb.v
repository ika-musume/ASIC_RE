/*
    Copyright (C) 2022 Sehyeon Kim(Raki)
    
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

`timescale 10ps/10ps
module K005297_tb;

reg             MCLK = 1'b0; //48MHz
wire            CLK4M;
reg             MRST = 1'b0;



///////////////////////////////////////////////////////////
//////  DMA BUS SWITCH
////

//dma port
wire            BMC_BR_n, CPU_BG_n, BMC_BGACK_n;


//Memory bus
wire    [22:0]  AOUT_BUS; //address output
reg     [15:0]  DIN_BUS; //read from memory
wire    [15:0]  DOUT_BUS; //write to memory
wire            R_nW, UDS_n, LDS_n, AS_n; //bus control


//When the BMC acts as a bus master:
wire    [15:0]  BMC_DIN_BUS;
wire    [15:0]  BMC_DOUT_BUS;

wire    [6:0]   BMC_AIN_BUS = AOUT_BUS[6:0];
wire    [22:0]  BMC_AOUT_BUS;

wire            BMC_R_nW, BMC_UDS_n, BMC_LDS_n, BMC_AS_n;
wire    [2:0]   BMC_FC;


//When the CPU acts as a bus master:
wire    [15:0]  CPU_DIN_BUS = DIN_BUS;
reg     [15:0]  CPU_DOUT_BUS;

reg     [23:0]  cpu_aout_intl;
wire    [22:0]  CPU_AOUT_BUS = cpu_aout_intl[23:1];

reg             CPU_R_nW, CPU_UDS_n, CPU_LDS_n, CPU_AS_n;
reg     [2:0]   CPU_FC = 3'b110;





//BMC data in bus
assign          BMC_DIN_BUS = (BMC_BGACK_n == 1'b0) ? DIN_BUS : DOUT_BUS; //read from memory(DMA) : register write

//DMA address output bus
assign          AOUT_BUS    = (BMC_BGACK_n == 1'b0) ? BMC_AOUT_BUS : CPU_AOUT_BUS;

//DMA data output bus(write to memory)
assign          DOUT_BUS    = (BMC_BGACK_n == 1'b0) ? BMC_DOUT_BUS : CPU_DOUT_BUS;

//bus control
assign          R_nW        = (BMC_BGACK_n == 1'b0) ? BMC_R_nW : CPU_R_nW;
assign          UDS_n       = (BMC_BGACK_n == 1'b0) ? BMC_UDS_n : CPU_UDS_n;
assign          LDS_n       = (BMC_BGACK_n == 1'b0) ? BMC_LDS_n : CPU_LDS_n;
assign          AS_n        = (BMC_BGACK_n == 1'b0) ? BMC_AS_n : CPU_AS_n;








///////////////////////////////////////////////////////////
//////  K005297 packer
////

//bubbledrive8
reg             TEMPLO_n = 1'b0;
wire            BOOTEN_n, BSS_n, BSEN_n, REPEN_n, SWAPEN_n;
wire            DOUT1, DOUT0;
wire            USERROM_FLASH_nCS, USERROM_CLK, USERROM_MISO, USERROM_MOSI;  

//BMC CS
wire            BMC_CS_n = (AOUT_BUS[22:15] == 8'h04 && AS_n == 1'b0) ? 1'b0 : 1'b1;

//address latch
wire            BMC_ALE;
reg     [15:0]  bmc_address_latch = 16'h0000;
assign          BMC_AOUT_BUS[22:7] = bmc_address_latch;
always @(*) begin
    if(BMC_ALE) begin
        bmc_address_latch <= BMC_DOUT_BUS;
    end
end


K005297 main
(
    .i_MCLK                     (CLK4M                  ),

    .i_CLK4M_PCEN_n             (1'b0                   ),
                         
    .i_MRST_n                   (MRST                   ),
                         
    .i_REGCS_n                  (BMC_CS_n               ),
    .i_DIN                      (BMC_DIN_BUS            ), //write to BMC/BMC DMA read
    .i_AIN                      (BMC_AIN_BUS            ), //write to BMC
    .i_R_nW                     (R_nW                   ),
    .i_UDS_n                    (UDS_n                  ),
    .i_LDS_n                    (LDS_n                  ),
    .i_AS_n                     (AS_n                   ),
                         
    .o_DOUT                     (BMC_DOUT_BUS           ),
    .o_AOUT                     (BMC_AOUT_BUS[6:0]      ),
    .o_R_nW                     (BMC_R_nW               ),
    .o_UDS_n                    (BMC_UDS_n              ),
    .o_LDS_n                    (BMC_LDS_n              ),
    .o_AS_n                     (BMC_AS_n               ),
    .o_ALE                      (BMC_ALE                ),
                         
    .o_BR_n                     (BMC_BR_n               ),
    .i_BG_n                     (1'b0                   ),
    .o_BGACK_n                  (BMC_BGACK_n            ),
                         
    .o_CPURST_n                 (                       ),
    .o_IRQ_n                    (                       ),
                         
    .o_FCOUT                    (                       ),
    .i_FCIN                     (CPU_FC                 ),
                         
    .o_BDOUT_n                  (                       ),
    .i_BDIN_n                   ({DOUT1, DOUT0, 2'b11}  ),
    .o_BOOTEN_n                 (BOOTEN_n               ),
    .o_BSS_n                    (BSS_n                  ),
    .o_BSEN_n                   (BSEN_n                 ),
    .o_REPEN_n                  (REPEN_n                ),
    .o_SWAPEN_n                 (SWAPEN_n               ),
    .i_TEMPLO_n                 (TEMPLO_n               ),
    .o_HEATEN_n                 (                       ),
    .i_4BEN_n                   (1'b1                   ),
                         
    .o_INT1_ACK_n               (                       ),
    .i_TST1                     (1'b1                   ),
    .i_TST2                     (1'b0                   ),
    .i_TST3                     (1'b1                   ),
    .i_TST4                     (1'b0                   ),
    .i_TST5                     (1'b1                   ),
                         
    .o_CTRL_DMAIO_OE_n          (CTRL_DMAIO_OE_n        ),
    .o_CTRL_DATA_OE_n           (CTRL_DATA_OE_n         )
);

BubbleDrive8_emucore BubbleDrive8_emucore_0 (
    .MCLK                       (MCLK                   ),
    .nEN                        (1'b0                   ),
    .IMGSEL                     (4'b0000                ),
    .ROMSEL                     (1'b0                   ),
    .BITWIDTH4                  (1'b0                   ),
    .TIMINGSEL                  (1'b0                   ),

    .CLKOUT                     (CLK4M                  ),
    .nBSS                       (BSS_n                  ),
    .nBSEN                      (BSEN_n                 ),
    .nREPEN                     (REPEN_n                ),
    .nBOOTEN                    (BOOTEN_n               ),
    .nSWAPEN                    (SWAPEN_n               ),

    .DOUT0                      (DOUT0                  ),
    .DOUT1                      (DOUT1                  ),
    .DOUT2                      (DOUT2                  ),
    .DOUT3                      (DOUT3                  ),

    .CONFIGROM_nCS              (                       ),
    .CONFIGROM_CLK              (                       ),
    .CONFIGROM_MOSI             (                       ),
    .CONFIGROM_MISO             (                       ),

    .USERROM_FLASH_nCS          (USERROM_FLASH_nCS      ),
    .USERROM_FRAM_nCS           (                       ),
    .USERROM_CLK                (USERROM_CLK            ),
    .USERROM_MOSI               (USERROM_MISO           ),
    .USERROM_MISO               (USERROM_MOSI           ),

    .nFIFOBUFWRCLKEN            (                       ),
    .FIFOBUFWRADDR              (                       ),
    .FIFOBUFWRDATA              (                       ),
    .nFIFOSENDBOOT              (                       ),
    .nFIFOSENDUSER              (                       ),
    .FIFORELPAGE                (                       ),

    .nACC                       (                       )
);

wire            USERROM_nWP;        assign USERROM_nWP = 1'b1;
wire            USERROM_nHOLD;      assign USERROM_nHOLD = 1'b1;
wire            USERROM_nRESET;     assign USERROM_nRESET = 1'b1;

W25Q32JVxxIM SPIFlash_USER
(
    .CSn                        (USERROM_FLASH_nCS      ),
    .CLK                        (USERROM_CLK            ),
    .DO                         (USERROM_MOSI           ),
    .DIO                        (USERROM_MISO           ),
    
    .WPn                        (USERROM_nWP            ),
    .HOLDn                      (USERROM_nHOLD          ),
    .RESETn                     (USERROM_nRESET         )
);



///////////////////////////////////////////////////////////
//////  CPU BUS
////

//initialize
initial begin
    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1;
end

reg [63:0] RD001 = 64'd4200898243;
initial begin //read 0x000
    #(RD001);

    //initialize STFLAG
    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    //read 0x40002
    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    //read 0x40006
    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0006; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0006; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0006; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0006; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0006; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0006; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0006; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT
end

reg [63:0] WR801 = 64'd6794431468;
initial begin //write 0x801
    #(WR801);

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0801; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0801; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0801; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0801; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0801; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0002; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0002; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0002; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0002; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0002; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT
end

reg [63:0] RD181 = 64'd8464176773;
initial begin //read 0x181
    #(RD181);

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    //read 0x40002
    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0181; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0181; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0181; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0181; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0181; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT
end


reg [63:0] RD182 = 64'd10556036693;
initial begin //read 0x182
    #(RD182);

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    //read 0x40002
    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0182; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0182; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0182; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0182; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0182; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT
end

reg [63:0] RD000 = 64'd11325190860;
initial begin //read 0x000
    #(RD000);

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0004; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    //read 0x40002
    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT

    #0    cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S0
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S1
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S2
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b0; //S3
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S4
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S5
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b0; CPU_LDS_n = 1'b0; CPU_AS_n = 1'b0; //S6
    #5425 cpu_aout_intl = 23'h04_0002; CPU_DOUT_BUS = 16'h0001; CPU_R_nW = 1'b0; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //S7
    #5425 cpu_aout_intl = 23'h00_0000; CPU_DOUT_BUS = 16'h0000; CPU_R_nW = 1'b1; CPU_UDS_n = 1'b1; CPU_LDS_n = 1'b1; CPU_AS_n = 1'b1; //INIT
end



///////////////////////////////////////////////////////////
//////  SHARED RAM
////

wire            SHAREDRAM_CS_n = (AOUT_BUS[22:15] == 8'h00 && AS_n == 1'b0) ? 1'b0 : 1'b1;
wire            SHAREDRAM_RD_n = SHAREDRAM_CS_n | UDS_n | ~R_nW;
wire            SHAREDRAM_WR_n = SHAREDRAM_CS_n | UDS_n | R_nW;

reg     [15:0]  sharedram [0:2047];
wire    [11:0]  sharedram_addr = AOUT_BUS[11:0];
reg     [15:0]  sharedram_outlatch;

always @(*) begin
    if(!SHAREDRAM_WR_n) begin
        sharedram[sharedram_addr] <= DOUT_BUS;
    end
end

always @(*) begin
    if(!SHAREDRAM_RD_n) begin
        sharedram_outlatch <= sharedram[sharedram_addr];
    end
end


initial
begin
    $readmemh("sharedram.txt", sharedram);
end




///////////////////////////////////////////////////////////
//////  DATA READ MUX
////

wire    [1:0]   dinmux_sel = {BMC_CS_n, SHAREDRAM_CS_n};

always @(*) begin
    case(dinmux_sel)
        2'b01: DIN_BUS <= BMC_DOUT_BUS;
        2'b10: DIN_BUS <= sharedram_outlatch;
        default: DIN_BUS <= 16'hFFFF; //pull-up
    endcase
end



always #1042 MCLK = ~MCLK;
always #3800 MRST <= 1'b1;

initial begin
    #7000 TEMPLO_n <= 1'b1;
    #12000 TEMPLO_n <= 1'b0;
    #30000 TEMPLO_n <= 1'b1;
end

endmodule