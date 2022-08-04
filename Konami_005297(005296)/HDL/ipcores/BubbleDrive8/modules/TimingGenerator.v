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

module TimingGenerator
/*
    BubbleDrive8_emucore > modules > TimingGenerator.v

    Copyright (C) 2020-2021, Raki

    TimingGenerator provides all timing signals related to 
    the bubble memory side. This module uses 48MHz as master clock, 
    x4 of the original function timing generator(FTG) MB14506.
    Thereby BubbleDrive8 can manage all bubble logic without using 
    a PLL block. 


    * more details of signals below can be found on bubsys85.net *

    CLKOUT: 
        4MHz clock for the bubble memory controller: maybe an MCU uses this
    nBSS: Bubble Shift Start
        a pulse to notify a start of access cycle
    nBSEN: Bubble Shift ENable
        magnetic field rotates when this signal goes low
    nREPEN: REPlicator ENable
        FTG use this signal to replicate a bubble 
    nBOOTEN: BOOTloop ENable
        controller can access two bootloops by driving this signal low
    nSWAPEN: SWAP gate ENable
        FTG use this signal to write a page to a bubble memory

    nEN: module enable signal
    ACCTYPE: bubble access mode type
    BOUTCYCLENUM: bubble output cycle number: counts serial bits
    nBINCLKEN: emulator samples bubble data for page write when this goes low
    nBOUTCLKEN: emulator launches bubble data when this goes low
    nNOBUBBLE: emulator launches 1(no bubble)

    ABSPAGE: bubble memory's absolute position number


    * For my convenience, many comments are written in Korean *
*/

(
    //48MHz input clock
    input   wire            MCLK,   

    //4MHz output clock
    output  reg             CLKOUT = 1'b1,

    //Input control
    input   wire            nEN,
    input   wire            TIMINGSEL,

    //Bubble control signal inputs
    input   wire            nBSS,
    input   wire            nBSEN,
    input   wire            nREPEN,
    input   wire            nBOOTEN,
    input   wire            nSWAPEN,
    
    //Emulator signal outputs
    output  wire    [2:0]   ACCTYPE,
    output  reg     [12:0]  BOUTCYCLENUM,
    output  reg             nBINCLKEN = 1'b1,
    output  reg             nBOUTCLKEN = 1'b0,

    output  wire    [11:0]  ABSPAGE
);

localparam      INITIAL_ABS_PAGE = 12'd1968; //0-2052
reg             __REF_nBOUTCLKEN_ORIG = 1'b0;
reg             __REF_CLK12M = 1'b0;


/*
    GLOBAL NET/REGS
*/
reg             nBSS_intl;
reg             nBSEN_intl;
reg             nREPEN_intl;
reg             nBOOTEN_intl;
reg             nSWAPEN_intl;



/*
    CLOCK DIVIDER
*/

/*
                                                         1 1 1 1 1 1 1 1 1 1 2 2 2 2
                                     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 0 1 2 3 4 ...
                                                                             1   1 
                                     0   1   2   3   4   5   6   7   8   9   0   1   0
    48MHz             ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    12MHz             _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    4MHz              ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|

    BMC signals       ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
                                           |---------> sampled


    synchronization                                  |---|           |---|
    determine current access state                       |---|           |---|
    MCLK counting                                            |---------------|----------------->

    This block generates 12MHz ref clk, and 4MHz BMC clock. BMC always launches
    its signal at a "falling edge" of 4MHz. I don't know if it's synchronized
    to 4MHz or if they added a simple buffer delay. Anyway, all control signals
    arrives at a negative edge of the departing 4MHz.
    MB14506 starts to rotate magnetic field 23*12Mclk(about 83.33ns*23) later 
    just after nBSEN is sampled.
*/

reg     [4:0]   counter12 = 4'd0;


