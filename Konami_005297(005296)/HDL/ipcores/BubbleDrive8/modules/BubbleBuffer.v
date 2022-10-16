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

module BubbleBuffer
/*
    BubbleDrive8_emucore > modules > BubbleBuffer.v

    Copyright (C) 2020-2022, Raki

    BubbleInterface acts as a buffer. This buffer has 8k*1bit space per
    one bubble memory. So, a 2Mbit module can take two of them, and a 4Mb,
    unreleased, undeveloped, never-seen one takes four.
    This buffer can hold both bootloader(2053*2) and user pages(584). SPI 
    Loader writes the bootloader and a requested page on here. One important 
    thing is that this buffer also has the synchronization pattern and empty
    propagation line.
    64 of LOGIC LOW + 1 of LOGIC HIGH + extra 1 of DON'T CARE synchronization
    pattern bits are loaded on the D0 buffer during the FPGA configuration 
    session. BUBBLE VALID CYCLE COUNTER automatically sweeps the address bus 
    of the buffer, so entire bootloop read can be accomplished without 
    unnatural behavior or exceptional asynchronous code that forces to make
    the pattern.
    Timing Generator makes Clock Enable pulses(active low) to launch a bubble
    bit.

    * For my convenience, many comments are written in Korean *
*/

(
    //48MHz input clock
    input   wire            MCLK,

    //4bit width mode
    input   wire            BITWIDTH4,

    //Emulator signal outputs
    input   wire    [2:0]   ACCTYPE,        //access type
    input   wire    [12:0]  BOUTCYCLENUM,   //bubble output cycle number
    input   wire            nBINCLKEN,
    input   wire            nBOUTCLKEN,     //bubble output asynchronous control ticks

    //Bubble out buffer interface
    input   wire            nOUTBUFWRCLKEN,    //bubble outbuffer write clk
    input   wire    [14:0]  OUTBUFWRADDR,      //bubble outbuffer write address
    input   wire            OUTBUFWRDATA,      //bubble outbuffer write data

    //Bubble data out
    output  wire            DOUT0,
    output  wire            DOUT1,
    output  wire            DOUT2,
    output  wire            DOUT3
);



/*
    OUTBUFFER READ ADDRESS DECODER
*/

/*
    Block RAM Buffer Address [DOUT1/DOUT0]
    1bit 0 + 13bit address + 1bit CS
    0000-1327 : bootloader data 1328*2 bits
    1328-1911 : 584*2 bad loop table
    1912-1926 : 14*2 or 15*2 bits of CRC(??) data, at least 28 bits
    1927-4038 : 11 = filler
    4039-4103 : X0 = 65 of ZEROs on EVEN channel (or possibly 64?)
    4104      : X1 = 1 of ONE on EVEN channel
    4105      : XX = DON'T CARE
    4106-7167 : 00 = empty space
    7168-7170 : 00 = 3 position shifted page data
    7171-7751 : 581bits remaining page data

    8191      : 00 = empty bubble propagation line
*/

localparam BOOT = 3'b110;   //C
localparam USER = 3'b111;   //D

reg     [12:0]  outbuffer_read_address = 13'b1_1111_1111_1111;

