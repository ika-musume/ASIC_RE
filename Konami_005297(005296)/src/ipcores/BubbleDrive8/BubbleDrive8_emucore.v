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

module BubbleDrive8_emucore
(
    //48MHz input clock
    input   wire            MCLK,

    //module enable
    input   wire            nEN,

    //DIP switch
    input   wire    [3:0]   IMGSEL,
    input   wire            ROMSEL,

    //4bit width mode
    input   wire            BITWIDTH4,

    //BOUT timing select
    input   wire            TIMINGSEL,

    //4MHz output clock
    output  wire            CLKOUT,

    //Bubble control signal inputs
    input   wire            nBSS,
    input   wire            nBSEN,
    input   wire            nREPEN,
    input   wire            nBOOTEN,
    input   wire            nSWAPEN,

    //Bubble data outputs
    output  wire            DOUT0,
    output  wire            DOUT1,
    output  wire            DOUT2,
    output  wire            DOUT3,

    //Configuration flash: W25Q80, W25Q64
    output  wire            CONFIGROM_nCS,
    output  wire            CONFIGROM_CLK,
    output  wire            CONFIGROM_MOSI,
    input   wire            CONFIGROM_MISO,

    //User flash
    output  wire            USERROM_FLASH_nCS,
    output  wire            USERROM_FRAM_nCS,
    output  wire            USERROM_CLK,
    output  wire            USERROM_MOSI,
    input   wire            USERROM_MISO,
    
    //FIFO buffer
    output  wire            nFIFOBUFWRCLKEN,
    output  wire    [12:0]  FIFOBUFWRADDR,
    output  wire            FIFOBUFWRDATA,
    output  wire            nFIFOSENDBOOT,
    output  wire            nFIFOSENDUSER,
    output  wire    [11:0]  FIFORELPAGE,
    
    //BUBBLE ACC LED
    output  wire            nACC
);

//TimingGenerator
wire    [2:0]   ACCTYPE;
wire    [12:0]  BOUTCYCLENUM;
wire    [11:0]  ABSPAGE;
wire            nBINCLKEN;
wire            nBOUTCLKEN;

//SPILoader -> BubbleInterface
wire            nOUTBUFWRCLKEN;
wire    [14:0]  OUTBUFWRADDR;
wire            OUTBUFWRDATA;

assign nACC = ~ACCTYPE[2];


TimingGenerator TimingGenerator_0
(
    .MCLK           (MCLK               ),

    .nEN            (nEN                ),
    .TIMINGSEL      (TIMINGSEL          ),

    .CLKOUT         (CLKOUT             ),
    .nBSS           (nBSS               ),
    .nBSEN          (nBSEN              ),
    .nREPEN         (nREPEN             ),
    .nBOOTEN        (nBOOTEN            ),
    .nSWAPEN        (nSWAPEN            ),

    .ACCTYPE        (ACCTYPE            ),
    .BOUTCYCLENUM   (BOUTCYCLENUM       ),
    .nBINCLKEN      (nBINCLKEN          ),
    .nBOUTCLKEN     (nBOUTCLKEN         ),

    .ABSPAGE        (ABSPAGE            )
);



BubbleBuffer BubbleBuffer_0
(
    .MCLK           (MCLK               ),

    .BITWIDTH4      (BITWIDTH4          ),

    .ACCTYPE        (ACCTYPE            ),
    .BOUTCYCLENUM   (BOUTCYCLENUM       ),
    .nBINCLKEN      (nBINCLKEN          ),
    .nBOUTCLKEN     (nBOUTCLKEN         ),

    .nOUTBUFWRCLKEN (nOUTBUFWRCLKEN     ),
    .OUTBUFWRADDR   (OUTBUFWRADDR       ),
    .OUTBUFWRDATA   (OUTBUFWRDATA       ),

    .DOUT0          (DOUT0              ),
    .DOUT1          (DOUT1              ),
    .DOUT2          (DOUT2              ),
    .DOUT3          (DOUT3              )
);



SPIDriver SPIDriver_0
(
    .MCLK           (MCLK               ),

    .IMGSEL         (IMGSEL             ),
    .ROMSEL         (ROMSEL             ),

    .BITWIDTH4      (BITWIDTH4          ),

    .ACCTYPE        (ACCTYPE            ),
    .ABSPAGE        (ABSPAGE            ),
    .RELPAGE        (FIFORELPAGE        ),

    .nOUTBUFWRCLKEN (nOUTBUFWRCLKEN     ),
    .OUTBUFWRADDR   (OUTBUFWRADDR       ),
    .OUTBUFWRDATA   (OUTBUFWRDATA       ),

    .CONFIGROM_nCS  (CONFIGROM_nCS      ),
    .CONFIGROM_CLK  (CONFIGROM_CLK      ),
    .CONFIGROM_MOSI (CONFIGROM_MOSI     ),
    .CONFIGROM_MISO (CONFIGROM_MISO     ),

    .USERROM_FLASH_nCS  (USERROM_FLASH_nCS  ),
    .USERROM_FRAM_nCS   (USERROM_FRAM_nCS   ),
    .USERROM_CLK    (USERROM_CLK        ),
    .USERROM_MOSI   (USERROM_MOSI       ),
    .USERROM_MISO   (USERROM_MISO       ),

    .nFIFOBUFWRCLKEN(nFIFOBUFWRCLKEN    ),
    .FIFOBUFWRADDR  (FIFOBUFWRADDR      ),
    .FIFOBUFWRDATA  (FIFOBUFWRDATA      ),
    .nFIFOSENDBOOT  (nFIFOSENDBOOT      ),
    .nFIFOSENDUSER  (nFIFOSENDUSER      )
);


endmodule