always @(posedge MCLK)
begin
    if(counter12 == 4'd1)
    begin
        __REF_CLK12M <= 1'b1;
        counter12 <= counter12 + 4'd1;
    end
    else if(counter12 == 4'd3)
    begin
        __REF_CLK12M <= 1'b0;
        counter12 <= counter12 + 4'd1;
    end
    else if(counter12 == 4'd5)
    begin
        __REF_CLK12M <= 1'b1;
        CLKOUT <= 1'b1;
        counter12 <= counter12 + 4'd1;
    end
    else if(counter12 == 4'd7)
    begin
        __REF_CLK12M <= 1'b0;
        counter12 <= counter12 + 4'd1;
    end
    else if(counter12 == 4'd9)
    begin
        __REF_CLK12M <= 1'b1;
        counter12 <= counter12 + 4'd1;
    end
    else if(counter12 == 4'd11)
    begin
        __REF_CLK12M <= 1'b0;
        CLKOUT <= 1'b0;
        counter12 <= 4'd0;
    end
    else
    begin
        counter12 <= counter12 + 4'd1;
    end
end



/*
    BUFFER CHAIN
*/
reg     [4:0]   step1 = 5'b11110;
reg     [4:0]   step2 = 5'b11110;
reg     [4:0]   step3 = 5'b11110;

always @(negedge MCLK)
begin
    step1[4] <= nEN | nSWAPEN;
    step1[3] <= nEN | nBSS;
    step1[2] <= nEN | nBSEN;
    step1[1] <= nEN | (nREPEN | ~nBOOTEN);
    step1[0] <= ~nEN & nBOOTEN;

    step2 <= step1;
    step3 <= step2;
end



/*
    SYNCHRONIZER
*/
always @(posedge MCLK)
begin
    if(counter12 == 4'd3 || counter12 == 4'd7 || counter12 == 4'd11)
    begin
        nSWAPEN_intl    <= step3[4];
        nBSS_intl       <= step3[3];
        nBSEN_intl      <= step3[2]; 
        nREPEN_intl     <= step3[1];
        nBOOTEN_intl    <= step3[0];
    end
end


/*
    ACCESS TYPE STATE MACHINE
*/

/*
    nREPEN            ¯¯¯¯¯¯¯¯¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    nBSS_intl         ¯¯¯¯¯|_|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    nBOOTEN_intl      ______________________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    nBSEN_intl        ¯¯¯¯¯¯¯¯|____________________________________|¯¯¯¯¯¯¯¯¯|__________________________|¯¯¯¯¯¯|__________________________|¯¯¯
    nREPEN_intl       ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    nSWAPEN_intl      ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_|¯¯¯¯¯¯¯¯
                              |----(bootloader load out enable)----|             |(page load out enable)|                          |(swap)|
    ----->TIME        A    |B |C                                   |A     |B |E  |D(HOLD)               |A  |B |E                  |F     |A
*/

//[magnetic field activation/data transfer/mode]
localparam RST = 3'b000;    //A
localparam STBY = 3'b001;   //B
localparam BOOT = 3'b110;   //C
localparam USER = 3'b111;   //D
localparam IDLE = 3'b100;   //E
localparam SWAP = 3'b101;   //F

reg     [2:0]   access_type = RST;
assign ACCTYPE = access_type;

always @(posedge MCLK)
begin
    case ({nBSS_intl, nBOOTEN_intl, nBSEN_intl, nREPEN_intl, nSWAPEN_intl})
        5'b10111: //최초 시작 후의 리셋 상태, 또는 부트로더 액세스가 끝난 후 아주 잠깐 발생
        begin
            if(access_type == STBY)
            begin
                access_type <= STBY;
            end
            else
            begin
                access_type <= RST;
            end
        end

        5'b00111: //부트로더 스탠바이
        begin
            if(access_type == RST)
            begin
                access_type <= STBY;
            end
            else
            begin
                access_type <= access_type;
            end
        end

        5'b10011: //부트로더 액세스 중
        begin
            if(access_type == STBY || access_type == BOOT || access_type == RST)
            begin
                access_type <= BOOT;
            end
            else
            begin
                access_type <= access_type;
            end
        end

        5'b11111: //유저 영역 리셋 상태
        begin
            if(access_type == STBY)
            begin
                access_type <= STBY;
            end
            else
            begin
                access_type <= RST;
            end
        end

        5'b01111: //페이지 스탠바이
        begin
            if(access_type == RST)
            begin
                access_type <= STBY;
            end
            else
            begin
                access_type <= access_type;
            end
        end

        5'b11011: //페이지 seek중, 또는 페이지 로딩 중(로딩 중에는 리플리케이션을 유지)
        begin
            if(access_type == STBY || access_type == RST)
            begin
                access_type <= IDLE;
            end
            else
            begin
                access_type <= access_type;
            end
        end

        5'b11001: //리플리케이션 펄스가 들어왔을 때
        begin
            if(access_type == IDLE)
            begin
                access_type <= USER;
            end
            else
            begin
                access_type <= access_type;
            end
        end

        5'b11010: //스왑 펄스가 들어왔을 때
        begin
            if(access_type == IDLE)
            begin
                access_type <= SWAP;
            end
            else
            begin
                access_type <= access_type;
            end
        end

        default:
        begin
            access_type <= access_type;
        end
    endcase
end



/*
    BUBBLE CYCLE STATE MACHINE
*/

/*
        +Y 568
-X 208           +X 448
        -Y 328
*/

//12MHz 1 bubble cycle = 120clks
//48MHz 1 bubble cycle = 480clks
//12MHz 1.5클럭이 씹힌 후에 계산, 만약 BMC신호가 38ns 이상 지연되면 1클럭 추가로 씹힘
//1.5클럭 씹힌 후 22클럭이 지난 직후 -X자기장 생성 시작

reg     [9:0]   MCLK_counter = 10'd0; //마스터 카운터는 세기 쉽게 1부터 시작 0아님!!

//master clock counters
always @(posedge MCLK)
begin
    //시작
    if(MCLK_counter == 10'd0)
    begin
        if(access_type[2] == 1'b0)
        begin
            MCLK_counter <= 10'd0;
        end
        else
        begin
            MCLK_counter <= MCLK_counter + 10'd1;
        end
    end

    //53번째 pos엣지에서 half disk -X방향 위치
    else if(MCLK_counter == 10'd208)
    begin
        if(access_type[2] == 1'b0) //-X방향에서 자기장회전이 끝났다면
        begin
            MCLK_counter <= 10'd0; //그대로 정지
        end
        else
        begin
            MCLK_counter <= MCLK_counter + 10'd1;
        end
    end

    //143번째 pos엣지에서 half disk +Y방향 위치
    else if(MCLK_counter == 10'd568) 
    begin
       MCLK_counter <= 10'd89; 
    end

    else
    begin
        MCLK_counter <= MCLK_counter + 10'd1;
    end
end

/*

    //////////////////////////////////////////////////////
    ////    INTERNAL ORGANIZATION OF FBM54DB


        -1
    ----O---- DETECTOR 1
     \  |0 /   <------------ bubble output signal latched here(magnetic field -Y) by MB3908 sense amplifier; stretcher patterns exist here
      --O--   DETECTOR 0
        |                                                   ←     ←     ←     ←     ←         propagation direction
        |1    2         95    96    97    98    99    100   101               680   681
        O-----O   ...   O-----O-----O-----O-----O-----O-----O--             --O-----O
                              ↑     ↑     ↑     ↑     ↑     ↑                 ↑     ↑  
                            __^__ __^__ __^__ __^__ __^__ __^__             __^__ __^__  <-- "block" replicators; replicators for two bootloops
                         ↓  |   | |   | |   | |   | |   | |   |             |   | |   |       can be operated independantly from page replicators
                            |   | |   | |   | |   | |   | |   |             |   | |   | 
                         ↓  | L | | L | | L | | L | | L | | L |             | L | | L | 
                            | O | | O | | O | | O | | O | | O |             | O | | O | 
        ←                ↓  | O | | O | | O | | O | | O | | O |    .....    | O | | O |  <-- each loop can hold 2053 magnetic bubbles
     ↙                     | P | | P | | P | | P | | P | | P |             | P | | P | 
     ↓  ↑ EXTERNAL       ↓  |B 0| |B 1| |  0| |  1| |  2| |  3|             |582| |583| 
        | MAGNETIC          |   | |   | |   | |   | |   | |   |             |   | |   | 
          FIELD             ~   ~ ~   ~ ~   ~ ~   ~ ~   ~ ~   ~             ~   ~ ~O N~ 
                            |   | |   | |   | |   | |   | |   |             |   | |L E| 
                            |   | |   | |   | |   | |   | |   |             |   | |D W| 
                            ¯↓^↑¯ ¯↓^↑¯ ¯↓^↑¯ ¯↓^↑¯ ¯↓^↑¯ ¯↓^↑¯             ¯↓^↑¯ ¯↓^↑¯  <-- swap gate swaps an old bubble with a new bubble at the same time: -Y
                             / \   / \   / \   / \   / \   / \               / \   / \                    2     1
            O-- .... ---O---/-O-\-/-O-\-/-O-\-/-O-\-/-O-\-/-O-\-            /-O-\-/-O-\---O-----O   ...   O-----O
            |                 626   625   624   623   622   621               42    41    40    39              |
            ↓ discarded                                                                ↑              __________^_0________
                                                                                 -Y position          | G E N E R A T O R | <-- generates a bubble at +Y

    SEE JAPANESE PATENT:
    JPA 1992074376-000000 / 特許出願公開 平4-74376  ;contains replicator/swap gate diagram
    JPA 1989220199-000000 / 特許出願公開 平1-220199 ;explains bubble write procedure

    !!!! IMPORTANT NOTE !!!!
    Note that FBM54DB is organized with EVEN HALF and ODD HALF. The EVEN HALF
    has 1 even bootloop + 292 even minor loops and the ODD HALF has the same
    but they are odd numbered loops. Due to the physical width of minor loop,
    there is one position between a position and a position on read/write
    track. That is, there is one bubble for every two positions, like a diagram
    below:

            P   P   P   P   P   P   P   P
    ODD     O---*---O---*---O---*---O---*
            bubble  bubble  bubble  bubble

            P   P   P   P   P   P   P   P
    EVEN    *---O---*---O---*---O---*---O
                bubble  bubble  bubble  bubble

    Bubble moves one position every 10us, so in this case, 1 bit of data is
    transferred every 20us. Developers wanted to speed things up. So, they
    made another half that can be "interleaved". FBM54DB has two detectors
    and two MB3908 sense amplifiers. Each SA launches data 50kbps anyway 
    but its open collector(negative logic) outputs are interleaved outside,
    therefore the user can get 100kbps data. The BMC inverts negative logic
    data internally.

    I merged the EVEN HALF and the ODD HALF in the diagaram above, for my
    convenience. Therefore the diagram that represents the real organization
    will be like this:

    ODD HALF :

        -1
    ----O---- DETECTOR 1
     \  |0 /
      --O--   DETECTOR 0
        |                                                   ←     ←     ←     ←     ←         propagation direction
        |1    2         95    96    97    98    99    100   101               680   681
        O-----O   ...   O-----O-----O-----O-----O-----O-----O--             --O-----O
                                    ↑           ↑           ↑                       ↑  
                                  __^__       __^__       __^__                   __^__
                                  |   |       |   |       |   |                   |   |
                                  |   |       |   |       |   |                   |   | 
                                  | L |       | L |       | L |                   | L | 
                                  | O |       | O |       | O |                   | O | 
        ←                         | O |       | O |       | O |    .....          | O |
     ↙                           | P |       | P |       | P |                   | P | 
     ↓  ↑ EXTERNAL                |B 1|       |  1|       |  3|                   |583| 
        | MAGNETIC                |   |       |   |       |   |                   |   | 
          FIELD                   ~   ~       ~   ~       ~   ~                   ~O N~ 
                                  |   |       |   |       |   |                   |L E| 
                                  |   |       |   |       |   |                   |D W| 
                                  ¯↓^↑¯       ¯↓^↑¯       ¯↓^↑¯                   ¯↓^↑¯ 
                                   / \         / \         / \                     / \                    2     1
            O-- .... ---O-----O---/-O-\---O---/-O-\---O---/-O-\-            --O---/-O-\---O-----O   ...   O-----O
            |                 626   625   624   623   622   621               42    41    40    39              |
            ↓ discarded                                                                ↑              __________^_0________
                                                                                  -Y position         | G E N E R A T O R |

    EVEN HALF :

        -1
    ----O---- DETECTOR 1
     \  |0 /
      --O--   DETECTOR 0
        |                                                   ←     ←     ←     ←     ←         propagation direction
        |1    2         95    96    97    98    99    100   101               680   681
        O-----O   ...   O-----O-----O-----O-----O-----O-----O--             --O-----O
                              ↑           ↑           ↑                       ↑  
                            __^__       __^__       __^__                   __^__
                            |   |       |   |       |   |                   |   |
                            |   |       |   |       |   |                   |   |
                            | L |       | L |       | L |                   | L |
                            | O |       | O |       | O |                   | O |
        ←                   | O |       | O |       | O |          .....    | O |
     ↙                     | P |       | P |       | P |                   | P | 
     ↓  ↑ EXTERNAL          |B 0|       |  0|       |  2|                   |582|
        | MAGNETIC          |   |       |   |       |   |                   |   |
          FIELD             ~   ~       ~   ~       ~   ~                   ~   ~
                            |   |       |   |       |   |                   |   |
                            |   |       |   |       |   |                   |   |
                            ¯↓^↑¯       ¯↓^↑¯       ¯↓^↑¯                   ¯↓^↑¯
                             / \         / \         / \                     / \                          2     1
            O-- .... ---O---/-O-\---O---/-O-\---O---/-O-\---O---          --/-O-\---O-----O-----O   ...   O-----O
            |                 626   625   624   623   622   621               42    41    40    39              |
            ↓ discarded                                                                ↑             __________^_0________
                                                                                 -Y position         | G E N E R A T O R |


    //////////////////////////////////////////////////////
    ////    EXACT MINOR LOOP POSITION OF FBM54DB

    A good minor loop in FBM54DB can hold 2053 magnetic bubbles. This means
    that the total count of positions is 2053. Early bubble memories had put 
    a bubble every two positions to prevent bubble-bubble interaction, but
    FBM54DB doesn't require such action. In the diagram, it appears to be 
    the swap gate and the replicator exist in symmetrical positions, 
    but actually, it's not. 

                        1   0   2052
                ____  __O___O___O__
                |  |  |           |
                |  |  |           O 2051
                |  |  |           |
                |  |  |           O 2050
                |  |  |           |
                |  |  |           O 2049
                |  |  |           |
                |  ¯¯¯¯           O 2048
    same loops  ~~   partially   ~~~
    continue    ~~   magnified   ~~~
                |  ____           O 1541
                |  |  |           | 
          912+0 O  |  O           O 1540
                |  |  |    LOOP   | 
             +1 O  |  O    #584   O 1539    
                |  |  |           | 
             +2 O  |  O           O 1538
                |  |  |    +624   | 
                ¯¯¯¯  ¯¯O¯↓¯O¯↑¯O¯¯ 
                    +623 /     \ +625
                  42    /   41  \     40        39
                --O----↓----O----↑----O---------O
                    bubble    bubble   
                    goes OUT  goes IN 
                    on this   on this  
                    position  position 
                    at -Y     at -Y

    To increase loop capacity and density of each half, Fujitsu lengthened
    minor loops about twice. I assume they are shaped like "H".

    Replicator is on absolute position 0
    Swap gate is on absolute position 1536
*/

/*
    ABSOLUTE POSITION COUNTER
*/

reg     [11:0]  absolute_page_number = INITIAL_ABS_PAGE;
assign  ABSPAGE = absolute_page_number;

always @(posedge MCLK)
begin
    //143번째 pos엣지에서 half disk +Y방향 위치
    if(MCLK_counter == 10'd568) 
    begin
        if(absolute_page_number < 12'd2052)
        begin
            absolute_page_number <= absolute_page_number + 12'd1;
        end
        else
        begin
            absolute_page_number <= 12'd0;
        end
    end
    //+Y 방향 빼고 나머지에서는
    else
    begin
        absolute_page_number <= absolute_page_number;
    end
end




/*
    TIMING CONSTANTS
*/

/*
        +Y 568
-X 208           +X 448
        -Y 328
*/

/*
    An MB3908 has two DFF with /Q OC output, and triggered on every positive
    edge of BOUTCLK from MB14506 timing generator. For example, the waveform
    below is showing a transfer of "6C 36 B1" 

                0us     0       0       0       0       0       0       0       0       0       0       0
    BOUTCLK     |¯|_____|¯|_____|¯|_____|¯|_____|¯|_____|¯|_____|¯|_____|¯|_____|¯|_____|¯|_____|¯|_____|¯|_____
    D1          ¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    D0          ________|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______
    bootloop          ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^
                   +7~8us
    user page     ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^     
               +0~1us

    Konami's BMC has different sampling timings for bootloop and user page, 
    respectively. I don't know how the unknown MCU inside the BMC 
    samples(or latches) data. I assume that MCU gets data from memory-mapped
    register once per bit, but there are several possibilities that the MCU
    gets several times, triggers flip-flops to sample data, or enables a kind
    of transparent latch for quite a long time.

    My friend Maki sent me a Bubble System PCB which has a deteriorated LS244.
    Total three LS244 are used as bubble memory control signal buffers, and 
    its propagation delay is often prolonged due to aging or the output 
    goes weak. Finally, it often became insufficient to drive a fairly long
    transmission line.

    Anyway, to prevent this missampling, bubble data should be launched 0-1us
    earlier when reading the bootloop, and 5-6us earlier when reading user
    pages.
*/

reg     [9:0]   OUTBUFFER_CLKEN_TIMING = 10'd0;
reg     [9:0]   CYCLECOUNTER_TIMING = 10'd568;

always @(posedge MCLK)
begin
    if(nEN == 1'b1)
    begin
        OUTBUFFER_CLKEN_TIMING <= 10'd0;
        CYCLECOUNTER_TIMING <= 10'd568;
    end
    else
    begin
        if(TIMINGSEL == 1'b0)
        begin
            OUTBUFFER_CLKEN_TIMING <= 10'd328 - 10'd2; //오리지널 타이밍 - 20ns
            CYCLECOUNTER_TIMING <= 10'd568; //오리지널 타이밍
        end
        else
        begin
            if(access_type == BOOT)
            begin
                OUTBUFFER_CLKEN_TIMING <= 10'd328 - 10'd2; //오리지널 타이밍 - 20ns
                CYCLECOUNTER_TIMING <= 10'd568; //오리지널 타이밍
            end
            else if(access_type == USER)
            begin
                OUTBUFFER_CLKEN_TIMING <= 10'd568 - 10'd48; //오리지널 타이밍 - 6us
                CYCLECOUNTER_TIMING <= 10'd568 - 10'd60;  //오리지널보다 카운터를 2.5us 빨리 증가시킴
            end
            else
            begin
                OUTBUFFER_CLKEN_TIMING <= 10'd328 - 10'd2; //오리지널 타이밍 - 20ns
                CYCLECOUNTER_TIMING <= 10'd568; //오리지널 타이밍
            end
        end
    end
end



/*
    CYCLE COUNTER
*/

reg     [6:0]   bout_propagation_delay_counter = 7'd127; //98
reg     [9:0]   bout_page_cycle_counter = 10'd1023; //584
reg     [12:0]  bout_bootloop_cycle_counter = {1'b0, INITIAL_ABS_PAGE}; //4106

//assign BOUTCYCLENUM = bout_page_cycle_counter[14:2];

always @(posedge MCLK)
begin
    //리셋상태
    if(MCLK_counter == 10'd0)
    begin
        if(access_type == RST) //리셋 시
        begin
            BOUTCYCLENUM <= 13'd8191;

            bout_propagation_delay_counter <= 7'd127;

            bout_page_cycle_counter <= 10'd1023;

            bout_bootloop_cycle_counter <= bout_bootloop_cycle_counter;
        end
        else //그냥 다른 때는 그대로 유지
        begin
            BOUTCYCLENUM <= BOUTCYCLENUM;

            bout_propagation_delay_counter <= bout_propagation_delay_counter;

            bout_page_cycle_counter <= bout_page_cycle_counter;

            bout_bootloop_cycle_counter <= bout_bootloop_cycle_counter;
        end
    end

    //+Y에서 한번씩 체크
    else if(MCLK_counter == CYCLECOUNTER_TIMING) //magnetic field rotation activated
    begin
        if(access_type[1] == 1'b0) //IDLE 또는 SWAP: 실제로 데이터가 나가지 않음
        begin
            //empty propagation line
            BOUTCYCLENUM <= 13'd8191;

            //reset state
            bout_propagation_delay_counter <= 7'd127;

            //reset state
            bout_page_cycle_counter <= 10'd1023;

            //count up
            if(bout_bootloop_cycle_counter < 13'd4105)
            begin
                bout_bootloop_cycle_counter <= bout_bootloop_cycle_counter + 13'd1; //bootloop cycle counter는 계속 세기
            end
            else
            begin
                bout_bootloop_cycle_counter <= 13'd0;
            end
        end

        else //BOOT 또는 USER
        begin
            if(bout_propagation_delay_counter == 7'd127 || bout_propagation_delay_counter < 7'd97) //부트로더(초반 2비트가 씹힘)와 페이지 공히 첫 98싸이클 무효
            begin
                //empty propagation line
                BOUTCYCLENUM <= 13'd8191;

                //count up
                if(bout_propagation_delay_counter < 7'd127)
                begin
                    bout_propagation_delay_counter <= bout_propagation_delay_counter + 7'd1;
                end
                else
                begin
                    bout_propagation_delay_counter <= 7'd0;
                end

                //reset state
                bout_page_cycle_counter <= 10'd1023;

                //count up
                if(bout_bootloop_cycle_counter < 13'd4105)
                begin
                    bout_bootloop_cycle_counter <= bout_bootloop_cycle_counter + 13'd1; //bootloop cycle counter는 계속 세기
                end
                else
                begin
                    bout_bootloop_cycle_counter <= 13'd0;
                end
            end

            else //98사이클 지난 후부터
            begin
                if(access_type[0] == 1'b0) //BOOT 액세스,
                begin
                    //hold
                    bout_propagation_delay_counter <= bout_propagation_delay_counter;

                    //reset state
                    bout_page_cycle_counter <= 10'd1023;

                    //count up
                    if(bout_bootloop_cycle_counter < 13'd4105)
                    begin
                        bout_bootloop_cycle_counter <= bout_bootloop_cycle_counter + 13'd1; //bootloop cycle counter는 계속 세기
                        BOUTCYCLENUM <= bout_bootloop_cycle_counter + 13'd1;
                    end
                    else
                    begin
                        bout_bootloop_cycle_counter <= 13'd0;
                        BOUTCYCLENUM <= 13'd0;
                    end
                end
                else //USER 액세스
                begin
                    if(bout_page_cycle_counter == 10'd1023 || bout_page_cycle_counter < 10'd583) //페이지는 584-1 카운트
                    begin
                        //hold
                        bout_propagation_delay_counter <= bout_propagation_delay_counter;

                        //count up
                        if(bout_page_cycle_counter < 10'd583)
                        begin
                            bout_page_cycle_counter <= bout_page_cycle_counter + 10'd1;
                            BOUTCYCLENUM <= {3'b000, (bout_page_cycle_counter + 10'd1)};
                        end
                        else
                        begin
                            bout_page_cycle_counter <= 10'd0;
                            BOUTCYCLENUM <= 13'd0;
                        end

                        //count up
                        if(bout_bootloop_cycle_counter < 13'd4105)
                        begin
                            bout_bootloop_cycle_counter <= bout_bootloop_cycle_counter + 13'd1; //bootloop cycle counter는 계속 세기
                        end
                        else
                        begin
                            bout_bootloop_cycle_counter <= 13'd0;
                        end
                    end
                    else
                    begin
                        //hold
                        bout_propagation_delay_counter <= bout_propagation_delay_counter;

                        //hold
                        bout_page_cycle_counter <= bout_page_cycle_counter;

                        //count up
                        if(bout_bootloop_cycle_counter < 13'd4105)
                        begin
                            bout_bootloop_cycle_counter <= bout_bootloop_cycle_counter + 13'd1; //bootloop cycle counter는 계속 세기
                        end
                        else
                        begin
                            bout_bootloop_cycle_counter <= 13'd0;
                        end
                    end
                end
            end
        end
    end
end

//bubble output clock enable generator
always @(posedge MCLK)
begin
    //리셋상태
    if(MCLK_counter == 10'd0)
    begin
        nBOUTCLKEN <= 1'b0;
    end
    //버블 -Y에서 체크
    else if(MCLK_counter == OUTBUFFER_CLKEN_TIMING) //propagation delay보상을 위해 신호를 15ns정도 일찍 보내기; 오래된 기판의 경우 LS244가 느려짐
    begin
        nBOUTCLKEN <= 1'b0;
    end
    else
    begin
        nBOUTCLKEN <= 1'b1;
    end
end

//bubble output clock enable generator(for reference)
always @(posedge MCLK)
begin
    //리셋상태
    if(MCLK_counter == 10'd0)
    begin
        __REF_nBOUTCLKEN_ORIG <= 1'b1;
    end
    //버블 -Y에서 체크
    else if(MCLK_counter == 10'd328) //propagation delay보상을 위해 신호를 15ns정도 일찍 보내기; 오래된 기판의 경우 LS244가 느려짐
    begin
        __REF_nBOUTCLKEN_ORIG <= 1'b0;
    end
    else
    begin
        __REF_nBOUTCLKEN_ORIG <= 1'b1;
    end
end

//bubble input enable generator
always @(posedge MCLK)
begin
    //리셋상태
    if(MCLK_counter == 10'd0)
    begin
        nBINCLKEN <= 1'b1;
    end
    //버블 시작, +Y에서 한번씩 체크
    else if(MCLK_counter == 10'd88 || MCLK_counter == 10'd568) 
    begin
        nBINCLKEN <= 1'b0;   
    end
    else
    begin
        nBINCLKEN <= 1'b1;
    end
end

endmodule