always @(*)
begin
    case (ACCTYPE)
        BOOT:
        begin
            outbuffer_read_address <= BOUTCYCLENUM;
        end
        USER:
        begin
            outbuffer_read_address <= {3'b111, BOUTCYCLENUM[9:0]};
        end
        default:
        begin
            outbuffer_read_address <= 13'b1_1111_1111_1111;
        end
    endcase
end



/*
    OUTBUFFER WRITE ADDRESS DECODER
*/

wire    [3:0]   outbuffer_write_enable;
reg     [3:0]   outbuffer_we_decoder = 4'b1111; //D3 D2 DOUT1 DOUT0
assign          outbuffer_write_enable = outbuffer_we_decoder | {4{~ACCTYPE[1]}};
reg     [12:0]  outbuffer_write_address;

always @(*)
begin
    case(BITWIDTH4)
        1'b0: //2BITMODE
        begin
            case(OUTBUFWRADDR[0])
                1'b0:
                begin
                    outbuffer_write_address <= OUTBUFWRADDR[13:1];
                    outbuffer_we_decoder <= 4'b1101;
                end
                1'b1:
                begin
                    outbuffer_write_address <= OUTBUFWRADDR[13:1];
                    outbuffer_we_decoder <= 4'b1110;
                end
            endcase
        end
        1'b1: //4BITMODE: no game released
        begin
            case(OUTBUFWRADDR[1:0])
                2'b00:
                begin
                    outbuffer_write_address <= OUTBUFWRADDR[14:2];
                    outbuffer_we_decoder <= 4'b0111;
                end
                2'b01:
                begin
                    outbuffer_write_address <= OUTBUFWRADDR[14:2];
                    outbuffer_we_decoder <= 4'b1011;
                end
                2'b10:
                begin
                    outbuffer_write_address <= OUTBUFWRADDR[14:2];
                    outbuffer_we_decoder <= 4'b1101;
                end
                2'b11:
                begin
                    outbuffer_write_address <= OUTBUFWRADDR[14:2];
                    outbuffer_we_decoder <= 4'b1110;
                end
            endcase
        end
    endcase
end



/*
    OUTBUFFER
*/

//DOUT0
reg             D0_outbuffer[8191:0];
reg             D0_outbuffer_read_data;
assign          DOUT0 = ~D0_outbuffer_read_data;

always @(posedge MCLK)
begin
    if(nOUTBUFWRCLKEN == 1'b0)
    begin
       if (outbuffer_write_enable[0] == 1'b0)
       begin
           D0_outbuffer[outbuffer_write_address] <= OUTBUFWRDATA;
       end
    end
end

always @(posedge MCLK) //read 
begin
    if(nBOUTCLKEN == 1'b0)
    begin
        D0_outbuffer_read_data <= D0_outbuffer[outbuffer_read_address];
    end
end

initial
begin
    $readmemb("ipcores/BubbleDrive8/bram_init/D0_outbuffer.txt", D0_outbuffer);
end


//DOUT1
reg             D1_outbuffer[8191:0];
reg             D1_outbuffer_read_data;
assign          DOUT1 = ~D1_outbuffer_read_data;

always @(posedge MCLK)
begin
    if(nOUTBUFWRCLKEN == 1'b0)
    begin
       if (outbuffer_write_enable[1] == 1'b0)
       begin
           D1_outbuffer[outbuffer_write_address] <= OUTBUFWRDATA;
       end
    end
end

always @(posedge MCLK) //read 
begin   
    if(nBOUTCLKEN == 1'b0)
    begin
        D1_outbuffer_read_data <= D1_outbuffer[outbuffer_read_address];
    end
end

initial
begin
    $readmemb("ipcores/BubbleDrive8/bram_init/D1_outbuffer.txt", D1_outbuffer);
end


//DOUT2
reg             D2_outbuffer[8191:0];
reg             D2_outbuffer_read_data;
assign          DOUT2 = (BITWIDTH4 == 1'b0) ? ~1'b1 : ~D2_outbuffer_read_data;

always @(posedge MCLK)
begin
    if(nOUTBUFWRCLKEN == 1'b0)
    begin
       if (outbuffer_write_enable[2] == 1'b0)
       begin
           D2_outbuffer[outbuffer_write_address] <= OUTBUFWRDATA;
       end
    end
end

always @(posedge MCLK) //read 
begin
    if(nBOUTCLKEN == 1'b0)
    begin
        D2_outbuffer_read_data <= D2_outbuffer[outbuffer_read_address];
    end
end

initial
begin
    $readmemb("ipcores/BubbleDrive8/bram_init/D2_outbuffer.txt", D2_outbuffer);
end


//DOUT3
reg             D3_outbuffer[8191:0];
reg             D3_outbuffer_read_data;
assign          DOUT3 = (BITWIDTH4 == 1'b0) ? ~1'b1 : ~D3_outbuffer_read_data;

always @(posedge MCLK)
begin
    if(nOUTBUFWRCLKEN == 1'b0)
    begin
       if (outbuffer_write_enable[3] == 1'b0)
       begin
           D3_outbuffer[outbuffer_write_address] <= OUTBUFWRDATA;
       end
    end
end

always @(posedge MCLK) //read 
begin
    if(nBOUTCLKEN == 1'b0)
    begin
        D3_outbuffer_read_data <= D3_outbuffer[outbuffer_read_address];
    end
end

initial
begin
    $readmemb("ipcores/BubbleDrive8/bram_init/D3_outbuffer.txt", D3_outbuffer);
end

endmodule