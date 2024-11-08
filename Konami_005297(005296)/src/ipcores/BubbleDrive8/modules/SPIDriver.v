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

module SPIDriver
/*
    
*/

(
    //48MHz input clock
    input   wire            MCLK,

    //image/ROM device select
    input   wire    [3:0]   IMGSEL,
    input   wire            ROMSEL,

    //4bit width mode
    input   wire            BITWIDTH4,

    //Emulator signal outputs
    input   wire    [2:0]   ACCTYPE,        //access type
    input   wire    [11:0]  ABSPAGE,         //absolute position number
    output  wire    [11:0]  RELPAGE,

    //Bubble out buffer interface
    output  reg             nOUTBUFWRCLKEN = 1'b1,       //bubble buffer write clken
    output  reg     [14:0]  OUTBUFWRADDR = 14'd0,      //bubble buffer write address
    output  reg             OUTBUFWRDATA = 1'b1,       //bubble buffer write data

    //FIFO buffer interface
    output  reg             nFIFOBUFWRCLKEN = 1'b1,
    output  reg     [12:0]  FIFOBUFWRADDR = 13'd0,   //13bit addr = 8k * 1bit
    output  reg             FIFOBUFWRDATA = 1'b1,
    output  reg             nFIFOSENDBOOT = 1'b1,
    output  reg             nFIFOSENDUSER = 1'b1,

    //Configuration flash: W25Q80, W25Q64
    output  reg             CONFIGROM_nCS,
    output  reg             CONFIGROM_CLK,
    output  reg             CONFIGROM_MOSI,
    input   wire            CONFIGROM_MISO,

    //User flash
    output  reg             USERROM_FLASH_nCS,
    output  reg             USERROM_FRAM_nCS,
    output  reg             USERROM_CLK,
    output  reg             USERROM_MOSI,
    input   wire            USERROM_MISO
);



/*
    GLOBAL SPI REGISTERS
*/

reg             SPI_nCS = 1'b1;
reg             SPI_CLK = 1'b1;
reg             SPI_MOSI;
reg             SPI_MISO;
reg     [2:0]   SPI_IMG;


/*
    SPI MUX
*/

always @(*)
begin
    if(IMGSEL[0] == 1'b1) //FPGA configuration ROM W25Q08
    begin
        CONFIGROM_nCS       = SPI_nCS;
        CONFIGROM_CLK       = SPI_CLK;
        CONFIGROM_MOSI      = SPI_MOSI;

        USERROM_FLASH_nCS   = 1'b1;
        USERROM_FRAM_nCS    = 1'b1;
        USERROM_CLK         = 1'b1;
        USERROM_MOSI        = 1'b1;

        SPI_MISO            = CONFIGROM_MISO;

        SPI_IMG             = 3'b001;
    end

    else
    begin
        if(ROMSEL == 1'b0) //W25Q32
        begin
            CONFIGROM_nCS       = 1'b1;
            CONFIGROM_CLK       = 1'b1;
            CONFIGROM_MOSI      = 1'b1;

            USERROM_FLASH_nCS   = SPI_nCS;
            USERROM_FRAM_nCS    = 1'b1;
            USERROM_CLK         = SPI_CLK;
            USERROM_MOSI        = SPI_MOSI;

            SPI_MISO            = USERROM_MISO;

            SPI_IMG             = IMGSEL[3:1];
        end
        else //Fujitsu MB85RS4MT or Cypress CY15B108
        begin
            CONFIGROM_nCS       = 1'b1;
            CONFIGROM_CLK       = 1'b1;
            CONFIGROM_MOSI      = 1'b1;

            USERROM_FLASH_nCS   = 1'b1;
            USERROM_FRAM_nCS    = SPI_nCS;
            USERROM_CLK         = SPI_CLK;
            USERROM_MOSI        = SPI_MOSI;

            SPI_MISO            = USERROM_MISO;

            SPI_IMG             = {2'b00, IMGSEL[1]};
        end
    end
end



/*
    BAD LOOP MASKING TABLE
*/

reg             map_table[4095:0];
reg             map_data_in;
reg             map_data_out;
reg     [11:0]  map_addr = 12'd0; 
reg             map_write_enable = 1'b1;
reg             map_write_clken = 1'b1;
reg             map_read_clken = 1'b1;

always @(posedge MCLK)
begin
    if(map_write_clken == 1'b0)
    begin
        if(map_write_enable == 1'b0)
        begin
            map_table[{map_addr[11:4], ~map_addr[3:0]}] <= map_data_in; //see bubsys85.net
        end
     end
end

always @(posedge MCLK)
begin
    if(map_read_clken == 1'b0)
    begin
        map_data_out <= map_table[map_addr];
    end
end



/*
    RELATIVE PAGE CONVERTER
*/

reg     [11:0]  target_position = 12'd0;
wire    [11:0]  relative_page;
assign          RELPAGE = relative_page;
reg             convert = 1'b1;

RelativePageConverter Main (.MCLK(MCLK), .nCONV(convert), .ABSPAGE(target_position), .RELPAGE(relative_page));



/*
    SPI LOADER
*/

/*
    HI [00II/IPPP/PPPP/PPPP/PAAA/AAAA] LO
    00II/IXXX = 3 bits of image number
    XPPP/PPPP/PPPP/PXXX = 12 bits of page number
    XAAA/AAAA = 7 bitaddress of a page(128 bytes)
    0x000 - page
    0x001 - page
    ...
    0x804 - page
    0x805 - bootloader
    0x806 - bootloader
    0x807 - bootloader
    0x808 - bootloader
*/

reg     [31:0]  spi_instruction = 32'h0000_0000; //33 bit: 1 bit SPI_LATCH + 8 bit instruction + 24 bit address

reg     [11:0]  general_counter = 12'd0;

//declare states
localparam RESET = 12'b0000_0000_0000;              //버블 출력 종료 후 기본 리셋상태

localparam SPI_RDCMD_2B_S0 = 12'b0001_0000_0000;    //ACCTYPE가 페이지가 카운트 되기 전에 바뀌므로 ABSPAGE+1을 집어넣고, 페이지를 변환한다(convert = 0)
localparam SPI_RDCMD_2B_S1 = 12'b0001_0000_0001;    //convert = 1
localparam SPI_RDCMD_2B_S2 = 12'b0001_0000_0010;    //SPI인스트럭션을 버퍼에 로드한다, 부트로더와 페이지가 달라짐
localparam SPI_RDCMD_2B_S3 = 12'b0001_0000_0011;    //SPI CS내려서 준비한다
localparam SPI_RDCMD_2B_S4 = 12'b0001_0000_0100;    //branch state; 전송 안 했으면 다음 state, 만약 다 전송했으면 액세스 타입에 따라 분기한다
localparam SPI_RDCMD_2B_S5 = 12'b0001_0000_0101;    //negedge에서 마스터가 SPI명령 쉬프트
localparam SPI_RDCMD_2B_S6 = 12'b0001_0000_0110;    //posedge에서 슬레이브가 명령 받게 SPI_CLK = 1, branch state로 돌아가기

//bootloader load
localparam BOOT_2B_S0 = 12'b0011_0010_0000;         //OUTBUFFER주소를 부트로더 시작 주소로 변경한다
localparam BOOT_2B_S1 = 12'b0011_0010_0001;         //branch state; general counter를 보고 부트로더 로딩이 끝났는지 체크하고, 로딩완료면 S6으로
localparam BOOT_2B_S2 = 12'b0011_0010_0010;         //negedge에서 슬레이브가 SPI데이터 보냄
localparam BOOT_2B_S3 = 12'b0011_0010_0011;         //posedge에서 마스터가 데이터를 샘플링한다
localparam BOOT_2B_S4 = 12'b0011_0010_0100;         //OUTBUFFER에 이 데이터를 쓴다(OUTBUFFERCLKEN = 0)
localparam BOOT_2B_S5 = 12'b0011_0010_0101;         //모두 정리하고(OUTBUFFERCLKEN = 1) 제네럴/어드레스 카운터 증가 후 branch로 되돌아간다
//error map load
localparam BOOT_2B_S6 = 12'b0011_0010_0110;         //에러맵 테이블 WE = 0, general counter 리셋
localparam BOOT_2B_S7 = 12'b0011_0010_0111;         //branch state; 에러맵 로딩이 끝났는지 체크하고, 끝났으면 RDIDLE로 간다
localparam BOOT_2B_S8 = 12'b0011_0010_1000;         //negedge에서 슬레이브가 SPI데이터 보냄
localparam BOOT_2B_S9 = 12'b0011_0010_1001;         //posedge에서 마스터가 데이터를 샘플링한다
localparam BOOT_2B_S10 = 12'b0011_0010_1010;        //OUTBUFFER와 error map 테이블 둘 다에 데이터를 쓴다(OUTBUFFERCLKEN = 0)
localparam BOOT_2B_S11 = 12'b0011_0010_1011;        //모두 정리하고(clken = 1) 제네럴/어드레스 카운터 증가 후 branch로 되돌하간다

//page head 6bit
localparam PGRD_2B_S0 = 12'b0100_0000_0000;         //OUTBUFFER주소를 페이지 시작 주소로 변경한다
localparam PGRD_2B_S1 = 12'b0100_0000_0001;         //branch state; 초반 6비트 쉬프트를 했나 안 했나 체크(주의: 0x000, 0x804등은 컨트롤러가 자체적으로 쉬프트시키는듯함)
localparam PGRD_2B_S2_0 = 12'b0100_0000_0010;       //에러맵 테이블 clken = 0으로 읽기
localparam PGRD_2B_S2_1 = 12'b0100_0000_0011;       //에러맵 테이블 clken = 1으로
localparam PGRD_2B_S3 = 12'b0100_0000_0100;         //불량루프(0)이면 데이터 0 쓰기 준비, 정상루프면 1 쓰기 준비
localparam PGRD_2B_S4 = 12'b0100_0000_0101;         //버퍼에 데이터 쓰기
localparam PGRD_2B_S5 = 12'b0100_0000_0110;         //테이블 어드레스 증가, 버퍼 어드레스 증가, branch로 돌아가기
//page data load
localparam PGRD_2B_S6 = 12'b0100_0000_0111;         //branch state; 페이지 다 로딩했나 체크한다, 로딩했으면 SPIIDLE
localparam PGRD_2B_S7 = 12'b0100_0000_1000;         //negedge에서 슬레이브가 SPI데이터 보냄
localparam PGRD_2B_S8 = 12'b0100_0000_1001;         //posedge에서 데이터를 샘플링하고, 에러맵 테이블 clken = 0으로 읽기 
localparam PGRD_2B_S9 = 12'b0100_0000_1010;         //에러맵 테이블 clken = 0으로 읽기 
localparam PGRD_2B_S10 = 12'b0100_0000_1011;        //불량루프(0)이면 데이터 0 쓰기 준비, 정상루프면 SPI데이터 쓰기 준비
localparam PGRD_2B_S11 = 12'b0100_0000_1100;        //버퍼에 데이터를 쓴다
localparam PGRD_2B_S12 = 12'b0100_0000_1101;        //branch state; 테이블 어드레스 증가, 버퍼 어드레스 증가, 정상루프면 g.c증가시키고 S6으로 돌아가기, 불량루프면 g.c는 그대로 S8로 가서 에러맵 읽기

localparam SPI_RDIDLE_S0 = 12'b0000_0001_0000;      //SPI CS = 1; 데이터 출력 다 끝난 후 버블 데이터 다 보낼때까지 대기시간, SENDBOOT or SENDUSER = 0

localparam PGWR_2B_S0 = 12'b1000_0000_0000;

localparam SPI_RDCMD_4B_S0 = 12'b0001_1000_0000;
localparam BOOT_4B_S0 = 12'b0011_1000_0000;
localparam PGRD_4B_S0 = 12'b0100_1000_0000;
localparam PGWR_4B_S0 = 12'b1100_0000_0000;

//spi state
reg     [11:0]   spi_state = RESET;

//state flow control
always @(posedge MCLK)
begin
    case (spi_state)
        //아이들 상태
        SPI_RDIDLE_S0:
            case(ACCTYPE[1])
                1'b0: spi_state <= RESET;
                1'b1: spi_state <= SPI_RDIDLE_S0;
            endcase
        RESET:
            case(ACCTYPE[1])
                1'b0: spi_state <= RESET;
                1'b1: spi_state <= SPI_RDCMD_2B_S0;
            endcase

        //2비트 모드 SPI 로드
        SPI_RDCMD_2B_S0: spi_state <= SPI_RDCMD_2B_S1;
        SPI_RDCMD_2B_S1: spi_state <= SPI_RDCMD_2B_S2;
        SPI_RDCMD_2B_S2: spi_state <= SPI_RDCMD_2B_S3;
        SPI_RDCMD_2B_S3: spi_state <= SPI_RDCMD_2B_S4;
        SPI_RDCMD_2B_S4:
            case({general_counter[5], ACCTYPE[0]})
                2'b00: spi_state <= SPI_RDCMD_2B_S5;
                2'b01: spi_state <= SPI_RDCMD_2B_S5;
                2'b10: spi_state <= BOOT_2B_S0;
                2'b11: spi_state <= PGRD_2B_S0;
            endcase
        SPI_RDCMD_2B_S5: spi_state <= SPI_RDCMD_2B_S6;
        SPI_RDCMD_2B_S6: spi_state <= SPI_RDCMD_2B_S4;

        //2비트 모드 부트로더 읽기
        BOOT_2B_S0: spi_state <= BOOT_2B_S1;
        BOOT_2B_S1:
            if(general_counter < 12'd2656)
            begin
                spi_state <= BOOT_2B_S2;
            end
            else
            begin
                spi_state <= BOOT_2B_S6;
            end
        BOOT_2B_S2: spi_state <= BOOT_2B_S3;
        BOOT_2B_S3: spi_state <= BOOT_2B_S4;
        BOOT_2B_S4: spi_state <= BOOT_2B_S5;
        BOOT_2B_S5: spi_state <= BOOT_2B_S1;

        BOOT_2B_S6: spi_state <= BOOT_2B_S7;
        BOOT_2B_S7:
            if(general_counter < 12'd1168 + 12'd32) //굉장히 수상한 32비트 데이터
            begin
                spi_state <= BOOT_2B_S8;
            end
            else
            begin
                spi_state <= SPI_RDIDLE_S0;
            end
        BOOT_2B_S8: spi_state <= BOOT_2B_S9;
        BOOT_2B_S9: spi_state <= BOOT_2B_S10;
        BOOT_2B_S10: spi_state <= BOOT_2B_S11;
        BOOT_2B_S11: spi_state <= BOOT_2B_S7;

        //2비트 모드 페이지 읽기
        PGRD_2B_S0: spi_state <= PGRD_2B_S1;
        PGRD_2B_S1:
            if(general_counter < 12'd6)
            begin
                spi_state <= PGRD_2B_S2_0;
            end
            else
            begin
                spi_state <= PGRD_2B_S6;
            end
        PGRD_2B_S2_0: spi_state <= PGRD_2B_S2_1;
        PGRD_2B_S2_1: spi_state <= PGRD_2B_S3;
        PGRD_2B_S3: spi_state <= PGRD_2B_S4;
        PGRD_2B_S4: spi_state <= PGRD_2B_S5;
        PGRD_2B_S5:
            case(map_data_out)
                1'b0: spi_state <= PGRD_2B_S2_0; //불량 루프면 다음 에러맵 읽기
                1'b1: spi_state <= PGRD_2B_S1; //정상 루프면 되돌아가기, 카운터 증가
            endcase

        PGRD_2B_S6:
            if(general_counter < 12'd1030)
            begin
                spi_state <= PGRD_2B_S7;
            end
            else
            begin
                spi_state <= SPI_RDIDLE_S0;
            end
        PGRD_2B_S7: spi_state <= PGRD_2B_S8;
        PGRD_2B_S8: spi_state <= PGRD_2B_S9;
        PGRD_2B_S9: spi_state <= PGRD_2B_S10;
        PGRD_2B_S10: spi_state <= PGRD_2B_S11;
        PGRD_2B_S11: spi_state <= PGRD_2B_S12;
        PGRD_2B_S12:
            case(map_data_out)
                1'b0: spi_state <= PGRD_2B_S8; //불량 루프면 다음 에러맵 읽기
                1'b1: spi_state <= PGRD_2B_S6; //정상 루프면 데이터 그대로 쓰기 준비
            endcase

        default: spi_state <= RESET;
    endcase
end

//determine the output
always @(posedge MCLK)
begin
    case (spi_state)
        SPI_RDIDLE_S0:
        begin
            SPI_nCS <= 1'b1; SPI_CLK <= 1'b1; 
            
            if(ACCTYPE == 3'b110) //bootloader
            begin
                nFIFOSENDBOOT <= 1'b0;
                nFIFOSENDUSER <= 1'b1;
            end
            else if(ACCTYPE == 3'b111) //user pages
            begin
                nFIFOSENDBOOT <= 1'b1;
                nFIFOSENDUSER <= 1'b0;
            end
            else
            begin
                nFIFOSENDBOOT <= 1'b1;
                nFIFOSENDUSER <= 1'b1;
            end
        end
        RESET:
        begin
            SPI_nCS <= 1'b1; SPI_CLK <= 1'b1; 
            OUTBUFWRADDR <= {1'b0, 13'd0, 1'b0}; nOUTBUFWRCLKEN <= 1'b1;
            map_addr <= 12'd0; map_write_enable <= 1'b1; map_write_clken <= 1'b1; map_read_clken <= 1'b1;
            FIFOBUFWRADDR <= 13'd0; nFIFOBUFWRCLKEN <= 1'b1; nFIFOSENDBOOT <= 1'b1; nFIFOSENDUSER <= 1'b1;
            convert <= 1'b1;
            general_counter <= 12'd0; 
        end

        SPI_RDCMD_2B_S0:
        begin
            target_position <= ABSPAGE + 12'd1;
            convert <= 1'b0;
        end
        SPI_RDCMD_2B_S1:
        begin
            convert <= 1'b1;
        end 
        SPI_RDCMD_2B_S2:
        begin
            convert <= 1'b1;
            case(ACCTYPE[0])
                1'b0: begin spi_instruction <= {8'b0000_0011, 2'b00, SPI_IMG, 12'h805, 7'b000_0000}; $display("Read bootloader"); end
                1'b1: begin spi_instruction <= {8'b0000_0011, 2'b00, SPI_IMG, relative_page[11:0], 7'b000_0000}; $display("Read page 0x%h", relative_page[11:0]); end
            endcase
        end
        SPI_RDCMD_2B_S3:
        begin
            SPI_nCS <= 1'b0;
        end
        SPI_RDCMD_2B_S4:
        begin
            
        end
        SPI_RDCMD_2B_S5:
        begin
            SPI_CLK <= 1'b0;
            SPI_MOSI <= spi_instruction[31];
            spi_instruction[31:1] <= spi_instruction[30:0]; 
            general_counter <= general_counter + 12'd1; 
        end
        SPI_RDCMD_2B_S6:
        begin
            SPI_CLK <= 1'b1;
        end

        BOOT_2B_S0:
        begin
            OUTBUFWRADDR <= {1'b0, 13'd0, 1'b0}; //부트로더 시작 주소로 변경
            FIFOBUFWRADDR <= 13'd0;

            general_counter <= 12'd0;
        end
        BOOT_2B_S1:
        begin
            
        end
        BOOT_2B_S2:
        begin
            SPI_CLK <= 1'b0;
        end
        BOOT_2B_S3:
        begin
            SPI_CLK <= 1'b1;
            OUTBUFWRDATA <= SPI_MISO;
            FIFOBUFWRDATA <= SPI_MISO;
        end
        BOOT_2B_S4:
        begin
            nOUTBUFWRCLKEN <= 1'b0;
            nFIFOBUFWRCLKEN <= 1'b0;
        end
        BOOT_2B_S5:
        begin
            nOUTBUFWRCLKEN <= 1'b1; OUTBUFWRADDR <= OUTBUFWRADDR + 15'd1;
            nFIFOBUFWRCLKEN <= 1'b1; FIFOBUFWRADDR <= FIFOBUFWRADDR + 13'd1;
            general_counter <= general_counter + 12'd1;
        end
        BOOT_2B_S6:
        begin
            map_write_enable <= 1'b0; //에러맵 테이블 쓰기 허용
            general_counter <= 12'd0;
        end
        BOOT_2B_S7:
        begin
            
        end
        BOOT_2B_S8:
        begin
            SPI_CLK <= 1'b0;
        end
        BOOT_2B_S9:
        begin
            SPI_CLK <= 1'b1;
            OUTBUFWRDATA <= SPI_MISO;
            map_data_in <= SPI_MISO;
            FIFOBUFWRDATA <= SPI_MISO;
        end
        BOOT_2B_S10:
        begin
            nOUTBUFWRCLKEN <= 1'b0;
            map_write_clken <= 1'b0;
            nFIFOBUFWRCLKEN <= 1'b0;
        end
        BOOT_2B_S11:
        begin
            nOUTBUFWRCLKEN <= 1'b1; OUTBUFWRADDR <= OUTBUFWRADDR + 15'd1;
            map_write_clken <= 1'b1; map_addr <= map_addr + 12'd1;
            nFIFOBUFWRCLKEN <= 1'b1; FIFOBUFWRADDR <= FIFOBUFWRADDR + 13'd1;
            general_counter <= general_counter + 12'd1;
        end

        PGRD_2B_S0:
        begin
            OUTBUFWRADDR <= {1'b0, 13'd7168, 1'b0}; //페이지 데이터 시작시점
            FIFOBUFWRADDR <= 13'd0;
            general_counter <= 12'd0;
        end
        PGRD_2B_S1:
        begin
            
        end
        PGRD_2B_S2_0:
        begin
            map_read_clken <= 1'b0;
        end
        PGRD_2B_S2_1:
        begin
            map_read_clken <= 1'b1;
        end
        PGRD_2B_S3:
        begin
            map_read_clken <= 1'b1;
            case(map_data_out)
                1'b0: OUTBUFWRDATA <= 1'b0; //불량 루프면 데이터 0쓰기 준비
                1'b1: OUTBUFWRDATA <= 1'b1; //정상 루프면 데이터 1쓰기 준비, 카운터 증가
            endcase
        end
        PGRD_2B_S4:
        begin
            nOUTBUFWRCLKEN <= 1'b0;
        end
        PGRD_2B_S5:
        begin
            map_addr <= map_addr + 12'd1;
            nOUTBUFWRCLKEN <= 1'b1; OUTBUFWRADDR <= OUTBUFWRADDR + 15'd1;
            case(map_data_out)
                1'b0: begin end //불량 루프면 다음 에러맵 읽기
                1'b1: begin general_counter <= general_counter + 12'd1; end //정상 루프면 되돌아가기, 카운터 증가
            endcase
        end
        PGRD_2B_S6:
        begin
            
        end
        PGRD_2B_S7:
        begin
            SPI_CLK <= 1'b0;
        end
        PGRD_2B_S8:
        begin
            SPI_CLK <= 1'b1;
            map_read_clken <= 1'b0;
        end
        PGRD_2B_S9:
        begin
            map_read_clken <= 1'b1;
        end
        PGRD_2B_S10:
        begin
            map_read_clken <= 1'b1;
            case(map_data_out)
                1'b0: begin OUTBUFWRDATA <= 1'b0; end //불량 루프면 데이터 0쓰기 준비
                1'b1: begin OUTBUFWRDATA <= SPI_MISO; FIFOBUFWRDATA <= SPI_MISO; end //정상 루프면 데이터 그대로 쓰기 준비
            endcase
        end
        PGRD_2B_S11:
        begin
            nOUTBUFWRCLKEN <= 1'b0;
            case(map_data_out)
                1'b0: begin nFIFOBUFWRCLKEN <= 1'b1; end //불량 루프면 FIFO버퍼에 데이터 쓰지 않기
                1'b1: begin nFIFOBUFWRCLKEN <= 1'b0; end //정상 루프면 FIFO버퍼에 데이터 쓰기
            endcase
            
        end
        PGRD_2B_S12:
        begin
            map_addr <= map_addr + 12'd1;
            nOUTBUFWRCLKEN <= 1'b1; OUTBUFWRADDR <= OUTBUFWRADDR + 15'd1; 
            nFIFOBUFWRCLKEN <= 1'b1; 
            case(map_data_out)
                1'b0: begin end //불량 루프면 다음 에러맵 읽기
                1'b1: begin general_counter <= general_counter + 12'd1; FIFOBUFWRADDR <= FIFOBUFWRADDR + 13'd1; end //정상 루프면 데이터 그대로 쓰기 준비, FIFO버퍼 어드레스 증가
            endcase
        end

        default:
        begin
            
        end
    endcase
end

endmodule