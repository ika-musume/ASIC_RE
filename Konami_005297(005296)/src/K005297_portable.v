module K005297 (
    //master clock
    input   wire            i_MCLK,

    //chip clock from bubble cart, synchronized to i_MCLK
    input   wire            i_CLK4M_PCEN_n,

    //master reset
    input   wire            i_MRST_n,

    //data-address inputs(register RW)
    input   wire            i_REGCS_n,
    input   wire    [15:0]  i_DIN,
    input   wire    [2:0]   i_AIN, //A3, A2, A1
    input   wire            i_R_nW,
    input   wire            i_UDS_n,
    input   wire            i_LDS_n,
    input   wire            i_AS_n,

    //data-address outputs(DMA transfer)
    output  reg     [15:0]  o_DOUT,
    output  wire    [6:0]   o_AOUT, //A7-A1
    output  wire            o_R_nW,
    output  wire            o_UDS_n,
    output  wire            o_LDS_n,
    output  wire            o_AS_n,
    output  wire            o_ALE,

    //DMA control
    output  wire            o_BR_n,
    input   wire            i_BG_n,
    output  wire            o_BGACK_n,

    //CPU management
    output  wire            o_CPURST_n,
    output  wire            o_IRQ_n,

    //FC
    output  wire    [2:0]   o_FCOUT,
    input   wire    [2:0]   i_FCIN,

    //bubble side
    output  wire    [3:0]   o_BDOUT_n,
    input   wire    [3:0]   i_BDIN_n,
    output  wire            o_BOOTEN_n,
    output  wire            o_BSS_n,
    output  wire            o_BSEN_n,
    output  wire            o_REPEN_n,
    output  wire            o_SWAPEN_n,

    input   wire            i_TEMPLO_n,
    output  wire            o_HEATEN_n,

    input   wire            i_4BEN_n,

    //test?
    output  wire            o_INT1_ACK_n, //pin 30
    input   wire            i_TST1, //pin 20
    input   wire            i_TST2, //pin 21
    input   wire            i_TST3, //pin 22
    input   wire            i_TST4, //pin 23
    input   wire            i_TST5, //pin 24

    //bidirectional pin OE(internal)
    output  wire            o_CTRL_DMAIO_OE_n,
    output  wire            o_CTRL_DATA_OE_n
);

/*
    Verilog HDL model programmed by Sehyeon Kim(Raki), All .v source files in the K005297 directory are distributed as BSD-2.
    GitHub @ika-musume, Twitter @RCAVictorCo


    Konami 005296/005297 Bubble Memory Controller(BMC) cell level implementation based on the die shot below:

    Die shot: https://www.siliconpr0n.org/archive/doku.php?id=caps0ff:konami:005297

    Designed in 1984, 3um YAMAHA C2MOS gate array.


    Variations:
    005296: Comes with Bubble System 07A board, Ceramic Quad In-line Package(Centipede)
    005297: Comes with Bubble System 07E and 07F board, Plastic Shrinked Dual In-line Package(1.778 pitch)

    The main difference between the two is pinout of #1 and #64. These pins are swappable since they have two pads each.
    This chip uses dynamic CMOS cells heavily, hence the 2-phase clock generator with delay lines exists. 
    See clocking information on supervisor module. I can't believe it, but the delay cell seems to give about 240ns of delay. 
    Probably not. All flip-flops operating at 2MHz SUBCLK output data at the falling edge of 4MHz master clock.
    To meet this condition, the clock must be inverted, or put a delay of about 240ns.

    This model works at 4MHz. Use an external 74LVC1G14 for clock cleaning if you are going to make a hardware replacement.


                                   Konami 005296/005297 Pinout
                                        ┌───────U───────┐
                                        │    K005297    │
                                  D15 ──┤1  IO     IO 64├── Vdd   <--pin1 and 64 are swapped in K005296
                   ┌──────  BDO_D3/D1 ──┤2   O     IO 63├── D14
                   │        BDO_D2/D0 ──┤3   O     IO 62├── D13
                   │        BDO_D1    ──┤4   O     IO 61├── D12
               bitwidth     BDO_D0    ──┤5   O     IO 60├── D11
               4bit/2bit    BDI_D3/D1 ──┤6  I      IO 59├── D10
                   │        BDI_D2/D0 ──┤7  I      IO 58├── D9
                   │        BDI_D1    ──┤8  I      IO 57├── D8
                   └──────  BDI_D0    ──┤9  I      IO 56├── D7
                                 /BSS ──┤10  O     IO 55├── D6
                                /BSEN ──┤11  O     IO 54├── D5
                               /REPEN ──┤12  O     IO 53├── D4
                              /SWAPEN ──┤13  O     IO 52├── D3
                              /BOOTEN ──┤14  O     IO 51├── D2
                              /TEMPLO ──┤15 I      IO 50├── D1
                              /HEATEN ──┤16  O     IO 49├── D0
                                  Vss ──┤17         O 48├── ALE
                                CLK4M ──┤18 I       O 47├── A7
                                /4BEN ──┤19 I       O 46├── A6
                                 TST1 ──┤20 I       O 45├── A5
                                 TST2 ──┤21 I       O 44├── A4
                                 TST3 ──┤22 I      IO 43├── A3
                                 TST4 ──┤23 I      IO 42├── A2
                                 TST5 ──┤24 I      IO 41├── A1
                              /CPURST ──┤25  O     IO 40├── R/W
                                /MRST ──┤26 I      IO 39├── /LDS
                                  /BG ──┤27 I      IO 38├── /UDS
                               /BGACK ──┤28  O     IO 37├── FC2
                                  /BR ──┤29  O     IO 36├── FC1
                               /IACK1 ──┤30  O     IO 35├── FC0
                                 /IRQ ──┤31  O     IO 34├── /AS
                                  Vdd ──┤32        I  33├── /REGCS
                                        │               │
                                        └───────────────┘


    IMPLEMENTATION NOTE:


    20 Total latches - 4MHz master clock is too slow to sample any asynchronous write of the 68k @ 9.216MHz.

    Page Register(12)
    Asynchronous latches have been used. Data is always stabilized before the bubble RW command is written.

    Status Flags(6)
    BMC to CPU, unidirectional latces for flags.

    RW Command Register(2)
    Asynchronous latches have been used. There's a possibility of timing hazard on the signal path below:

        RW CMD reg(latch) -> PLA FSM(comb) -> PLA output register(DFF)

    The original chip used D-latches for PLA output register. I used two 8bit width DFF sets that act as
    a synchronizer. The primary one samples PLA output at negedge of ROT20_n[10], and the secondary one
    samples the primary's output at posedge of ROT20_n[10]. Metastability risks still remain, but the 
    interval between two consecutive positive edge is 500ns(2MHz), so it is unlikely to be a major problem.
    -----------------


    Wrong decoder

    I fixed wrong output decoder that always causes internal bus contention. See ADDRESS DECODER section
    -----------------


    ASIC-ish combinational loops and tricks

    Cut some combinational loops. See comments.
    -----------------
*/


///////////////////////////////////////////////////////////
//////  GLOBAL CLOCKS / FLAGS
////

//all stoarge elements works at falling edge of 4M/2M
//Use LVC1G14 for hardware replacement implementation
wire            CLK4P_n = i_CLK4M_PCEN_n;   //4MHz clock from bubble memory cartridge 12MHz/3
wire            CLK2P_n;                    //2MHz internal subclock that can be controlled by start/stop logic

//global flags
wire            SYS_RST_n;
wire            SYS_RUN_FLAG, SYS_RUN_FLAG_SET_n;

//timings
wire    [7:0]   ROT8;
wire    [19:0]  ROT20_n;

assign  o_FCOUT = 3'b101; //clip cells
assign  o_CPURST_n = o_BOOTEN_n; //C28 NAND, CPURST_n = BOOTEN_n



///////////////////////////////////////////////////////////
//////  SUPERVISOR MODULE
////

wire            SYS_RUN_FLAG_RST_n;
wire            FSMERR_RESTART_n, BOOTERR_RESTART_n;
wire            CLK2M_STOP_n, CLK2M_STOP_DLYD_n; //for tempdet

K005297_supervisor supervisor_main (
    .i_MCLK                     (i_MCLK                     ),

    .i_CLK4M_PCEN_n             (CLK4P_n                    ),

    .i_MRST_n                   (i_MRST_n                   ),

    .i_HALT_n                   (i_TST1                     ),

    .i_CLK2M_STOPRQ0_n          (FSMERR_RESTART_n           ),
    .i_CLK2M_STOPRQ1_n          (BOOTERR_RESTART_n          ),
    .o_CLK2M_STOP_n             (CLK2M_STOP_n               ),
    .o_CLK2M_STOP_DLYD_n        (CLK2M_STOP_DLYD_n          ),
    .o_CLK2M_PCEN_n             (CLK2P_n                    ),

    .o_ROT8                     (ROT8                       ),
    .o_ROT20_n                  (ROT20_n                    ),

    .o_SYS_RST_n                (SYS_RST_n                  ),
    .o_SYS_RUN_FLAG             (SYS_RUN_FLAG               ),
    .o_SYS_RUN_FLAG_SET_n       (SYS_RUN_FLAG_SET_n         )       
);



///////////////////////////////////////////////////////////
//////  INTERCONNECTS
////

//delayed ~ROT20_n[18] ...why not D19?
reg             rot20_d18_dlyd1, rot20_d18_dlyd2;
always @(posedge i_MCLK) begin
    if(!CLK2P_n) begin
        rot20_d18_dlyd1 <= ~ROT20_n[18];
        rot20_d18_dlyd2 <= rot20_d18_dlyd1;
    end
end

//FSM
wire            BDI_EN_SET_n, BDI_EN_RST_n;
wire            CMDREG_RST_n;
wire            ACC_START;
wire            PGREG_SR_LD_EN;
wire            CMD_ACCEPTED_n;

//bubble related
wire            BDI, BDI_EN; //bubble input stream

//Synchronization Pattern Detector(K005297_SPDET)
wire            SYNCTIP_n, SYNCED_FLAG, SYNCED_FLAG_SET_n;

//Cycle Counter
wire            CYCLECNTR_LSB;

//Function Trigger
wire            ACC_END, REP_START, SWAP_START, ACQ_START, ADDR_RST;  

//Error Map(mask) Register
wire            MSKREG_LD, MSKREG_SR_LD, MSKREG_SR_LSB;

//Supplementary Bubble Data Counter
wire            SUPBD_START_n, SUPBD_END_n, SUPBD_ACT_n, SUPBDLCNTR_CNT;

//Data Length Counter
wire            DLCNTR_LSB, DLCNTR_CFLAG;

//Byte Acquisition Counter
wire            NEWBYTE, BYTEACQ_DONE;

//Relative Page Counter
wire            ABSPGCNTR_CNT_START, ABSPGCNTR_CNT_STOP, ABSPGCNTR_LSB;

//Page Comparator
wire            PGCMP_EQ;

//Invalid Page Detector
wire            ACC_INVAL_n, VALPG_FLAG_SET_n;

//Page Register
wire            PGREG_SR_SHIFT, PGREG_SR_LSB, PGREG_D2, PGREG_D8;

//Invalid Page Data Generator(data scrambler)
wire            MUXED_BDI, EFF_MUXED_BDI;

//DMA Data Register Load Control
wire            DMADREG_BDHI_LD, DMADREG_BDLO_LD;

//DMA Timings
wire            BR_START_n, DMA_END, DMA_WORD_END, DMA_WR_ACT_n, MSKADDR_INC, DMADREG_BDHILO_LD;

//DMA Frontend
wire            DMA_ACT;
assign          o_CTRL_DMAIO_OE_n = ~DMA_ACT;

//Bus Control Frontend
wire            DMA_R_nW; //DMA Read/Write Indicator

//DMA Data Register
wire            BDRWADDR_INC, EFF_BDO;

//Z14 Evaluator(CRC-14)
wire            MUXED_BDO, Z14_UNLOCK_n, Z14_LOCKED_n;

//Timer 25k
wire            TIMER25K_CNT, TIMER25K_OUTLATCH_LD_n, TIMER25K_TIMEOVER_n;

//Checksum Comparator
wire            SUMEQ_n, INVALPG_LSB;

//Temperature Detector
wire            TEMPDROP_SET_n;

//Address Decoder 
//read-only register data
wire    [15:0]  DMATXREG;      //0x40000
wire    [3:0]   TIMERREG_MSBS;
wire    [11:0]  TIMERREG_LSBS; //0x40002
wire    [15:0]  STFLAG;        //0x40004
//write-only register enables   
wire            ASYNC_LATCH_EN__PGREG_LD, ASYNC_LATCH_EN__CMDREG_WR_EN, ASYNC_LATCH_EN__STFLAG_CLR;

//Data Output Mux
wire            ALD_EN; //address latch data enable

wire    [3:0]   ALD_DMABD; //address latch data for bubble data transfer
wire            ALD_DMAMSK; //for mask data(error map)

reg     [15:0]  INTLBUS;       //When reading 0x40002, there's bus contention with 0x40000 caused by a defect in the decoder design
                               //The chip gets hot but seems to work well. I think polysilicon acts as a resistor because there's 
                               //only one metal layer on this die.



///////////////////////////////////////////////////////////
//////  ACCESS MODE FLAG
////

wire            UMODE_SET_n;
wire            UMODE_n, BMODE_n;
wire            ALD_nB_U;

K005297_accmodeflag accmodeflag_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),
    .i_SYS_RUN_FLAG             (SYS_RUN_FLAG               ),

    .i_CMDREG_RST_n             (CMDREG_RST_n               ),
    .i_BDI_EN_SET_n             (BDI_EN_SET_n               ),
    .i_SYNCED_FLAG_SET_n        (SYNCED_FLAG_SET_n          ),

    .o_BMODE_n                  (BMODE_n                    ),
    .o_UMODE_n                  (UMODE_n                    ),
    .o_ALD_nB_U                 (ALD_nB_U                   ),
    .o_UMODE_SET_n              (UMODE_SET_n                )
);



///////////////////////////////////////////////////////////
//////  ABSOLUTE PAGE COUNTER CONTROL
////

reg             abspgcntr_ctrl_0, abspgcntr_ctrl_1;
always @(posedge i_MCLK) begin
    if(!CLK2P_n) begin  
        abspgcntr_ctrl_0 <= (ROT20_n[16] == 1'b0) ? (((o_HEATEN_n & UMODE_n) | ACC_START) & SYS_RST_n) : (abspgcntr_ctrl_0 & SYS_RST_n);
        abspgcntr_ctrl_1 <= (ROT20_n[4] == 1'b0) ? (abspgcntr_ctrl_0 & SYS_RST_n) : (abspgcntr_ctrl_1 & SYS_RST_n);
    end
end

assign          ABSPGCNTR_CNT_START = abspgcntr_ctrl_0 & ~abspgcntr_ctrl_1;
assign          ABSPGCNTR_CNT_STOP = ~(~(ACC_END & ~ROT20_n[17]) & (o_CPURST_n | UMODE_SET_n));



///////////////////////////////////////////////////////////
//////  MISC CONTROL SIGNALS AND FLAGS
////

//Access Activated
wire            ACC_ACT_n;
SRNAND primitive_E24 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(SUPBD_END_n), .i_R_n(~(ACQ_START & rot20_d18_dlyd2)), .o_Q(ACC_ACT_n), .o_Q_n());

//Acquisition: Mask Load
reg             ACQ_MSK_LD = 1'b0; //this sr latch's outer circuit has a combinational loop
always @(posedge i_MCLK) begin
    if(SYS_RST_n == 1'b0) begin //synchronous reset(SR latch originally)
        ACQ_MSK_LD <= 1'b0;
    end
    else begin
        if(!CLK2P_n) begin
            if(ROT20_n[19] == 1'b0) begin //SR latch's reset works @ ROT20[0], ACQ_START_D0, ACQ-START is always asserted before ROT20[0]
                if(ACQ_START == 1'b1) begin
                    ACQ_MSK_LD <= 1'b1;
                end
            end
            else if(ROT20_n[1] == 1'b0) begin //ACQ_MSK_LD changes @ ROT20[0], MSKREG_SR_LD changes @ ROT20[3] or [18]
                if(ACQ_MSK_LD & MSKREG_SR_LD == 1'b1) begin
                    ACQ_MSK_LD <= 1'b0;
                end
            end
            else begin
                ACQ_MSK_LD <= ACQ_MSK_LD;
            end
        end
    end
end

//ACQ_MSK_LD delayed
reg             acq_msk_ld_dlyd = 1'b0;
always @(posedge i_MCLK) begin
    if(SYS_RST_n == 1'b0) begin //synchronous reset(SR latch originally)
        acq_msk_ld_dlyd <= 1'b0;
    end
    else begin
        if(!CLK2P_n) begin
            if(ROT20_n[15] == 1'b0) begin
                if(ACQ_MSK_LD == 1'b1) begin
                    acq_msk_ld_dlyd <= 1'b1;
                end
            end
            else if(ROT20_n[1] == 1'b0) begin
                if(ACQ_MSK_LD & MSKREG_SR_LD == 1'b1) begin
                    acq_msk_ld_dlyd <= 1'b0;
                end
            end
            else begin
                acq_msk_ld_dlyd <= acq_msk_ld_dlyd;
            end
        end
    end
end


//SRNAND primitive_J62 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(~((ACQ_MSK_LD & MSKREG_SR_LD & ~ROT20_n[2]) | ~SYS_RST_n)), .i_R_n(~(ACQ_MSK_LD & ~ROT20_n[16])), .o_Q(), .o_Q_n(acq_msk_ld_dlyd));

wire            BUBWR_WAIT = acq_msk_ld_dlyd & ~BDI_EN;
wire            GLCNT_RD =  (BUBWR_WAIT | MSKREG_SR_LSB | ~o_BOOTEN_n) &
                           ~(ROT20_n[2] & ROT20_n[7] & ~(~(ROT20_n[12] & ROT20_n[17]) & ~i_4BEN_n)); //0-5_10-15

//Data Length Counter
wire            DLCNT_EN;
wire            DLCNT_START_n = ~(ACQ_MSK_LD & rot20_d18_dlyd1);

//Z14 Flag related?
wire            Z14_n;
wire            Z14_ERR_n = ~Z14_n | SUPBD_END_n | ~BDI_EN;

reg             supbd_act_n_dlyd;
assign          BOOTERR_RESTART_n = BMODE_n | supbd_act_n_dlyd | Z14_ERR_n;
always @(posedge i_MCLK) begin
    if(!CLK2P_n) begin
        supbd_act_n_dlyd <= SUPBD_ACT_n;
    end
end

//Operation Done flag
wire            OP_DONE_SET_n = ((BDI_EN | SUPBD_END_n) & BOOTERR_RESTART_n) & (Z14_n | SUPBD_END_n | ~BDI_EN);
wire            OP_DONE;
SRNAND primitive_F25 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(BDI_EN_SET_n & SYS_RUN_FLAG), .i_R_n(OP_DONE_SET_n), .o_Q(), .o_Q_n(OP_DONE));

//Error flag
wire            SYS_ERR_FLAG;
SRNAND primitive_I31 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(BDI_EN_SET_n), .i_R_n(~(ABSPGCNTR_CNT_STOP & ~BDI_EN) & Z14_ERR_n & SYS_RUN_FLAG), .o_Q(), .o_Q_n(SYS_ERR_FLAG));

//Bubble Data Out flag
reg             supbd_act_dlyd;
always @(posedge i_MCLK) begin
    if(!CLK2P_n) begin
        supbd_act_dlyd <= ~SUPBD_ACT_n;
    end
end

wire            bdo_en_reset_n = ~((supbd_act_dlyd & rot20_d18_dlyd1) | ~SYS_RST_n);
wire            BDO_EN_n, MUXED_BDO_EN;
wire            EFFBDO_EN = MUXED_BDO_EN & SUPBD_ACT_n;
SRNAND primitive_J43 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(bdo_en_reset_n), .i_R_n(DLCNT_START_n), .o_Q(BDO_EN_n), .o_Q_n(MUXED_BDO_EN));

wire            MUXED_BDO_EN_DLYD;
wire            SUPBDO_EN_n = MUXED_BDO_EN_DLYD | SUPBD_ACT_n; //J35 NAND demorgan
SRNAND primitive_J36 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(~((BDO_EN_n & ~ROT20_n[14]) | ~SYS_RST_n)), .i_R_n(DLCNT_START_n), .o_Q(), .o_Q_n(MUXED_BDO_EN_DLYD));

//DMA Data Register Control
wire            DMADREG_SHIFT = ~(~(~BYTEACQ_DONE | BDI_EN) | BUBWR_WAIT);
wire            DMADREG_BDLD_EN = ~(ROT20_n[0] & ROT20_n[5] & ~(~(ROT20_n[10] & ROT20_n[15]) & ~i_4BEN_n)) & BYTEACQ_DONE;

//Valid Page Access flag/Cycle Counter Enable
wire            VALPG_ACC_FLAG;
SRNAND primitive_H32 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(~((ACC_END | ~SYS_RUN_FLAG) & ~ROT20_n[1])), .i_R_n(VALPG_FLAG_SET_n), .o_Q(), .o_Q_n(VALPG_ACC_FLAG));

wire            CYCLECNTR_EN;
SRNAND primitive_H30 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(~((ACC_END | ~SYS_RUN_FLAG) & ~ROT20_n[1])), .i_R_n(~(~o_BSEN_n & PGCMP_EQ & ~ROT20_n[7])), .o_Q(), .o_Q_n(CYCLECNTR_EN));



///////////////////////////////////////////////////////////
//////  BUBBLE IO FRONTEND
////

//BUBBLE CONTROL FRONTEND
K005297_bubctrlfe bubctrlfe_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),
    .i_SYS_RUN_FLAG_SET_n       (SYS_RUN_FLAG_SET_n         ),

    .i_ABSPGCNTR_CNT_START      (ABSPGCNTR_CNT_START        ),
    .i_ABSPGCNTR_CNT_STOP       (ABSPGCNTR_CNT_STOP         ),
    .i_VALPG_ACC_FLAG           (VALPG_ACC_FLAG             ),
    .i_BMODE_n                  (BMODE_n                    ),
    .i_REP_START                (REP_START                  ),
    .i_SWAP_START               (SWAP_START                 ),

    .o_BOOTEN_n                 (o_BOOTEN_n                 ),
    .o_BSS_n                    (o_BSS_n                    ),
    .o_BSEN_n                   (o_BSEN_n                   ),
    .o_REPEN_n                  (o_REPEN_n                  ),
    .o_SWAPEN_n                 (o_SWAPEN_n                 )
);

//BUBBLE READ FRONTEND
K005297_bubrdfe bubrdfe_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_4BEN_n                   (i_4BEN_n                   ),
    .i_BDI_EN_SET_n             (BDI_EN_SET_n               ),
    .i_BDI_EN_RST_n             (BDI_EN_RST_n               ),
    .i_BDIN_n                   (i_BDIN_n                   ),

    .o_BDI                      (BDI                        ),
    .o_BDI_EN                   (BDI_EN                     )
);

//BUBBLE WRITE FRONTEND
K005297_bubwrfe bubwrfe_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_TST                      (i_TST5                     ),
    .i_4BEN_n                   (i_4BEN_n                   ),

    .i_MUXED_BDO                (MUXED_BDO                  ),
    .i_MUXED_BDO_EN             (MUXED_BDO_EN               ),
    .i_SUPBD_END_n              (SUPBD_END_n                ),

    .o_BDOUT_n                  (o_BDOUT_n                  ),

    .i_ABSPGCNTR_LSB            (ABSPGCNTR_LSB              ),
    .i_PGREG_SR_LSB             (PGREG_SR_LSB               ),
    .i_DLCNTR_LSB               (DLCNTR_LSB                 ),
    .i_CYCLECNTR_LSB            (CYCLECNTR_LSB              )
);



///////////////////////////////////////////////////////////
//////  SYNCHRONIZATION PATTERN DETECTOR
////

K005297_spdet spdet_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_BDI                      (BDI                        ),
    .i_GLCNT_RD                 (GLCNT_RD                   ),
    .i_BOOTEN_n                 (o_BOOTEN_n                 ),
    .i_BSEN_n                   (o_BSEN_n                   ),
    .i_4BEN_n                   (i_4BEN_n                   ),

    .o_SYNCTIP_n                (SYNCTIP_n                  ),
    .o_SYNCED_FLAG              (SYNCED_FLAG                ),
    .o_SYNCED_FLAG_SET_n        (SYNCED_FLAG_SET_n          )
);



///////////////////////////////////////////////////////////
//////  CYCLE COUNTER
////

K005297_cyclecntr cyclecntr_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_CYCLECNTR_EN             (CYCLECNTR_EN               ),
    .o_CYCLECNTR_LSB            (CYCLECNTR_LSB              )
);



///////////////////////////////////////////////////////////
//////  FUNCTION TRIGGER
////

K005297_functrig functrig_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_HALT                     (i_TST4                     ),
    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_UMODE_n                  (UMODE_n                    ),
    .i_CYCLECNTR_LSB            (CYCLECNTR_LSB              ),
    .i_ACC_INVAL_n              (ACC_INVAL_n                ),
    .i_PGCMP_EQ                 (PGCMP_EQ                   ),
    .i_SYNCTIP_n                (SYNCTIP_n                  ),
    .i_BDI_EN                   (BDI_EN                     ),

    .o_ACC_END                  (ACC_END                    ),
    .o_SWAP_START               (SWAP_START                 ),
    .o_ACQ_START                (ACQ_START                  ),
    .o_ADDR_RST                 (ADDR_RST                   )
);



///////////////////////////////////////////////////////////
//////  MASK LOAD TIMER
////

K005297_mskldtimer mskldtimer_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_4BEN_n                   (i_4BEN_n                   ),
    .i_ACC_ACT_n                (ACC_ACT_n                  ),
    .i_ACQ_MSK_LD               (ACQ_MSK_LD                 ),

    .o_MSKREG_SR_LD             (MSKREG_SR_LD               )
);



///////////////////////////////////////////////////////////
//////  MASK(ERROR MAP) REGISTER
////

K005297_mskreg mskreg_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_4BEN_n                   (i_4BEN_n                   ),
    .i_MSKREG_LD                (MSKREG_LD                  ),
    .i_MSKREG_SR_LD             (MSKREG_SR_LD               ),
    .i_BOOTEN_n                 (o_BOOTEN_n                 ),

    .i_DIN                      (i_DIN                      ),

    .o_MSKREG_SR_LSB            (MSKREG_SR_LSB              )
);



///////////////////////////////////////////////////////////
//////  DATA LENGTH COUNTER
////

K005297_dlcntr dlcntr_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_DLCNT_START_n            (DLCNT_START_n              ),
    .i_SUPBD_START_n            (SUPBD_START_n              ),
    .i_DLCNT_EN                 (DLCNT_EN                   ),

    .o_DLCNTR_LSB               (DLCNTR_LSB                 ),
    .o_DLCNTR_CFLAG             (DLCNTR_CFLAG               )
);



///////////////////////////////////////////////////////////
//////  BYTE ACQUISITION COUNTER
////

K005297_byteacqcntr byteacqcntr_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_4BEN_n                   (i_4BEN_n                   ),
    .i_ACC_ACT_n                (ACC_ACT_n                  ),
    .i_GLCNT_RD                 (GLCNT_RD                   ),

    .i_NEWBYTE                  (NEWBYTE                    ),
    .i_BUBWR_WAIT               (BUBWR_WAIT                 ),
    
    .o_BYTEACQ_DONE             (BYTEACQ_DONE               )
);



///////////////////////////////////////////////////////////
//////  DATA LENGTH EVALUATOR
////

K005297_dleval dleval_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_TST                      (i_TST2                     ),
    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_4BEN_n                   (i_4BEN_n                   ),
    .i_UMODE_n                  (UMODE_n                    ),
    .i_DLCNTR_LSB               (DLCNTR_LSB                 ),
    .i_DLCNTR_CFLAG             (DLCNTR_CFLAG               ),

    .i_BYTEACQ_DONE             (BYTEACQ_DONE               ),
    .i_SUPBD_END_n              (SUPBD_END_n                ),

    .o_SUPBD_START_n            (SUPBD_START_n              )
);



///////////////////////////////////////////////////////////
//////  SUPPLEMENTARY BUBBLE DATA LENGTH COUNTER
////

K005297_supbdlcntr supbdlcntr_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RUN_FLAG             (SYS_RUN_FLAG               ),

    .i_4BEN_n                   (i_4BEN_n                   ),
    .i_BDI_EN                   (BDI_EN                     ),
    .i_SUPBD_START_n            (SUPBD_START_n              ),
    .i_MSKREG_SR_LSB            (MSKREG_SR_LSB              ),
    .i_GLCNT_RD                 (GLCNT_RD                   ),

    .o_SUPBDLCNTR_CNT           (SUPBDLCNTR_CNT             ),
    .o_SUPBD_ACT_n              (SUPBD_ACT_n                ),
    .o_SUPBD_END_n              (SUPBD_END_n                )
);



///////////////////////////////////////////////////////////
//////  PAGE REGISTER
////

K005297_pgreg pgreg_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_PGREG_LD                 (ASYNC_LATCH_EN__PGREG_LD   ),
    .i_PGREG_SR_LD_EN           (PGREG_SR_LD_EN             ),
    .o_PGREG_SR_SHIFT           (PGREG_SR_SHIFT             ),

    .i_DIN                      (i_DIN                      ),

    .o_PGREG_D2                 (PGREG_D2                   ),
    .o_PGREG_D8                 (PGREG_D8                   ),
    .o_PGREG_SR_LSB             (PGREG_SR_LSB               )
);



///////////////////////////////////////////////////////////
//////  ABSOLUTE PAGE COUNTER
////

K005297_abspgcntr abspgcntr_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_ABSPGCNTR_CNT_STOP       (ABSPGCNTR_CNT_STOP         ),
    .i_ABSPGCNTR_CNT_START      (ABSPGCNTR_CNT_START        ),
    .i_ALD_nB_U                 (ALD_nB_U                   ),
    .o_ABSPGCNTR_LSB            (ABSPGCNTR_LSB              )
);



///////////////////////////////////////////////////////////
//////  PAGE COMPARATOR
////

K005297_pgcmp pgcmp_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_BDI_EN                   (BDI_EN                     ),
    .i_PGREG_SR_LSB             (PGREG_SR_LSB               ),
    .i_ABSPGCNTR_LSB            (ABSPGCNTR_LSB              ),
    .i_UMODE_n                  (UMODE_n                    ),

    .o_PGCMP_EQ                 (PGCMP_EQ                   )
);



///////////////////////////////////////////////////////////
//////  INVALID PAGE DETECTOR
////

K005297_invalpgdet invalpgdet_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_TST                      (i_TST3                     ),
    .i_PGREG_SR_LSB             (PGREG_SR_LSB               ),
    .i_INVALPG_LSB              (INVALPG_LSB                ),
    .i_UMODE_n                  (UMODE_n                    ),
    .i_PGCMP_EQ                 (PGCMP_EQ                   ),

    .o_ACC_INVAL_n              (ACC_INVAL_n                ),
    .o_VALPG_FLAG_SET_n         (VALPG_FLAG_SET_n           )
);



///////////////////////////////////////////////////////////
//////  DMA OUTLATCH LOAD CONTROL
////

K005297_dmadregldctrl dmadregldctrl_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_4BEN_n                   (i_4BEN_n                   ),
    .i_BDI_EN                   (BDI_EN                     ),
    .i_UMODE_n                  (UMODE_n                    ),

    .i_ACQ_MSK_LD               (ACQ_MSK_LD                 ),
    .i_MSKREG_SR_LD             (MSKREG_SR_LD               ),
    .i_BYTEACQ_DONE             (BYTEACQ_DONE               ),
    .i_GLCNT_RD                 (GLCNT_RD                   ),

    .i_ACQ_START                (ACQ_START                  ),
    .i_SUPBD_START_n            (SUPBD_START_n              ),
    .i_VALPG_FLAG_SET_n         (VALPG_FLAG_SET_n           ),

    .i_PGREG_SR_LSB             (PGREG_SR_LSB               ),
    .i_DLCNTR_LSB               (DLCNTR_LSB                 ),

    .i_DMA_WORD_END             (DMA_WORD_END               ),

    .o_NEWBYTE                  (NEWBYTE                    ),
    .o_DLCNT_EN                 (DLCNT_EN                   ),
    .o_DMADREG_BDHI_LD          (DMADREG_BDHI_LD            ),
    .o_DMADREG_BDLO_LD          (DMADREG_BDLO_LD            )
);



///////////////////////////////////////////////////////////
//////  DMA TIMINGS
////

K005297_dmatiming dmatiming_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT8                     (ROT8                       ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_UMODE_n                  (UMODE_n                    ),
    .i_ACC_ACT_n                (ACC_ACT_n                  ),
    .i_DMA_ACT                  (DMA_ACT                    ),
    .i_BDI_EN                   (BDI_EN                     ),
    .i_MSKREG_SR_LD             (MSKREG_SR_LD               ),
    .i_ACQ_MSK_LD               (ACQ_MSK_LD                 ),
    .i_ACQ_START                (ACQ_START                  ),
    .i_SUPBDO_EN_n              (SUPBDO_EN_n                ),
    .i_DMADREG_BDLO_LD          (DMADREG_BDLO_LD            ),

    .o_BR_START_n               (BR_START_n                 ),
    .o_DMA_END                  (DMA_END                    ),
    .o_DMA_WORD_END             (DMA_WORD_END               ),
    .o_MSKREG_LD                (MSKREG_LD                  ),
    .o_MSKADDR_INC              (MSKADDR_INC                ),
    .o_DMADREG_BDHILO_LD        (DMADREG_BDHILO_LD          ),
    .o_DMA_WR_ACT_n             (DMA_WR_ACT_n               )
);



///////////////////////////////////////////////////////////
//////  DMA FRONTEND
////

K005297_dmafe dmafe_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT8                     (ROT8                       ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_CPURST_n                 (o_CPURST_n                 ),
    .i_AS_n                     (i_AS_n                     ),
    .i_BG_n                     (i_BG_n                     ),
    .o_BR_n                     (o_BR_n                     ),
    .o_BGACK_n                  (o_BGACK_n                  ),

    .i_BR_START_n               (BR_START_n                 ),
    .i_DMA_END                  (DMA_END                    ),

    .o_ALD_EN                   (ALD_EN                     ),
    .o_DMA_ACT                  (DMA_ACT                    )
);



///////////////////////////////////////////////////////////
//////  BUS CONTROL FRONTEND
////

//Address Latch Enable
assign          o_ALE = DMA_ACT & ROT8[1];

K005297_busctrlfe busctrlfe_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT8                     (ROT8                       ),

    .i_DMA_ACT                  (DMA_ACT                    ),
    .i_DMA_WR_ACT_n             (DMA_WR_ACT_n               ),
    .o_DMA_R_nW                 (DMA_R_nW                   ),

    .o_UDS_n                    (o_UDS_n                    ),
    .o_LDS_n                    (o_LDS_n                    ),
    .o_AS_n                     (o_AS_n                     ),
    .o_R_nW                     (o_R_nW                     )
);



///////////////////////////////////////////////////////////
//////  INVALID PAGE DATA GENERATOR(DATA SCRAMBLER)
////

K005297_invalpgdgen invalpgdgen_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_PGREG_D2                 (PGREG_D2                   ),
    .i_PGREG_D8                 (PGREG_D8                   ),

    .i_EFFBDO_EN                (EFFBDO_EN                  ),
    .i_BDO_EN_n                 (BDO_EN_n                   ),
    .i_GLCNT_RD                 (GLCNT_RD                   ),

    .i_VALPG_ACC_FLAG           (VALPG_ACC_FLAG             ),
    .i_UMODE_n                  (UMODE_n                    ),
    .i_SUPBD_ACT_n              (SUPBD_ACT_n                ),
    .i_SYNCED_FLAG              (SYNCED_FLAG                ),
    .i_ALD_nB_U                 (ALD_nB_U                   ),

    .i_BDI                      (BDI                        ),
    .o_MUXED_BDI                (MUXED_BDI                  ),
    .o_EFF_MUXED_BDI            (EFF_MUXED_BDI              )
);



///////////////////////////////////////////////////////////
//////  DMA DATA REGISTER
////

K005297_dmadreg dmadreg_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT8                     (ROT8                       ),

    .i_DMADREG_SHIFT            (DMADREG_SHIFT              ),
    .i_DMADREG_BDLD_EN          (DMADREG_BDLD_EN            ),
    .i_DMADREG_BDHI_LD          (DMADREG_BDHI_LD            ),
    .i_DMADREG_BDLO_LD          (DMADREG_BDLO_LD            ),
    .i_DMADREG_BDHILO_LD        (DMADREG_BDHILO_LD          ),

    .i_DMA_ACT                  (DMA_ACT                    ),
    .i_BDI_EN                   (BDI_EN                     ),
    .i_GLCNT_RD                 (GLCNT_RD                   ),

    .o_BDRWADDR_INC             (BDRWADDR_INC               ),

    .i_MUXED_BDI                (BDI                        ),
    .o_DMATXREG                 (DMATXREG                   ),

    .o_EFF_BDO                  (EFF_BDO                    ),
    .i_DIN                      (16'h0AF5                   )
);



///////////////////////////////////////////////////////////
//////  DMA ADDRESS COUNTER
////

K005297_dmaaddrcntr dmaaddrcntr_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT8                     (ROT8                       ),

    .i_ALD_nB_U                 (ALD_nB_U                   ),
    .i_ADDR_RST                 (ADDR_RST                   ),
    .i_BDRWADDR_INC             (BDRWADDR_INC               ),
    .i_MSKADDR_INC              (MSKADDR_INC                ),

    .o_AOUT                     (o_AOUT                     ),
    .o_ALD_DMABD                (ALD_DMABD                  ),
    .o_ALD_DMAMSK               (ALD_DMAMSK                 )
);



///////////////////////////////////////////////////////////
//////  Z14(CRC14) checker
////

//CRC14 Polynomial = X^14 + X^5 + X^4 + 1

K005297_z14eval z14eval_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_SYS_RST_n                (SYS_RST_n                  ),

    .i_TIMER25K_TIMEOVER_n      (TIMER25K_TIMEOVER_n        ),
    .i_Z14_ERR_n                (Z14_ERR_n                  ),

    .o_Z14_UNLOCK_n             (Z14_UNLOCK_n               ),
    .o_Z14_LOCKED_n             (Z14_LOCKED_n               ),

    .i_BDI_EN                   (BDI_EN                     ),

    .i_SUPBD_ACT_n              (SUPBD_ACT_n                ),
    .i_SUPBD_END_n              (SUPBD_END_n                ),

    .i_DLCNT_START_n            (DLCNT_START_n              ),
    .i_SUPBDLCNTR_CNT           (SUPBDLCNTR_CNT             ),
    .i_ACQ_START                (ACQ_START                  ),

    .i_MSKREG_SR_LSB            (MSKREG_SR_LSB              ),

    .i_BDI                      (BDI                        ),
    .i_EFF_BDO                  (EFF_BDO                    ),
    .o_MUXED_BDO                (MUXED_BDO                  ),

    .o_TIMER25K_CNT             (TIMER25K_CNT               ),
    .o_TIMER25K_OUTLATCH_LD_n   (TIMER25K_OUTLATCH_LD_n     ),

    .o_Z14_n                    (Z14_n                      ),
    .o_Z11_d13_n                (                           ),
    .o_TIMERREG_MSBS            (TIMERREG_MSBS              )
);



///////////////////////////////////////////////////////////
//////  TIMER25K
////

K005297_timer25k timer25k_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_TIMER25K_CNT             (TIMER25K_CNT               ),
    .i_TIMER25K_OUTLATCH_LD_n   (TIMER25K_OUTLATCH_LD_n     ),
    .o_TIMER25K_TIMEOVER_n      (TIMER25K_TIMEOVER_n        ),

    .o_TIMERREG_LSBS            (TIMERREG_LSBS              )
);



///////////////////////////////////////////////////////////
//////  CHECKSUM COMPARATOR
////

K005297_sumcmp sumcmp_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_EFF_MUXED_BDI            (EFF_MUXED_BDI              ),

    .i_UMODE_n                  (UMODE_n                    ),
    .i_BDO_EN_n                 (BDO_EN_n                   ),
    .i_EFFBDO_EN                (EFFBDO_EN                  ),
    .i_GLCNT_RD                 (GLCNT_RD                   ),
    .i_PGREG_SR_SHIFT           (PGREG_SR_SHIFT             ),
    .i_DMADREG_BDLD_EN          (DMADREG_BDLD_EN            ),

    .i_MUXED_BDO_EN_DLYD        (MUXED_BDO_EN_DLYD          ),
    .i_SUPBD_ACT_n              (SUPBD_ACT_n                ),
    .i_ALD_nB_U                 (ALD_nB_U                   ),

    .o_INVALPG_LSB              (INVALPG_LSB                ),
    .o_SUMEQ_n                  (SUMEQ_n                    )
);



///////////////////////////////////////////////////////////
//////  TEMPERATURE DETECTOR
////

K005297_tempdet tempdet_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),

    .i_TEMPLO_n                 (i_TEMPLO_n                 ),
    .i_CLK2M_STOP_n             (CLK2M_STOP_n               ),
    .i_CLK2M_STOP_DLYD_n        (CLK2M_STOP_DLYD_n          ),

    .o_TEMPDROP_SET_n           (TEMPDROP_SET_n             ),
    .o_HEATEN_n                 (o_HEATEN_n                 )
);



///////////////////////////////////////////////////////////
//////  RW COMMAND REGISTER
////


wire            CMDREG_RDREQ_n, CMDREG_WRREQ_n;
ASYNCDL primitive_N33 (.i_SET(~(CMDREG_RST_n & SYS_RUN_FLAG)), .i_EN(ASYNC_LATCH_EN__CMDREG_WR_EN), .i_D(~i_DIN[0]), .o_Q(CMDREG_RDREQ_n));
ASYNCDL primitive_N31 (.i_SET(~(CMDREG_RST_n & SYS_RUN_FLAG)), .i_EN(ASYNC_LATCH_EN__CMDREG_WR_EN), .i_D(~i_DIN[1]), .o_Q(CMDREG_WRREQ_n));



///////////////////////////////////////////////////////////
//////  FSM
////

K005297_fsm fsm_main (
    .i_MCLK                     (i_MCLK                     ),
    .i_CLK4M_PCEN_n             (CLK4P_n                    ),
    .i_CLK2M_PCEN_n             (CLK2P_n                    ),
    .i_ROT20_n                  (ROT20_n                    ),

    .i_CMDREG_RDREQ             (~CMDREG_RDREQ_n            ),
    .i_CMDREG_WRREQ             (~CMDREG_WRREQ_n            ),
    .o_CMDREG_RST_n             (CMDREG_RST_n               ),

    .i_SYS_RUN_FLAG             (SYS_RUN_FLAG               ),
    .i_SYS_ERR_FLAG             (SYS_ERR_FLAG               ),

    .o_FSMERR_RESTART_n         (FSMERR_RESTART_n           ),

    .i_SUPBD_ACT_n              (SUPBD_ACT_n                ),
    .i_PGCMP_EQ                 (PGCMP_EQ                   ),
    .i_VALPG_ACC_FLAG           (VALPG_ACC_FLAG             ),
    .i_PGREG_SR_SHIFT           (PGREG_SR_SHIFT             ),
    .i_SUMEQ_n                  (SUMEQ_n                    ),
    .i_MUXED_BDO_EN_DLYD        (MUXED_BDO_EN_DLYD          ),
    .i_OP_DONE                  (OP_DONE                    ),

    .o_BDI_EN_SET_n             (BDI_EN_SET_n               ),
    .o_BDI_EN_RST_n             (BDI_EN_RST_n               ),
    .o_PGREG_SRLD_EN            (PGREG_SR_LD_EN             ),
    .o_ACC_START                (ACC_START                  ),
    .o_REP_START                (REP_START                  ),
    .o_CMD_ACCEPTED_n           (CMD_ACCEPTED_n             ) //R59
);



///////////////////////////////////////////////////////////
//////  STATUS FLAGS
////

//USER PAGES Z14 ERROR FLAG
//Original circuit used a narrow tip caused by gate delay to reset STFLAG_USER_Z14_ERR_n.
//A small delay occurs on the SRNAND Z14_LOCKED_n output when Z14_UNLOCK_n resets the latch.
reg             z14_locked_dlyd_n = 1'b1;
always @(posedge i_MCLK) begin
    if(!CLK2P_n) begin
        z14_locked_dlyd_n <= Z14_LOCKED_n;
    end
end

//display valid unlock signal when ROT20 = 13
wire            z14_unlock_valid_n = (ROT20_n[13] == 1'b0) ? (Z14_UNLOCK_n | z14_locked_dlyd_n) : 1'b1;

wire            STFLAG_USER_Z14_ERR_n;
SRNAND primitive_D14 (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_S_n(~(ACQ_START & rot20_d18_dlyd2)), .i_R_n(~(~(z14_unlock_valid_n & OP_DONE_SET_n) | ~SYS_RST_n)), .o_Q(), .o_Q_n(STFLAG_USER_Z14_ERR_n));


//ASYNC SR LATCHES
wire            STFLAG_OP_DONE_n;
ASYNCDL primitive_D17 (.i_SET(ASYNC_LATCH_EN__STFLAG_CLR), .i_EN(~OP_DONE_SET_n),           .i_D(1'b0), .o_Q(STFLAG_OP_DONE_n));

wire            STFLAG_Z14_ERR_n;
ASYNCDL primitive_D18 (.i_SET(ASYNC_LATCH_EN__STFLAG_CLR), .i_EN(~Z14_ERR_n),               .i_D(1'b0), .o_Q(STFLAG_Z14_ERR_n));

wire            STFLAG_TIMER25K_LATCHED_n;
ASYNCDL primitive_D19 (.i_SET(ASYNC_LATCH_EN__STFLAG_CLR), .i_EN(~TIMER25K_OUTLATCH_LD_n),  .i_D(1'b0), .o_Q(STFLAG_TIMER25K_LATCHED_n));

wire            STFLAG_TIMER25K_TIMEOVER_n;
ASYNCDL primitive_D20 (.i_SET(ASYNC_LATCH_EN__STFLAG_CLR), .i_EN(~TIMER25K_TIMEOVER_n),     .i_D(1'b0), .o_Q(STFLAG_TIMER25K_TIMEOVER_n));

wire            STFLAG_CMD_ACCEPTED_n;
ASYNCDL primitive_D21 (.i_SET(ASYNC_LATCH_EN__STFLAG_CLR), .i_EN(~CMD_ACCEPTED_n),          .i_D(1'b0), .o_Q(STFLAG_CMD_ACCEPTED_n));

wire            STFLAG_TEMPDROP_n;
ASYNCDL primitive_C20 (.i_SET(ASYNC_LATCH_EN__STFLAG_CLR), .i_EN(~TEMPDROP_SET_n),          .i_D(1'b0), .o_Q(STFLAG_TEMPDROP_n));

//stflag bus assignments
assign          STFLAG[15] = ~STFLAG_TIMER25K_LATCHED_n;
assign          STFLAG[14] = ~STFLAG_Z14_ERR_n;
assign          STFLAG[13] = ~STFLAG_TIMER25K_TIMEOVER_n;
assign          STFLAG[12] = ~CMD_ACCEPTED_n;
assign          STFLAG[11] = ~STFLAG_OP_DONE_n;
assign          STFLAG[10] = ~1'b1;
assign          STFLAG[9]  = i_TEMPLO_n;
assign          STFLAG[8]  = ~STFLAG_USER_Z14_ERR_n;
assign          STFLAG[7]  = ~1'b1;
assign          STFLAG[6]  = ~1'b0;
assign          STFLAG[5]  = ~1'b1;
assign          STFLAG[4]  = ~1'b1;
assign          STFLAG[3]  = ~1'b1;
assign          STFLAG[2]  = ~STFLAG_TIMER25K_LATCHED_n;
assign          STFLAG[1]  = (STFLAG_TIMER25K_LATCHED_n & ~STFLAG_TIMER25K_TIMEOVER_n) | (STFLAG_TIMER25K_LATCHED_n & ~STFLAG_Z14_ERR_n);
assign          STFLAG[0]  = (STFLAG_TIMER25K_LATCHED_n & STFLAG_TIMER25K_TIMEOVER_n & ~STFLAG_CMD_ACCEPTED_n) |
                             (STFLAG_TIMER25K_LATCHED_n & ~STFLAG_Z14_ERR_n);

//controller IRQ
assign          o_IRQ_n = &{STFLAG_OP_DONE_n,
                            STFLAG_CMD_ACCEPTED_n,
                            STFLAG_Z14_ERR_n,
                            STFLAG_TIMER25K_LATCHED_n,
                            STFLAG_TIMER25K_TIMEOVER_n,
                            ~(STFLAG_USER_Z14_ERR_n & ~STFLAG_TEMPDROP_n)};



///////////////////////////////////////////////////////////
//////  ADDRESS DECODER
////

//
//  DATA OUT
//

//bubble/controller IO
wire            dma_tx_n = (DMA_R_nW & ~ALD_EN) | ~DMA_ACT;         //DMA data write/Address latch write
wire            cpu_reg_read_n = ~(i_FCIN[2] & i_R_nW) | i_REGCS_n; //Supervisor/interrupt

//interrupt related
wire            cpu_interrupted_n = ~&{i_FCIN} | i_AS_n;            //FC = 3'b111, CPU interrupted
wire            int1_vector_req_n = ~|{cpu_interrupted_n, i_LDS_n, i_AIN[0], ~&{i_AIN[1], i_AIN[2], i_R_nW}};
assign          o_INT1_ACK_n = cpu_interrupted_n | int1_vector_req_n;

//read-only register decoder
//0: 0x40000: DMA tx register
//1: 0x40002: CRC14 SR upper 4bits + timer 25k 12bits(bus contention with 0x40000)
//2:        : no register
//3: 0x40006: BMC status/INT1 vector(lower data)
wire    [1:0]   internal_bus_addr = (i_AIN[1:0] | {2{int1_vector_req_n}}) & {2{~DMA_ACT}};

//internal tri-state bus
always @(*) begin
    case(internal_bus_addr)
        2'b00: INTLBUS <= DMATXREG;
        2'b01: INTLBUS <= {TIMERREG_MSBS, TIMERREG_LSBS};
        2'b10: INTLBUS <= 16'h0000;
        2'b11: INTLBUS <= STFLAG;
    endcase
end

//data bus driver
assign          o_CTRL_DATA_OE_n = &{dma_tx_n, cpu_reg_read_n, cpu_interrupted_n};


//
//  DATA IN
//

//write enable
wire            write_enable = &{i_FCIN[2], ~DMA_ACT, ~|{i_REGCS_n, i_UDS_n, i_LDS_n, i_R_nW}};

//write-only register decoder
//0: 0x40000: page number
//1: 0x40002: r/w command
//2: 0x40004: status flag clear
//3:        : no register

//must promote them as global signals or clocks
assign          ASYNC_LATCH_EN__PGREG_LD        = &{~i_AIN[1], ~i_AIN[0], write_enable};
assign          ASYNC_LATCH_EN__CMDREG_WR_EN    = &{~i_AIN[1],  i_AIN[0], write_enable};
assign          ASYNC_LATCH_EN__STFLAG_CLR      = &{ i_AIN[1], ~i_AIN[0], write_enable};



///////////////////////////////////////////////////////////
//////  DATA OUTPUT MUX
////

wire    [1:0]   doutmux_sel = {~((MSKADDR_INC | DMADREG_BDHILO_LD) & ALD_EN), (MSKADDR_INC & ALD_EN)};

always @(*) begin
    case(doutmux_sel)
        2'b00: o_DOUT <= {12'h000, ALD_DMABD | {4{ALD_nB_U}}};      //0x000-0x480 for bootloader, 0xF00-0xFFF for user pages. Use AND, invert ALD_DMABD once more and apply demorgan
        2'b01: o_DOUT <= {12'h000, 2'b11, ALD_DMAMSK, ~ALD_DMAMSK}; //error map from 0xD00
        2'b10: o_DOUT <= INTLBUS;                                   //internal tri-state bus
        2'b11: o_DOUT <= 16'h0000;                                  //unselected
    endcase
end

endmodule

module K005297_abspgcntr (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_ABSPGCNTR_CNT_STOP,
    input   wire            i_ABSPGCNTR_CNT_START,
    input   wire            i_ALD_nB_U,

    output  wire            o_ABSPGCNTR_LSB
);



///////////////////////////////////////////////////////////
//////  RELATIVE PAGE COUNTER
////

/*
    gte(greater than or equal) flag(>= 1531 evaluation)
    relative page 0-1530: +522
    relative page 1531-2052: -1531(loop)
*/


//SR shift enable
wire            abspgcntr_shift; //shift flag
SRNAND I24 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(abspgcntr_shift));


//const add enable
wire            abspgcntr_add_en;
SRNOR I34 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S(i_ABSPGCNTR_CNT_STOP), .i_R(i_ABSPGCNTR_CNT_START), .o_Q(), .o_Q_n(abspgcntr_add_en));

 
reg     [11:0]  abspgcntr = 12'd0; //abs page counter
wire            abspgcntr_const, abspgcntr_fa_sum, abspgcntr_fa_cout; //FA carry out
reg             abspgcntr_fa_cflag = 1'b0; //FA carry storage
assign  o_ABSPGCNTR_LSB = abspgcntr_fa_sum & i_ALD_nB_U;

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(abspgcntr_shift == 1'b1) begin
            abspgcntr[11] <= o_ABSPGCNTR_LSB;
            abspgcntr[10:0] <= abspgcntr[11:1];
        end
        else begin
            abspgcntr <= abspgcntr;
        end
    end
end

//constant generator: +522 or -1531
wire            constP522 = ~&{i_ROT20_n[9], i_ROT20_n[3], i_ROT20_n[1]};
wire            constN1531 = ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]};
reg             gte1531_evalreg = 1'b0;
reg             gte1531_flag = 1'b0;
assign  abspgcntr_const = (gte1531_flag == 1'b0) ? constP522 : constN1531;
                                                //+522 : -1531
//evaluator: greater than or equal to 1531
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        gte1531_evalreg <= ((abspgcntr_fa_sum & ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) | 
                           ((o_ABSPGCNTR_LSB | ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) & gte1531_evalreg)) &
                           i_ROT20_n[19];

        gte1531_flag <= (i_ROT20_n[12] == 1'b0) ? gte1531_evalreg : gte1531_flag;
    end
end

//adder
FA J30 (.i_A(abspgcntr_add_en & abspgcntr_const), .i_B(abspgcntr_fa_cflag), .i_CIN(abspgcntr[0]), .o_S(abspgcntr_fa_sum), .o_COUT(abspgcntr_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        abspgcntr_fa_cflag <= abspgcntr_fa_cout & i_ROT20_n[19];
    end
end

endmodule

module K005297_accmodeflag (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //system flags
    input   wire            i_SYS_RST_n,
    input   wire            i_SYS_RUN_FLAG,

    //control
    input   wire            i_CMDREG_RST_n,
    input   wire            i_BDI_EN_SET_n,
    input   wire            i_SYNCED_FLAG_SET_n,

    //mode flag output
    output  wire            o_BMODE_n, //bootloader mode
    output  wire            o_UMODE_n, //user mode
    output  wire            o_ALD_nB_U, //addres latch data BOOTLOADER_n / USER
    output  wire            o_UMODE_SET_n
);

assign  o_UMODE_SET_n = i_CMDREG_RST_n | i_BDI_EN_SET_n;

SRNAND C21 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_UMODE_SET_n), .i_R_n(i_SYS_RST_n), .o_Q(o_BMODE_n), .o_Q_n());
SRNAND C54 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_UMODE_SET_n), .i_R_n(i_SYS_RUN_FLAG), .o_Q(), .o_Q_n(o_UMODE_n));
SRNAND C19 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_UMODE_SET_n & i_SYS_RUN_FLAG), .i_R_n(i_SYNCED_FLAG_SET_n), .o_Q(o_ALD_nB_U), .o_Q_n());

endmodule

module K005297_bubctrlfe (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //system flags
    input   wire            i_SYS_RST_n,
    input   wire            i_SYS_RUN_FLAG_SET_n,

    //control
    input   wire            i_ABSPGCNTR_CNT_START,
    input   wire            i_ABSPGCNTR_CNT_STOP,
    input   wire            i_VALPG_ACC_FLAG,
    input   wire            i_BMODE_n,

    input   wire            i_REP_START,
    input   wire            i_SWAP_START,

    output   wire           o_BOOTEN_n,
    output   wire           o_BSS_n,
    output   wire           o_BSEN_n,
    output   wire           o_REPEN_n,
    output   wire           o_SWAPEN_n
);

//Bubble Shift Start
SRNAND T6 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~(i_ABSPGCNTR_CNT_START & ~i_ROT20_n[17])), .i_R_n(i_SYS_RUN_FLAG_SET_n & i_SYS_RST_n), .o_Q(), .o_Q_n(o_BSS_n));

//Bubble Shift Enable
SRNAND H22 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~i_ABSPGCNTR_CNT_STOP & i_SYS_RST_n), .i_R_n(~(i_ABSPGCNTR_CNT_START & ~i_ROT20_n[1])), .o_Q(o_BSEN_n), .o_Q_n());

//Replicator Enable
reg             bootloop_rep_pulse = 1'b1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(o_BOOTEN_n | o_BSEN_n == 1'b1) begin //H25 NAND demorgan
            bootloop_rep_pulse <= 1'b1;
        end
        else begin
            if(i_ROT20_n[1] == 1'b0) begin
                bootloop_rep_pulse <= ~bootloop_rep_pulse;
            end
            else begin
                bootloop_rep_pulse <= bootloop_rep_pulse;
            end
        end
    end
end

wire            replicator_on = ~((~bootloop_rep_pulse | i_REP_START) & ~i_ROT20_n[2]);
SRNAND K24 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SYS_RST_n & i_ROT20_n[16]), .i_R_n(replicator_on), .o_Q(o_REPEN_n), .o_Q_n());

//Swap Gate Enable
SRNAND T15 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SYS_RST_n & i_ROT20_n[17]), .i_R_n(~((i_VALPG_ACC_FLAG & i_SWAP_START) & ~i_ROT20_n[3])), .o_Q(o_SWAPEN_n), .o_Q_n());

//Bootloop Enabe;
SRNAND C27 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SYS_RST_n), .i_R_n(~(i_BMODE_n & ~i_ROT20_n[0])), .o_Q(), .o_Q_n(o_BOOTEN_n));

endmodule

module K005297_bubrdfe (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //system reset
    input   wire            i_SYS_RST_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_BDI_EN_SET_n,
    input   wire            i_BDI_EN_RST_n,

    input   wire    [3:0]   i_BDIN_n,

    //output
    output  wire            o_BDI,

    output  wire            o_BDI_EN
);

//input enable
SRNAND F32 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n((i_BDI_EN_SET_n & i_SYS_RST_n)), .i_R_n(i_BDI_EN_RST_n), .o_Q(o_BDI_EN), .o_Q_n());

//mux select counter
reg     [1:0]   mux_cntr = 2'd0;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[0] == 1'b0) begin
            mux_cntr <= 2'd0;
        end 
        else begin
            if(~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) == 1'b1) begin //3-8_13-18
                if(mux_cntr == 2'd3) begin
                    mux_cntr <= 2'd0;
                end
                else begin
                    mux_cntr <= mux_cntr + 2'd1;
                end
            end
            else begin
                mux_cntr <= mux_cntr;
            end
        end
    end
end

//bubble inlatch
reg     [3:0]   bubble_inlatch;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[18] == 1'b0) begin //d-latch latches SR data at ROT20_n[19]
            bubble_inlatch <= i_BDIN_n;
        end
    end
end

//in mux
reg             bubble_stream;
wire    [1:0]   mux_select = {(mux_cntr[1] & ~i_4BEN_n), mux_cntr[0]};
always @(*) begin
    case(mux_select) //bit3->2->1->0
        2'd0: bubble_stream <= bubble_inlatch[3];
        2'd1: bubble_stream <= bubble_inlatch[2];
        2'd2: bubble_stream <= bubble_inlatch[1];
        2'd3: bubble_stream <= bubble_inlatch[0];
    endcase
end

assign  o_BDI = ~bubble_stream & o_BDI_EN;

endmodule

module K005297_bubwrfe (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_TST, //TST5
    input   wire            i_4BEN_n,

    input   wire            i_MUXED_BDO,
    input   wire            i_MUXED_BDO_EN,
    input   wire            i_SUPBD_END_n,

    output  wire    [3:0]   o_BDOUT_n,

    //test mode
    input   wire            i_ABSPGCNTR_LSB,
    input   wire            i_PGREG_SR_LSB,
    input   wire            i_DLCNTR_LSB,
    input   wire            i_CYCLECNTR_LSB
);

//output enable
wire            bubble_output_en;
SRNAND K22 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_END_n), .i_R_n(~(i_MUXED_BDO_EN & ~i_ROT20_n[17])), .o_Q(), .o_Q_n(bubble_output_en));

//bubble shift register
reg     [3:0]   bubble_sr;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) == 1'b1) begin //3-8_13-18
            bubble_sr[0] <= i_MUXED_BDO;
            bubble_sr[3:1] <= bubble_sr[2:0];
        end
        else begin
            bubble_sr <= bubble_sr;
        end
    end
end

//bubble outlatch
reg     [3:0]   bubble_outlatch;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[0] == 1'b0) begin //d-latch latches SR data at ROT20_n[1]
            if(i_4BEN_n == 1'b1) begin //2bit mode
                bubble_outlatch <= {bubble_sr[3:2], 2'b00};
            end
            else begin //4bit mode
                bubble_outlatch <= bubble_sr;
            end
        end
    end
end

//output mux
assign  o_BDOUT_n = (i_TST == 1'b1) ? ~(bubble_outlatch & {4{bubble_output_en}}) :
                                      {i_CYCLECNTR_LSB, i_DLCNTR_LSB, i_PGREG_SR_LSB, i_ABSPGCNTR_LSB};

endmodule

module K005297_busctrlfe (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,

    //control
    input   wire            i_DMA_ACT,
    input   wire            i_DMA_WR_ACT_n,
    output  wire            o_DMA_R_nW,

    //bus control
    output  wire            o_UDS_n,
    output  wire            o_LDS_n,
    output  wire            o_AS_n,
    output  wire            o_R_nW
);

//DMA RW mode indicator
assign          o_DMA_R_nW = (i_DMA_WR_ACT_n == 1'b0) ? 1'b0 : 1'b1; //write : read

//DATA STROBE(UDS+LDS)
wire            data_strobe_set_n = (i_DMA_WR_ACT_n == 1'b0) ? ~i_ROT8[4] : ~i_ROT8[2]; //write : read
wire            data_strobe_reset_n = (i_DMA_WR_ACT_n == 1'b0) ? (~i_ROT8[6] & i_DMA_ACT) : (~i_ROT8[7] & i_DMA_ACT); //write : read
wire            data_strobe_n;
assign          o_UDS_n = data_strobe_n;
assign          o_LDS_n = data_strobe_n;

SRNAND C43 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(data_strobe_set_n), .i_R_n(data_strobe_reset_n), .o_Q(), .o_Q_n(data_strobe_n));

//ADDRESS STROBE
wire            addr_strobe_set_n = ~i_ROT8[2];
wire            addr_strobe_reset_n = ~i_ROT8[7] & i_DMA_ACT;

SRNAND C68 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(addr_strobe_set_n), .i_R_n(addr_strobe_reset_n), .o_Q(), .o_Q_n(o_AS_n));

//R/W
wire            bus_read_n = (~i_ROT8[7] & i_DMA_ACT) & ~(i_ROT8[2] & o_DMA_R_nW);
wire            bus_write_n = ~i_ROT8[2] | ~(~o_DMA_R_nW & i_DMA_ACT);

SRNAND C53 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(bus_write_n), .i_R_n(bus_read_n), .o_Q(), .o_Q_n(o_R_nW));

endmodule

module K005297_byteacqcntr (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_GLCNT_RD,
    input   wire            i_NEWBYTE,
    input   wire            i_ACC_ACT_n,
    input   wire            i_BUBWR_WAIT,

    output  reg             o_BYTEACQ_DONE = 1'b0
);


///////////////////////////////////////////////////////////
//////  BYTE ACQUISITION COUNTER
////

//byte acquisition counter
reg     [2:0]   byte_acq_cntr = 3'h7;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if((i_NEWBYTE | i_ACC_ACT_n) == 1'b1) begin //reset
            byte_acq_cntr <= 3'h7;
        end
        else begin
            if(i_GLCNT_RD == 1'b1) begin
                if(byte_acq_cntr == 3'h0) begin
                    byte_acq_cntr <= 3'h7;
                end
                else begin
                    byte_acq_cntr <= byte_acq_cntr - 3'h1;
                end
            end
            else begin
                byte_acq_cntr <= byte_acq_cntr;
            end
        end
    end
end

//flag
wire            eq7 = (byte_acq_cntr == 3'h0) ? 1'b1 : 1'b0;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) == 1'b1) begin //3-8_13-18
            o_BYTEACQ_DONE <= eq7 | i_BUBWR_WAIT;
        end
        else begin
            o_BYTEACQ_DONE <= o_BYTEACQ_DONE;
        end
    end
end

endmodule

module K005297_cyclecntr (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_CYCLECNTR_EN,
    output  wire            o_CYCLECNTR_LSB
);



///////////////////////////////////////////////////////////
//////  CYCLE COUNTER
////

/*
    +1 serial up counter
*/

//shift flag
wire            cyclecntr_shift; 
SRNAND Q67 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[10]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(cyclecntr_shift));


reg     [9:0]   cyclecntr = 10'd0; //cycle counter
wire            cyclecntr_fa_sum; //msb input
wire            cyclecntr_fa_cout; //FA carry out
reg             cyclecntr_fa_cflag = 1'b0; //FA carry storage
assign  o_CYCLECNTR_LSB = cyclecntr[0];

//serial full adder cell
FA K20 (.i_A(~i_ROT20_n[0]), .i_B(cyclecntr[0]), .i_CIN(cyclecntr_fa_cflag), .o_S(cyclecntr_fa_sum), .o_COUT(cyclecntr_fa_cout));

//previous carry bit storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        cyclecntr_fa_cflag <= cyclecntr_fa_cout & i_ROT20_n[19];
    end
end

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(cyclecntr_shift == 1'b1) begin
            cyclecntr[9] <= cyclecntr_fa_sum & i_CYCLECNTR_EN;
            cyclecntr[8:0] <= cyclecntr[9:1];
        end
        else begin
            cyclecntr <= cyclecntr;
        end
    end
end

endmodule

module K005297_dlcntr (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_DLCNT_START_n, //data length count start
    input   wire            i_SUPBD_START_n, //data length count end
    input   wire            i_DLCNT_EN, //data length + 1

    output  wire            o_DLCNTR_LSB, //data length counter lsb
    output  wire            o_DLCNTR_CFLAG //carry of data length's msb
);



///////////////////////////////////////////////////////////
//////  DATA LENGTH COUNTER
////

/*
    +1 serial up counter
*/

//reset flag(load 0)
wire            dlcntr_rst_n; 
SRNAND I46 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_START_n), .i_R_n(i_DLCNT_START_n), .o_Q(), .o_Q_n(dlcntr_rst_n));

//shift flag
wire            dlcntr_shift; 
SRNAND J67 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[10]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(dlcntr_shift));


reg     [9:0]   dlcntr = 10'd0; //data length counter
wire            dlcntr_fa_sum; //msb input
wire            dlcntr_fa_cout; //FA carry out
reg             dlcntr_fa_cflag = 1'b0; //FA carry storage
assign          o_DLCNTR_LSB = dlcntr[0];
assign          o_DLCNTR_CFLAG = dlcntr_fa_cflag;

//serial full adder cell
FA I61 (.i_A(dlcntr[0]), .i_B(dlcntr_fa_cflag), .i_CIN(i_DLCNT_EN), .o_S(dlcntr_fa_sum), .o_COUT(dlcntr_fa_cout));

//previous carry bit storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        dlcntr_fa_cflag <= dlcntr_fa_cout & i_ROT20_n[19];
    end
end

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(dlcntr_shift == 1'b1) begin
            dlcntr[9] <= dlcntr_fa_sum & dlcntr_rst_n;
            dlcntr[8:0] <= dlcntr[9:1];
        end
        else begin
            dlcntr <= dlcntr;
        end
    end
end

endmodule

module K005297_dleval (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_TST,
    input   wire            i_SYS_RST_n,
    
    input   wire            i_4BEN_n,
    input   wire            i_UMODE_n,
    input   wire            i_DLCNTR_LSB,
    input   wire            i_DLCNTR_CFLAG,

    input   wire            i_BYTEACQ_DONE,
    input   wire            i_SUPBD_END_n,

    output  wire            o_SUPBD_START_n
);



///////////////////////////////////////////////////////////
//////  DATA LENGTH COUNTER
////

//eq480
wire            const480 = ~&{i_ROT20_n[8], i_ROT20_n[7], i_ROT20_n[6], i_ROT20_n[5]};
reg             eq480_flag_n = 1'b0;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq480_flag_n <= (((i_DLCNTR_LSB ^ const480) | eq480_flag_n) & i_ROT20_n[19]);
    end
end

//bootloader done flag
reg             boot_done = 1'b0;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        boot_done <= (i_ROT20_n[9] == 1'b0) ? (~eq480_flag_n | i_TST) & i_UMODE_n :
                                              boot_done & i_UMODE_n;
    end
end

//page done flag
reg             pg_done = 1'b0;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_4BEN_n == 1'b1) begin //2bit mode
            pg_done <= (i_ROT20_n[7] == 1'b0) ? ((i_TST | i_DLCNTR_CFLAG) & ~i_UMODE_n) : pg_done;
        end
        else begin //4bit mode
            pg_done <= (i_ROT20_n[8] == 1'b0) ? ((i_TST | i_DLCNTR_CFLAG) & ~i_UMODE_n) : pg_done;
        end
    end
end


///////////////////////////////////////////////////////////
//////  EFFECTIVE BUBBLE DATA END FLAG
////

wire            effbd_done = ~((boot_done | pg_done) & ~i_ROT20_n[10]);
wire            supbd_rdy;
assign          o_SUPBD_START_n = ~&{supbd_rdy, i_BYTEACQ_DONE, ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n))} & i_SYS_RST_n;

SRNAND K23 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_END_n), .i_R_n(effbd_done), .o_Q(), .o_Q_n(supbd_rdy));

endmodule

module K005297_dmaaddrcntr (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,

    //control
    input   wire            i_ALD_nB_U,
    input   wire            i_ADDR_RST,
    input   wire            i_BDRWADDR_INC,
    input   wire            i_MSKADDR_INC,

    output  wire    [6:0]   o_AOUT, //A7-A1
    output  wire    [3:0]   o_ALD_DMABD, //bubble data
    output  wire            o_ALD_DMAMSK //error map
);



///////////////////////////////////////////////////////////
//////  DMA TX(BUBBLE DATA) ADDRESS COUNTER
////

reg     [10:0]  dmabd_addr_cntr = 11'h000;

always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ADDR_RST == 1'b1) begin
            dmabd_addr_cntr <= 11'h000;
        end
        else begin
            if((i_BDRWADDR_INC & i_ROT8[1]) == 1'b1) begin //count up
                if(i_ALD_nB_U == 1'b0) begin //bootloader
                    if(dmabd_addr_cntr == 11'h7FF) begin
                        dmabd_addr_cntr <= 11'h000;
                    end
                    else begin
                        dmabd_addr_cntr <= dmabd_addr_cntr + 11'h001;
                    end
                end
                else begin //user pages
                    if(dmabd_addr_cntr == 11'h0FF) begin
                        dmabd_addr_cntr <= 11'h000;
                    end
                    else begin
                        dmabd_addr_cntr <= dmabd_addr_cntr + 11'h001;
                    end
                end
            end
            else begin
                dmabd_addr_cntr <= dmabd_addr_cntr;
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  DMA RX(ERROR MAP) ADDRESS COUNTER
////

//mskaddr inc latch(why?)
reg             mskaddr_inc_latched;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[1] == 1'b1) begin //D-latch latches this at ROT8[2] == 1'b1;
            mskaddr_inc_latched <= i_MSKADDR_INC;
        end
    end
end

//address counter
reg     [7:0]  dmamsk_addr_cntr = 8'h00;

always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ADDR_RST == 1'b1) begin
            dmamsk_addr_cntr <= 8'h00;
        end
        else begin
            if((mskaddr_inc_latched & i_ROT8[1]) == 1'b1) begin //count up
                if(dmamsk_addr_cntr == 8'hFF) begin
                    dmamsk_addr_cntr <= 8'h00;
                end
                else begin
                    dmamsk_addr_cntr <= dmamsk_addr_cntr + 8'h01;
                end
            end
            else begin
                dmamsk_addr_cntr <= dmamsk_addr_cntr;
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  OUTPUTS
////

assign  o_AOUT = (i_MSKADDR_INC == 1'b0) ? dmabd_addr_cntr[6:0] : dmamsk_addr_cntr[6:0];
assign  o_ALD_DMABD = dmabd_addr_cntr[10:7];
assign  o_ALD_DMAMSK = dmamsk_addr_cntr[7];

endmodule

module K005297_dmadreg (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,

    //control
    input   wire            i_DMADREG_SHIFT,
    input   wire            i_DMADREG_BDLD_EN,
    input   wire            i_DMADREG_BDHI_LD,
    input   wire            i_DMADREG_BDLO_LD,
    input   wire            i_DMADREG_BDHILO_LD,

    input   wire            i_DMA_ACT,
    input   wire            i_BDI_EN,
    input   wire            i_GLCNT_RD,

    output  wire            o_BDRWADDR_INC,

    input   wire            i_MUXED_BDI, //muxed bubble data input(bubble read)
    output  wire    [15:0]  o_DMATXREG, //parallel bubble read data(DMA TX)

    output  wire            o_EFF_BDO, //effective bubble data output(bubble write)
    input   wire    [15:0]  i_DIN //parallel bubble write data(DMA RX)
);

///////////////////////////////////////////////////////////
//////  DMA DATA REGISTER
////

//word load request(for write?)
reg             txreg_word_ld_rq = 1'b0;
wire            txreg_word_ld = txreg_word_ld_rq & i_DMA_ACT & i_ROT8[6];
assign  o_BDRWADDR_INC = txreg_word_ld_rq;

always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[1] == 1'b1) begin
            txreg_word_ld_rq <= i_DMADREG_BDHILO_LD; //latches at i_ROT8[2]; source latch launches at i_ROT8[7]
        end
    end
end

//8 bit shift register for data IO
reg     [7:0]   bytesr;
assign          o_EFF_BDO = bytesr[7];
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        case({i_GLCNT_RD, i_DMADREG_SHIFT})
            2'b00: bytesr <= bytesr; //hold
            2'b01: bytesr <= bytesr;
            2'b10: bytesr <= (i_DMADREG_BDHI_LD == 1'b0) ? o_DMATXREG[7:0] : o_DMATXREG[15:8]; //parallel load(bubble write)
            2'b11: begin bytesr[0] <= i_MUXED_BDI; bytesr[7:1] <= bytesr[6:0]; end //serial load(bubble read)
        endcase
    end
end

//D latch * 16
wire            txreg_hi_ld = (i_BDI_EN == 1'b1) ? (i_DMADREG_BDHI_LD & i_DMADREG_BDLD_EN) : txreg_word_ld;
wire            txreg_lo_ld = (i_BDI_EN == 1'b1) ? (i_DMADREG_BDLO_LD & i_DMADREG_BDLD_EN) : txreg_word_ld;
wire    [7:0]   txreg_hi_data = (i_BDI_EN == 1'b1) ? bytesr: i_DIN[15:8];
wire    [7:0]   txreg_lo_data = (i_BDI_EN == 1'b1) ? bytesr: i_DIN[7:0];

DL #(.dw(8)) DMATXREGHI (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_EN(txreg_hi_ld), .i_D(txreg_hi_data), .o_Q(o_DMATXREG[15:8]), .o_Q_n());
DL #(.dw(8)) DMATXREGLO (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_EN(txreg_lo_ld), .i_D(txreg_lo_data), .o_Q(o_DMATXREG[7:0]), .o_Q_n());

endmodule

module K005297_dmadregldctrl (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_BDI_EN,
    input   wire            i_UMODE_n,
    
    input   wire            i_ACQ_MSK_LD,
    input   wire            i_MSKREG_SR_LD,
    input   wire            i_BYTEACQ_DONE,
    input   wire            i_GLCNT_RD,

    input   wire            i_ACQ_START,
    input   wire            i_SUPBD_START_n,
    input   wire            i_VALPG_FLAG_SET_n,

    input   wire            i_PGREG_SR_LSB,
    input   wire            i_DLCNTR_LSB,

    input   wire            i_DMA_WORD_END,

    output  wire            o_NEWBYTE,
    output  wire            o_DLCNT_EN,
    output  reg             o_DMADREG_BDHI_LD = 1'b1,
    output  wire            o_DMADREG_BDLO_LD
);

//NEWBYTE for DMA outlatch control
reg             initial_newbyte; //only asserted at the beginning
assign          o_NEWBYTE = initial_newbyte | i_BYTEACQ_DONE & i_GLCNT_RD;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        initial_newbyte <= i_ACQ_MSK_LD & (i_MSKREG_SR_LD & ~i_ROT20_n[1]) & i_BDI_EN;
    end
end

//bootloader related
wire            newbyte_dlyd;
assign          o_DLCNT_EN = newbyte_dlyd & ~i_ROT20_n[0];
SRNAND K33 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[1]), .i_R_n(~o_NEWBYTE), .o_Q(), .o_Q_n(newbyte_dlyd));

//user page related
wire            valpg_dma_req;
SRNAND J38 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_START_n), .i_R_n(i_VALPG_FLAG_SET_n), .o_Q(), .o_Q_n(valpg_dma_req));

reg             dlcntr_cmp, dlcntr_zero_n;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        dlcntr_cmp <= (((i_DLCNTR_LSB ^ (i_PGREG_SR_LSB | valpg_dma_req)) | dlcntr_cmp) & i_ROT20_n[19]) | i_UMODE_n;

        dlcntr_zero_n <= (i_4BEN_n == 1'b1) ? ((i_ROT20_n[7] == 1'b0) ? dlcntr_cmp : dlcntr_zero_n) :
                                              ((i_ROT20_n[8] == 1'b0) ? dlcntr_cmp : dlcntr_zero_n); //2bit : 4bit
    end
end

reg             init_dma_req = 1'b0; //this sr latch's outer circuit has a combinational loop
                                       //RESET PORT(flag set) ACQ_START @ D0
                                       //SET PORT(flag reset) ACQ_MSK_LD @ D4(stable before D4)
always @(posedge i_MCLK) begin
    if(i_SYS_RST_n == 1'b0) begin //synchronous reset(SR latch originally)
        init_dma_req <= 1'b0;
    end
    else begin
        if(!i_CLK2M_PCEN_n) begin
            if(i_ROT20_n[19] == 1'b0) begin //SR latch's reset works @ ROT20[0]
                if(i_ACQ_START == 1'b1) begin
                    init_dma_req <= 1'b1;
                end
            end
            else if(i_ROT20_n[3] == 1'b0) begin
                if(init_dma_req & ~i_ACQ_MSK_LD == 1'b1) begin
                    init_dma_req <= 1'b0;
                end
            end
            else begin
                init_dma_req <= init_dma_req;
            end
        end
    end
end

//SR latch
wire            bootloader_dma_req;
SRNAND K38 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~(o_NEWBYTE & dlcntr_zero_n)), .i_R_n(~(o_DLCNT_EN & ~dlcntr_zero_n)), .o_Q(bootloader_dma_req), .o_Q_n());

//DMADREG HI/LO toggle
wire            dmadreg_toggle_hilo = ~(init_dma_req & i_BDI_EN) & (~valpg_dma_req | bootloader_dma_req) & o_NEWBYTE;

//K50 TFF
assign          o_DMADREG_BDLO_LD = ~o_DMADREG_BDHI_LD;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_DMA_WORD_END == 1'b1) begin //reset
            o_DMADREG_BDHI_LD <= 1'b1; 
        end
        else begin
            if(dmadreg_toggle_hilo == 1'b1) begin
                o_DMADREG_BDHI_LD <= ~o_DMADREG_BDHI_LD;
            end
            else begin
                o_DMADREG_BDHI_LD <= o_DMADREG_BDHI_LD;
            end
        end
    end
end

endmodule

module K005297_dmafe (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,

    //reset
    input   wire            i_SYS_RST_n,

    //68000
    input   wire            i_CPURST_n,
    input   wire            i_AS_n,
    input   wire            i_BG_n,
    output  wire            o_BR_n,
    output  wire            o_BGACK_n,

    //control
    input   wire            i_BR_START_n,
    input   wire            i_DMA_END,

    output  wire            o_ALD_EN,
    output  wire            o_DMA_ACT
);


///////////////////////////////////////////////////////////
//////  DMA FRONTEND
////

//
//  USE 4MHz CLOCK
//


//DMA ACT flag
//This SR latch receives the SET signal from the asynchronous source during ROT8[7] = 1
//so, sample the SET signal twice, at both posedge and negedge of ROT8[7] = 1
reg             dma_act_set_n;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[6] == 1'b1) begin //async signal from CPU, sample them here, latch C83 @ posedge ROT8[7]
            dma_act_set_n <= ~(~o_BR_n & (i_AS_n | ~i_CPURST_n) & ~(i_BG_n & i_CPURST_n)); //C87 NAND
        end
        else if(i_ROT8[7] == 1'b1) begin //async signal from CPU, sample them here, latch C83 @ negedge ROT8[7]
            dma_act_set_n <= ~(~o_BR_n & (i_AS_n | ~i_CPURST_n) & ~(i_BG_n & i_CPURST_n)); //C87 NAND
        end
        else begin //disable
            dma_act_set_n <= 1'b1;
        end
    end
end
   
reg             dma_act_reset_n;

reg             dma_end_dlyd;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        dma_end_dlyd <= i_DMA_END;

        dma_act_reset_n <= ~((i_DMA_END & ~dma_end_dlyd) | ~i_SYS_RST_n);
    end
end

SRNAND C83 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(dma_act_set_n), .i_R_n(dma_act_reset_n), .o_Q(o_DMA_ACT), .o_Q_n());

//BGACK
SRNAND C86 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(dma_act_reset_n | o_DMA_ACT), .i_R_n(dma_act_set_n), .o_Q(o_BGACK_n), .o_Q_n()); //set port: demorgan

//BR
reg             br_start_dlyd;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        br_start_dlyd <= ~i_BR_START_n;
    end
end

wire            br_set_n = i_BR_START_n | br_start_dlyd;
wire            br_reset_n = ~((o_DMA_ACT & i_ROT8[1]) | ~i_SYS_RST_n);
SRNAND C88 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(br_reset_n), .i_R_n(br_set_n), .o_Q(o_BR_n), .o_Q_n()); //set port: demorgan

//Address Latch Enable
//Glitch can occur here. Not a serious one. Solve.
wire            ald_en_set_n = ~(o_DMA_ACT & i_ROT8[0]);
wire            ald_en_reset_n = ~((o_DMA_ACT & i_ROT8[2]) | ~i_SYS_RST_n);
SRNAND C70 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(ald_en_reset_n), .i_R_n(ald_en_set_n), .o_Q(), .o_Q_n(o_ALD_EN));

endmodule

module K005297_dmatiming (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [7:0]   i_ROT8,
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //system flags
    input   wire            i_UMODE_n,
    input   wire            i_ACC_ACT_n,
    input   wire            i_DMA_ACT,
    input   wire            i_BDI_EN,
    input   wire            i_MSKREG_SR_LD,
    input   wire            i_ACQ_MSK_LD,
    input   wire            i_ACQ_START,
    input   wire            i_SUPBDO_EN_n,
    input   wire            i_DMADREG_BDLO_LD,

    output  reg             o_BR_START_n,
    output  wire            o_DMA_END,
    output  wire            o_DMA_WORD_END,
    output  wire            o_MSKREG_LD,
    output  wire            o_MSKADDR_INC,
    output  wire            o_DMADREG_BDHILO_LD,
    output  wire            o_DMA_WR_ACT_n
);

///////////////////////////////////////////////////////////
//////  DMA TIMINGS
////

//
//  USE 4MHz CLOCK
//

//BDLO_LD negedge detection
reg             dmareg_bdlo_ld_dlyd;
wire            dmareg_bdlo_ld_negedge = dmareg_bdlo_ld_dlyd & ~i_DMADREG_BDLO_LD;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        dmareg_bdlo_ld_dlyd <= i_DMADREG_BDLO_LD;
    end
end

//dma command d1 SRNOR control
wire            dma_command_d1_set = o_MSKREG_LD | ~i_SYS_RST_n;
wire            dma_command_d1_reset = ~(i_UMODE_n | ~((i_MSKREG_SR_LD & ~i_ROT20_n[1]) | (i_ACQ_MSK_LD & ~i_ROT20_n[3])));

//dma command d0 SRNAND control
wire            dma_command_d0_set_n = ~(~(~(o_DMADREG_BDHILO_LD & i_ROT8[3]) & ~(i_ACQ_START & ~i_ROT20_n[0]) & i_SUPBDO_EN_n) | ~i_SYS_RST_n);
wire            dma_command_d0_reset_n = ~(((i_ACQ_MSK_LD & ~i_ROT20_n[3]) & ~i_BDI_EN) | dmareg_bdlo_ld_negedge);
assign  o_DMA_WORD_END = ~dma_command_d0_set_n;

//dma commands from sr latches
wire    [1:0]   dma_command_input; //[G5, F20] 

//G5, d1
SRNOR G5 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S(dma_command_d1_set), .i_R(dma_command_d1_reset), .o_Q(), .o_Q_n(dma_command_input[1]));

//F50, d0
SRNAND F50 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(dma_command_d0_set_n), .i_R_n(dma_command_d0_reset_n), .o_Q(), .o_Q_n(dma_command_input[0]));




//dma command control block
//rot8    4 5 6 7 0 1 2 3 4 5 6 7
//rot20   0   1   2   3   4   5

//dma command input is stable at falling edge of ROT8[3], because the launching latches are all enabled by ROT8[3] or ROT20[3]
reg             dma_command_lock_n = 1'b0; //latches command status at ROT8[3] == 1
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[3] == 1'b1) begin
            if(dma_command_lock_n == 1'b0) begin
                if(i_ACC_ACT_n == 1'b0) begin
                    dma_command_lock_n <= 1'b1; //unlock
                end
                else begin
                    dma_command_lock_n <= 1'b0; //lock hold
                end
            end
            else begin
                if(i_ACC_ACT_n & ~|{dma_command_input} == 1'b1) begin
                    dma_command_lock_n <= 1'b0; //lock
                end
                else begin
                    dma_command_lock_n <= 1'b1; //unlock
                end
            end

            if(dma_command_lock_n == 1'b0) begin
                if(i_ACC_ACT_n == 1'b0) begin //unlock
                    o_BR_START_n <= ~|{dma_command_input}; 
                end
                else begin
                    o_BR_START_n <= 1'b1; //still locked
                end
            end
            else begin
                if(i_ACC_ACT_n == 1'b0) begin //free
                    o_BR_START_n <= ~|{dma_command_input};
                end
                else begin
                    o_BR_START_n <= ~|{dma_command_input}; //locks when NOR(dmainput) is 1
                end
            end
        end
    end
end

reg     [1:0]   dma_command_0; //d-latch @ ROT8[4]
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[4] == 1'b1) begin
            dma_command_0 <= dma_command_input & {2{(dma_command_lock_n & i_SYS_RST_n)}};
        end
    end
end

reg     [1:0]   dma_command_1; //d-latch @ ROT8[7]
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        if(i_ROT8[6] == 1'b1) begin
            dma_command_1 <= dma_command_0 & {2{(dma_command_lock_n)}};
        end
    end
end

assign  o_DMA_END           = ~( dma_command_1[1] |  dma_command_1[0]);
assign  o_MSKADDR_INC       =  ( dma_command_1[1] & ~dma_command_1[0] & i_DMA_ACT);
assign  o_MSKREG_LD         =  o_MSKADDR_INC & i_ROT8[3];
assign  o_DMADREG_BDHILO_LD =  ( dma_command_1[1] &  dma_command_1[0] & i_DMA_ACT) |
                              (~dma_command_1[1] &  dma_command_1[0] & i_DMA_ACT);
assign  o_DMA_WR_ACT_n      = o_MSKADDR_INC | ~o_DMADREG_BDHILO_LD | ~i_BDI_EN;

endmodule

module K005297_fsm (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //CMDREG related
    input   wire            i_CMDREG_RDREQ,
    input   wire            i_CMDREG_WRREQ,
    output  wire            o_CMDREG_RST_n,

    //system flags
    input   wire            i_SYS_RUN_FLAG,
    input   wire            i_SYS_ERR_FLAG,
    output  wire            o_FSMERR_RESTART_n,

    input   wire            i_SUPBD_ACT_n,
    input   wire            i_PGCMP_EQ,
    input   wire            i_VALPG_ACC_FLAG,
    input   wire            i_PGREG_SR_SHIFT,
    input   wire            i_SUMEQ_n,
    input   wire            i_MUXED_BDO_EN_DLYD,
    input   wire            i_OP_DONE, //???

    //bubble input enable
    output  wire            o_BDI_EN_SET_n,
    output  wire            o_BDI_EN_RST_n,

    //page register shift register parallel load enable
    output  wire            o_PGREG_SRLD_EN,
    
    //bubble IO related
    output  wire            o_ACC_START,
    output  wire            o_REP_START,
    
    //???
    output  wire            o_CMD_ACCEPTED_n //???
);


/*
        FSM STATE

    0: Initial state
    1: Bootloader Z14(CRC14 zero) flag check state. If nz, hangs on here.
    2: User mode idle
    3: R/W request acceptance
    4: Wait for page swapping
    5: Wait for page replication
    6: Swap start
    7: Page R/W operation

    bootloader:
    0->1->2

    page read:
    2->3->5->7->2

    page write:
    2->3->4->7->2
*/

///////////////////////////////////////////////////////////
//////  FSM STATE REGISTER
////

reg     [2:0]   fsmstat_sr = 3'b000; //state register
wire            fsmstat_shift; //shift flag: 4-5-6, Q38 SRNAND
SRNAND Q38 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[7]), .i_R_n(i_ROT20_n[4]), .o_Q(), .o_Q_n(fsmstat_shift));

//state adder variable
reg     [1:0]   fsmstat_nxtstat = 2'd3; //3: 1'b0, 2: nROT20[5], 1: nROT20[4], 0: nROT20[4, 5]
reg             fsmstat_var;

always @(*) begin
    case(fsmstat_nxtstat)
        2'd0: fsmstat_var <= ~(i_ROT20_n[4] & i_ROT20_n[5]);
        2'd1: fsmstat_var <= ~i_ROT20_n[4];
        2'd2: fsmstat_var <= ~i_ROT20_n[5];
        2'd3: fsmstat_var <= 1'b0;
    endcase
end
//wire            fsmstat_var = (fsmstat_nxtstat[1] == 1'b1) ? ((fsmstat_nxtstat[0] == 1'b1) ? 1'b0 : ~i_ROT20_n[5]) :
//                                                            ((fsmstat_nxtstat[0] == 1'b1) ? ~i_ROT20_n[4] : ~(i_ROT20_n[4] & i_ROT20_n[5]));

//full adder
wire            fsmstat_fa_sum, fsmstat_fa_cout;
reg             fsmstat_fa_cflag;
FA P56 (.i_A(fsmstat_var), .i_B(fsmstat_sr[0]), .i_CIN(fsmstat_fa_cflag), .o_S(fsmstat_fa_sum), .o_COUT(fsmstat_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        fsmstat_fa_cflag <= fsmstat_fa_cout & i_ROT20_n[19];
    end
end

//fsm state shift
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(fsmstat_shift == 1'b1) begin //shift
            fsmstat_sr[2] <= fsmstat_fa_sum & i_SYS_RUN_FLAG;
            fsmstat_sr[1:0] <= fsmstat_sr[2:1];
        end
        else begin //hold
            fsmstat_sr[2] <= fsmstat_sr[2] & i_SYS_RUN_FLAG;
            fsmstat_sr[1:0] <= fsmstat_sr[1:0];
        end
    end
end

//parallel load
reg     [2:0]   fsmstat_parallel = 3'b000;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[7] == 1'b0) begin //D-latch loads at nROT20[8]
            fsmstat_parallel <= fsmstat_sr;
        end
        else begin
            fsmstat_parallel <= fsmstat_parallel;
        end
    end
end



///////////////////////////////////////////////////////////
//////  FSM FLAG
////

reg             fsmflag;
always @(*) begin
    case(fsmstat_parallel)
        3'd0: fsmflag <= ~i_SUPBD_ACT_n;
        3'd1: fsmflag <= i_OP_DONE;
        3'd2: fsmflag <= 1'b0;
        3'd3: fsmflag <= 1'b0;
        3'd4: fsmflag <= i_PGCMP_EQ;
        3'd5: fsmflag <= i_PGCMP_EQ;
        3'd6: fsmflag <= 1'b0;
        3'd7: fsmflag <= &{~i_ROT20_n[8], ~i_SUPBD_ACT_n, ~i_VALPG_ACC_FLAG, (i_PGREG_SR_SHIFT & i_MUXED_BDO_EN_DLYD), i_SUMEQ_n};
    endcase
end



///////////////////////////////////////////////////////////
//////  AND-OR MATRIX
////

wire    [7:0]   pla_output;

reg     [1:0]   command_a_en = 2'b00; //initialize output register
reg     [1:0]   command_b_en = 2'b00;

reg     [1:0]   command_a_0 = 2'b00; //command synchronizer chain: async input from CPU(RD/WR commands)
reg     [1:0]   command_b_0 = 2'b00;

reg     [1:0]   command_a_1 = 2'b00;
reg     [1:0]   command_b_1 = 2'b00;

K005297_fsm_pla pla_main
(
    .i_A                        (i_CMDREG_RDREQ             ), //CMDREG.RDREQ
    .i_B                        (i_CMDREG_WRREQ             ), //CMDREG.WRREQ
    .i_C                        (fsmstat_parallel[0]        ), //FSMSTAT.D0
    .i_D                        (fsmstat_parallel[1]        ), //FSMSTAT.D1
    .i_E                        (fsmstat_parallel[2]        ), //FSMSTAT.D2
    .i_F                        (i_OP_DONE                  ), //OP_DONE
    .i_G                        (fsmflag                    ), //FSMFLAGIN
    .i_H                        (i_SYS_ERR_FLAG             ), //SYS_ERR_FLAG

    .o_S                        (pla_output[5]               ),
    .o_T                        (pla_output[4]               ),
    .o_U                        (pla_output[3]               ),

    .o_V                        (pla_output[2]               ),
    .o_W                        (pla_output[1]               ),
    .o_X                        (pla_output[0]               ),

    .o_Y                        (pla_output[7]               ),
    .o_Z                        (pla_output[6]               )
);

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[9] == 1'b0) begin //D-latch loads at nROT20[10]
            fsmstat_nxtstat <= pla_output[7:6];
        end
    end
end


wire            r59 = pla_output[5] & ~pla_output[4] & ~pla_output[3];



//
//  FSM COMMAND/ENABLE SYNCHRONIZER CHAIN(2)
//

//The FSM gets bubble RW command from the asynchronous latch and decodes it.
//Sample the value @ negedge ROT20_n[10] and shift it @ posedge ROT20_n[10].
//RW command output automatically disabled @ ROT20_n[10], so shifter's output
//can be presented @ posedge ROT20_n[10].

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[9] == 1'b0) begin //D-latch loads at nROT20[10]
            command_a_en[0] <= pla_output[5];
            command_a_en[1] <= 1'b0;

            command_b_en[0] <= pla_output[2];
            command_b_en[1] <= 1'b0;
        end
        else if(i_ROT20_n[10] == 1'b0) begin
            command_a_en[1] <= command_a_en[0];

            command_b_en[1] <= command_b_en[0];
        end
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_ROT20_n[9] == 1'b0) begin //D-latch loads at nROT20[10]
            command_a_0 <= pla_output[4:3];

            command_b_0 <= pla_output[1:0];
        end
        else if(i_ROT20_n[10] == 1'b0) begin
            command_a_1 <= command_a_0;

            command_b_1 <= command_b_0;
        end
    end
end



///////////////////////////////////////////////////////////
//////  COMMAND DECODER
////


assign  o_CMDREG_RST_n =      ~&{ command_a_1[1],  command_a_1[0], command_a_en[1]}; //NAND /3'b111

assign  o_FSMERR_RESTART_n =  ~&{~command_a_1[1],  command_a_1[0], command_a_en[1]}; //NAND /3'b101

assign  o_BDI_EN_SET_n =      ~&{ command_b_1[1],  command_b_1[0], command_b_en[1]}; //NAND /3'b111
assign  o_BDI_EN_RST_n =      ~&{~command_b_1[1],  command_b_1[0], command_b_en[1]}; //NAND /3'b101

assign  o_PGREG_SRLD_EN =      &{ command_a_1[1], ~command_a_1[0], command_a_en[1]}; //AND 3'b110

assign  o_ACC_START =          &{ command_b_1[1], ~command_b_1[0], command_b_en[1]}; //AND 3'b110
assign  o_REP_START =          &{~command_b_1[1], ~command_b_1[0], command_b_en[1]}; //AND 3'b100

assign  o_CMD_ACCEPTED_n =    ~&{~command_a_1[1], ~command_a_1[0], command_a_en[1]}; //NAND 3'b100 //NOR??

endmodule


module K005297_fsm_pla (
    input   wire            i_A,
    input   wire            i_B,
    input   wire            i_C,
    input   wire            i_D,
    input   wire            i_E,
    input   wire            i_F,
    input   wire            i_G,
    input   wire            i_H,

    output  wire            o_S,
    output  wire            o_T,
    output  wire            o_U,
    output  wire            o_V,
    output  wire            o_W,
    output  wire            o_X,
    output  wire            o_Y,
    output  wire            o_Z
);

//internal wires
wire    A = i_A; //CMDREG.RDREQ
wire    B = i_B; //CMDREG.WRREQ
wire    C = i_C; //FSMSTAT.D0
wire    D = i_D; //FSMSTAT.D1
wire    E = i_E; //FSMSTAT.D2
wire    F = i_F; //F25/Q
wire    G = i_G; //FSMFLAGIN
wire    H = i_H; //SYS_ERR_FLAG


//AND array 1
wire    S36 =   &{    A, ~B,  C, ~D,  E, ~F,     ~H   };
wire    S44 =   &{   ~A,  B,             ~F, ~G       };
wire    S43 =   &{   ~A,  B, ~C, ~D,  E, ~F,     ~H   };
wire    R49 =   &{           ~C,  D, ~E,         ~H   };
wire    S42 =   &{   ~A,  B, ~C,  D,  E, ~F,     ~H   };
wire    R50 =   &{            C,  D, ~E,         ~H   };
wire    S41 =   &{    A, ~B,             ~F, ~G       };
wire    S29 =   &{   ~A, ~B,             ~F, ~G       };
wire    R36 =   &{            C,  D,  E,         ~H   };
wire    S37 =   &{   ~A, ~B,              F,  G       };

//misc
wire    S45 = S44 | S37; //~A
wire    R33 = A ^ B;

//AND array 2
wire    R35 =   &{               ~D, ~E,         ~H   } & S29;
wire    R32 =   &{   ~A,  B                           } & R36;
wire    S31 =   &{                           ~G       } & S43;
wire    R29 =   &{    A, ~B,             ~F           } & R36;
wire    S30 =   &{                           ~G       } & S36;
wire    S27 =                                             R49 & S29;
wire    S50 =   &{   ~A, ~B, ~C, ~D, ~E,          H   };
wire    S49 =   &{   ~A, ~B, ~C, ~D, ~E, ~F,  G, ~H   };
wire    S46 =                                             S44 & R50;
wire    S38 =   &{                            G       } & S36;
wire    T42 =   &{                           ~G       } & S42;
wire    T40 =   &{                            G       } & S43;
wire    S48 =                                             R49 & S41;
wire    S47 =                                             S44 & R49;
wire    R52 =                                             R50 & S41;
wire    S51 =   &{            C, ~D, ~E,         ~H   } & S45;
wire    T41 =   &{                            G       } & S42;
wire    R34 =                                             S29 & R36;
wire    R37 =   &{            C,  D,  E,          H   } & R33;
wire    R30 =   &{    A, ~B,              F           } & R36;
wire    S40 =   &{            C, ~D, ~E,          H   } & S29;

//OR array
wire    S28 = |{R35, R32, S31, R29, S30, S27};

assign  o_S  = ~(|{S50, S49, S46, S38, T42, T40, R52, T41, R34} | S28);
assign  o_T  = ~ S40;
assign  o_U  = ~|{S48, S47};

assign  o_V  = ~(|{S49, T42, T40, T41, R34, S40} | S28);
assign  o_W  = ~|{S38, S47};
assign  o_X  = ~|{S46, S38, R52};

assign  o_Y  = ~|{S49, S46, T42, S48, S47, S51, T41, R34, R37, R30};
assign  o_Z  = ~|{S38, T40, R52, T41, R34, R37, R30, S40};

endmodule

module K005297_functrig (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_HALT, //TST4
    input   wire            i_SYS_RST_n,

    input   wire            i_UMODE_n,
    input   wire            i_CYCLECNTR_LSB,

    input   wire            i_ACC_INVAL_n,
    input   wire            i_PGCMP_EQ,
    input   wire            i_SYNCTIP_n,
    input   wire            i_BDI_EN,

    output  wire            o_ACC_END,
    output  wire            o_SWAP_START,
    output  wire            o_ACQ_START,
    output  wire            o_ADDR_RST
);


///////////////////////////////////////////////////////////
//////  ACCESS TERMINATION
////

//terminates magnetic field roation after 7030us
wire            const702 = ~&{i_ROT20_n[9], i_ROT20_n[7], i_ROT20_n[5], i_ROT20_n[4], i_ROT20_n[3], i_ROT20_n[2], i_ROT20_n[1]};
reg             eq702_flag_n = 1'b1;
reg             acc_end_flag_n = 1'b1;

assign  o_ACC_END = ~acc_end_flag_n;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq702_flag_n <= (((i_CYCLECNTR_LSB | i_HALT) ^ const702) | eq702_flag_n | i_UMODE_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        acc_end_flag_n <= (i_SYS_RST_n == 1'b0) ? 1'b1 : 
                                                  (i_ROT20_n[10] == 1'b0) ? eq702_flag_n : acc_end_flag_n;
    end
end



///////////////////////////////////////////////////////////
//////  SWAP START
////

//turn on swap gate after 6240us
wire            const623 = ~&{i_ROT20_n[9], i_ROT20_n[6], i_ROT20_n[5], i_ROT20_n[3], i_ROT20_n[2], i_ROT20_n[1], i_ROT20_n[0]};
reg             eq623_flag_n = 1'b1;
reg             swap_start_flag_n = 1'b1;

assign  o_SWAP_START = ~swap_start_flag_n;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq623_flag_n <= (((i_CYCLECNTR_LSB | i_HALT) ^ const623) | eq623_flag_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        swap_start_flag_n <= (i_BDI_EN == 1'b1) ? 1'b1 : 
                                               (i_ROT20_n[10] == 1'b0) ? eq623_flag_n : swap_start_flag_n;
    end
end



///////////////////////////////////////////////////////////
//////  ACQUISITION START
////

//start bubble data acquisition after 980us
wire            const97 = ~&{i_ROT20_n[6], i_ROT20_n[5], i_ROT20_n[0]};
reg             eq97_flag_n = 1'b1;
reg             acq_start_flag_n = 1'b1;
wire            acq_start_flag_feedback = (i_SYS_RST_n == 1'b0) ? 1'b1 : 
                                                                  (i_ROT20_n[10] == 1'b0) ? (eq97_flag_n | ~i_BDI_EN) : acq_start_flag_n;

assign  o_ACQ_START = ~acq_start_flag_n;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq97_flag_n <= (((i_CYCLECNTR_LSB | i_HALT) ^ const97) | eq97_flag_n | i_UMODE_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        acq_start_flag_n <= (|{~i_ACC_INVAL_n, i_BDI_EN, ~i_PGCMP_EQ, i_ROT20_n[14]} & i_SYNCTIP_n) & acq_start_flag_feedback;
    end
end


//delayed ~ROT20_n[18] ...why not D19?
reg             rot20_d18_dlyd;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        rot20_d18_dlyd <= ~i_ROT20_n[18];
    end
end

assign  o_ADDR_RST = o_ACQ_START & rot20_d18_dlyd;

endmodule

module K005297_invalpgdet (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_TST, //test pin(normally 1)
    input   wire            i_PGREG_SR_LSB, //page number shift register's lsb
    input   wire            i_INVALPG_LSB, //invalid page reference point
    input   wire            i_UMODE_n,
    input   wire            i_PGCMP_EQ,

    //output
    output  wire            o_ACC_INVAL_n,
    output  wire            o_VALPG_FLAG_SET_n
);


///////////////////////////////////////////////////////////
////// INVALID PAGE DETECTOR
////

//invalid page
reg             invalid_page = 1'b0;
reg             access_invalid_n = 1'b1;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        //TST3 = 1: eq 0
        //TST3 = 0: gte INVALPG
        invalid_page <= ~(~(((i_TST | i_INVALPG_LSB) & i_PGREG_SR_LSB) | ((i_TST | i_INVALPG_LSB | i_PGREG_SR_LSB) & invalid_page)) | ~i_ROT20_n[19]);

        access_invalid_n <= (i_ROT20_n[12] == 1'b0) ? (invalid_page & ~i_UMODE_n) : (access_invalid_n & ~i_UMODE_n);
    end
end

assign  o_ACC_INVAL_n = access_invalid_n & i_PGCMP_EQ;
assign  o_VALPG_FLAG_SET_n = ~(o_ACC_INVAL_n & ~i_ROT20_n[14]);

endmodule

module K005297_invalpgdgen
(
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //control
    input   wire            i_PGREG_D2,
    input   wire            i_PGREG_D8,

    input   wire            i_EFFBDO_EN,
    input   wire            i_BDO_EN_n,
    input   wire            i_GLCNT_RD,

    input   wire            i_VALPG_ACC_FLAG,
    input   wire            i_UMODE_n,
    input   wire            i_SUPBD_ACT_n,
    input   wire            i_SYNCED_FLAG,
    input   wire            i_ALD_nB_U,

    input   wire            i_BDI,
    output  wire            o_MUXED_BDI,
    output  wire            o_EFF_MUXED_BDI
);



///////////////////////////////////////////////////////////
//////  INVALID PAGE DATA GENERATOR
////

//muxed bdi = bubble data + invalid page data
//effective muxed bdi = excepts supplementary bubble data
assign  o_EFF_MUXED_BDI = o_MUXED_BDI & i_SUPBD_ACT_n;


//SR shift enable
wire            sr8_last_shift; //shift flag
wire            sr8_shift = (i_EFFBDO_EN & i_GLCNT_RD) | (i_BDO_EN_n & sr8_last_shift); //mux?

SRNAND F37 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[8]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(sr8_last_shift));


//shift register
reg     [7:0]   sr8;
wire            sr8_msb;
wire            sr8_lsb = sr8[0];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr8_shift == 1'b1) begin
            sr8[7] <= sr8_msb;
            sr8[6:0] <= sr8[7:1];
        end
        else begin
            sr8 <= sr8;
        end
    end
end


//adder
wire            sr8_const, sr8_fa_sum, sr8_fa_cout; //FA carry out
reg             sr8_fa_cflag = 1'b0; //FA carry storage
assign          sr8_msb = (i_ALD_nB_U == 1'b0) ? sr8_fa_sum & i_SYNCED_FLAG : sr8_lsb & i_SYNCED_FLAG; //bootloader : user pages

FA Q59 (.i_A(o_EFF_MUXED_BDI), .i_B(sr8_lsb), .i_CIN(sr8_fa_cflag), .o_S(sr8_fa_sum), .o_COUT(sr8_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr8_shift == 1'b1) begin
            sr8_fa_cflag <= sr8_fa_cout & (i_SUPBD_ACT_n & ~i_ALD_nB_U);
        end
        else begin
            sr8_fa_cflag <= sr8_fa_cflag & (i_SUPBD_ACT_n & ~i_ALD_nB_U);
        end
    end
end


//page number synchronizer(signal from true D-latch)
reg     [1:0]   sr8_bitmux_sel_0;
reg     [1:0]   sr8_bitmux_sel_1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        sr8_bitmux_sel_0 <= {i_PGREG_D8, i_PGREG_D2};
        sr8_bitmux_sel_1 <= sr8_bitmux_sel_0;
    end
end

//sr8 bit selector for scrambling?
reg             sr8_bitmux;
always @(*) begin
    case(sr8_bitmux_sel_1)
        2'b00: sr8_bitmux <= sr8[7];
        2'b01: sr8_bitmux <= sr8[6];
        2'b10: sr8_bitmux <= sr8[5];
        2'b11: sr8_bitmux <= sr8[4];
    endcase
end

assign          o_MUXED_BDI = i_BDI ^ (sr8_bitmux & ~(i_VALPG_ACC_FLAG | i_UMODE_n | ~i_SUPBD_ACT_n));

endmodule

module K005297_mskldtimer (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_ACC_ACT_n,
    input   wire            i_ACQ_MSK_LD,


    output  reg             o_MSKREG_SR_LD = 1'b0
);


reg     [3:0]   mask_load_timer = 4'hF;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if((i_ACC_ACT_n | (o_MSKREG_SR_LD & ~i_ROT20_n[1])) == 1'b1) begin //reset
            mask_load_timer <= 4'hF;
        end
        else begin
            if(~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n)) == 1'b1) begin //0-5_10-15
                if(mask_load_timer == 4'h0) begin
                    mask_load_timer <= 4'hF;
                end
                else begin
                    mask_load_timer <= mask_load_timer - 4'h1;
                end
            end
            else begin
                mask_load_timer <= mask_load_timer;
            end
        end
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        o_MSKREG_SR_LD <= ((i_ROT20_n[3] & i_ROT20_n[18]) == 1'b0) ? (&{~mask_load_timer} | i_ACQ_MSK_LD) : o_MSKREG_SR_LD;
    end
end

endmodule

module K005297_mskreg (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_4BEN_n,
    input   wire            i_MSKREG_LD,
    input   wire            i_MSKREG_SR_LD,
    input   wire            i_BOOTEN_n,

    //data
    input   wire    [15:0]  i_DIN,

    //serial data
    output  wire            o_MSKREG_SR_LSB
);



///////////////////////////////////////////////////////////
//////  MASK REGISTER
////

//D latch * 16
wire    [15:0]  mskreg_q;
DL #(.dw(16)) MSKREG (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_EN(i_MSKREG_LD), .i_D(i_DIN), .o_Q(mskreg_q), .o_Q_n());

//mask register sr control
wire    [1:0]   mskreg_sr_ctrl; //11:hold(invalid), 10:load, 01:shift, 00:hold
assign  mskreg_sr_ctrl[1] = ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n)) & (i_MSKREG_SR_LD & i_BOOTEN_n); //0-5_10-15
assign  mskreg_sr_ctrl[0] = ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n)) & ~(i_MSKREG_SR_LD & i_BOOTEN_n);

//mask register sr
reg     [15:0]  mskreg_sr;
assign  o_MSKREG_SR_LSB = mskreg_sr[0];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        case(mskreg_sr_ctrl)
            2'b11: begin
                mskreg_sr <= mskreg_sr;
            end
            2'b10: begin //load
                mskreg_sr <= mskreg_q;
            end
            2'b01: begin //shift
                mskreg_sr[15] <= ~i_BOOTEN_n;
                mskreg_sr[14:0] <= mskreg_sr[15:1];
            end
            2'b00: begin
                mskreg_sr <= mskreg_sr;
            end
        endcase
    end
end

endmodule

module K005297_pgcmp (
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

module K005297_pgreg (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //control
    input   wire            i_PGREG_LD, //async
    input   wire            i_PGREG_SR_LD_EN,
    output  wire            o_PGREG_SR_SHIFT,
    
    //data
    input   wire    [15:0]  i_DIN,

    output  wire            o_PGREG_D2,
    output  wire            o_PGREG_D8,
    output  wire            o_PGREG_SR_LSB
);



///////////////////////////////////////////////////////////
//////  PAGE REGISTER
////

/*
//Pseudo D latch * 12
wire    [11:0]  pgreg_q;
DL #(.dw(12)) PGREG (.i_CLK(MCLK), .i_CEN_n(CLK4P_n), .i_EN(i_PGREG_LD), .i_D(i_DIN[11:0]), .o_Q(pgreg_q), .o_Q_n());
*/

//True D latch primitive
reg     [11:0]  pgreg_q;
always @(i_PGREG_LD) begin
    if(i_PGREG_LD == 1'b1) begin
        pgreg_q <= i_DIN[11:0];
    end
    else begin
        pgreg_q <= pgreg_q;
    end
end

assign          o_PGREG_D2 = pgreg_q[2];
assign          o_PGREG_D8 = pgreg_q[8];

//shift flag
SRNAND N28 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(o_PGREG_SR_SHIFT));


//page shift register
reg     [11:0]  pgsr = 12'h000;
assign          o_PGREG_SR_LSB = pgsr[0];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        case({(i_PGREG_SR_LD_EN & ~i_ROT20_n[19]), o_PGREG_SR_SHIFT})
            2'b00: pgsr <= pgsr; //hold
            2'b01: begin pgsr[10:0] <= pgsr[11:1]; pgsr[11] <= o_PGREG_SR_LSB & i_SYS_RST_n; end //shift
            2'b10: pgsr <= pgreg_q; //load                                              TEST//
            2'b11: pgsr <= pgsr; //hold(invalid)
        endcase
    end
end

endmodule

module K005297_relpgcntr (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_RELPGCNTR_CNT_STOP,
    input   wire            i_RELPGCNTR_CNT_START,
    input   wire            i_ALD_nB_U,

    output  wire            o_RELPGCNTR_LSB
);



///////////////////////////////////////////////////////////
//////  RELATIVE PAGE COUNTER
////

/*
    gte(greater than or equal) flag(>= 1531 evaluation)
    relative page 0-1530: +522
    relative page 1531-2052: -1531(loop)
*/


//SR shift enable
wire            relpgcntr_shift; //shift flag
SRNAND I24 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(relpgcntr_shift));


//const add enable
wire            relpgcntr_add_en;
SRNOR I34 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S(i_RELPGCNTR_CNT_STOP), .i_R(i_RELPGCNTR_CNT_START), .o_Q(), .o_Q_n(relpgcntr_add_en));

 
reg     [11:0]  relpgcntr = 12'd0; //abs page counter
wire            relpgcntr_const, relpgcntr_fa_sum, relpgcntr_fa_cout; //FA carry out
reg             relpgcntr_fa_cflag = 1'b0; //FA carry storage
assign  o_RELPGCNTR_LSB = relpgcntr_fa_sum & i_ALD_nB_U;

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(relpgcntr_shift == 1'b1) begin
            relpgcntr[11] <= o_RELPGCNTR_LSB;
            relpgcntr[10:0] <= relpgcntr[11:1];
        end
        else begin
            relpgcntr <= relpgcntr;
        end
    end
end


//constant generator: +522 or -1531
wire            constP522 = ~&{i_ROT20_n[9], i_ROT20_n[3], i_ROT20_n[1]};
wire            constN1531 = ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]};
reg             gte1531_evalreg = 1'b0;
reg             gte1531_flag = 1'b0;
assign  relpgcntr_const = (gte1531_flag == 1'b0) ? constP522 : constN1531;
                                                //+522 : -1531
//evaluator: greater than or equal to 1531
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        gte1531_evalreg <= ((relpgcntr_fa_sum & ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) | 
                           ((o_RELPGCNTR_LSB | ~&{i_ROT20_n[11], i_ROT20_n[9], i_ROT20_n[2], i_ROT20_n[0]}) & gte1531_evalreg)) &
                           i_ROT20_n[19];

        gte1531_flag <= (i_ROT20_n[12] == 1'b0) ? gte1531_evalreg : gte1531_flag;
    end
end


//adder
FA J30 (.i_A(relpgcntr_add_en & relpgcntr_const), .i_B(relpgcntr_fa_cflag), .i_CIN(relpgcntr[0]), .o_S(relpgcntr_fa_sum), .o_COUT(relpgcntr_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        relpgcntr_fa_cflag <= relpgcntr_fa_cout & i_ROT20_n[19];
    end
end

endmodule

module K005297_spdet (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //control
    input   wire            i_BDI, //bubble input data stream
    input   wire            i_GLCNT_RD, //good loop count
    input   wire            i_BOOTEN_n, //bootloader enable(bubble cartridge)
    input   wire            i_BSEN_n, //bubble shift enable(bc)
    input   wire            i_4BEN_n,

    //output
    output  wire            o_SYNCTIP_n,
    output  wire            o_SYNCED_FLAG,
    output  wire            o_SYNCED_FLAG_SET_n
);


//zero bit counter: needs 128 zero bits + 1 "one" bit
reg     [7:0]   zerobit_cntr = 8'd255;
wire            zerobit_cntr_rst;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(zerobit_cntr_rst == 1'b1) begin
            zerobit_cntr <= 8'd255;
        end
        else begin
            if(i_GLCNT_RD == 1'b1) begin
                if(zerobit_cntr == 8'd0) begin //loop counter
                    zerobit_cntr <= 8'd255;
                end
                else begin
                    zerobit_cntr <= zerobit_cntr - 8'd1;
                end
            end
            else begin //hold
                zerobit_cntr <= zerobit_cntr;
            end
        end
    end
end


//invalid pattern: reset the counter if "one" comes in before a complete pattern is detected
reg             invalid_pattern = 1'b1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        invalid_pattern <= (i_GLCNT_RD == 1'b0) ? invalid_pattern : i_BDI; //0:1
    end
end


//zero bit counter reset and synced flag SR latch
wire            synced_flag;
assign  o_SYNCED_FLAG_SET_n = i_BOOTEN_n | o_SYNCTIP_n;

assign  zerobit_cntr_rst = i_BSEN_n | synced_flag | invalid_pattern; //resets zerobit counter
assign  o_SYNCED_FLAG = synced_flag;

SRNAND D60 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_SYNCED_FLAG_SET_n), .i_R_n(i_SYS_RST_n), .o_Q(synced_flag), .o_Q_n());


//sync tip
wire            synctip_en = (i_4BEN_n == 1'b0) ? ~i_ROT20_n[18] : ~i_ROT20_n[8]; //4bit mode : 2bit mode
wire            synctip_4b = ~&{synctip_en, i_BDI, ~zerobit_cntr[7]}; //D51 TFF
reg     [7:0]   synctip_2b_dlyd;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        synctip_2b_dlyd[7] <= synctip_4b;
        synctip_2b_dlyd[6:0] <= synctip_2b_dlyd[7:1];
    end
end

assign  o_SYNCTIP_n = (i_4BEN_n == 1'b0) ? synctip_4b : synctip_2b_dlyd[0]; //4bit mode : 2bit mode

endmodule

module K005297_sumcmp (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //data in
    input   wire            i_EFF_MUXED_BDI,

    //control
    input   wire            i_UMODE_n,
    input   wire            i_BDO_EN_n,
    input   wire            i_EFFBDO_EN,
    input   wire            i_GLCNT_RD,
    input   wire            i_PGREG_SR_SHIFT,
    input   wire            i_DMADREG_BDLD_EN,

    input   wire            i_MUXED_BDO_EN_DLYD,
    input   wire            i_SUPBD_ACT_n,
    input   wire            i_ALD_nB_U,

    //output
    output  wire            o_INVALPG_LSB,
    output  reg             o_SUMEQ_n
);


//
//  VARIABLE
//

//variable shift register
reg     [11:0]  sr_var = 12'h000;
wire            sr_var_shift = (i_EFFBDO_EN & i_GLCNT_RD) | (i_BDO_EN_n & i_PGREG_SR_SHIFT);

//sr_var serial FA
wire            sr_var_fa_sum, sr_var_fa_cout; //FA carry out
reg             sr_var_fa_cflag = 1'b0; //FA carry storage

//msb/lsb
wire            sr_var_msb = sr_var_fa_sum & i_MUXED_BDO_EN_DLYD;
wire            sr_var_lsb = (i_UMODE_n == 1'b1) ? sr_var[0] : sr_var[4]; //bootloader:user page


//Full adder
FA N48 (.i_A(i_EFF_MUXED_BDI), .i_B(sr_var_fa_cflag), .i_CIN(sr_var_lsb), .o_S(sr_var_fa_sum), .o_COUT(sr_var_fa_cout));

//carry storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        sr_var_fa_cflag <= (sr_var_shift == 1'b1) ? (sr_var_fa_cout & ~i_DMADREG_BDLD_EN) : (sr_var_fa_cflag & ~i_DMADREG_BDLD_EN); //update:hold
    end
end


//sr
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr_var_shift == 1'b1) begin
            sr_var[11] <= sr_var_msb;
            sr_var[10:0] <= sr_var[11:1];
        end
        else begin
            sr_var <= sr_var;
        end
    end
end



//
//  CONSTANT
//

//constant shift register
reg     [11:0]  sr_const = 12'h000;
wire            sr_const_shift;

//msb in
wire            sr_const_msb = (&{i_MUXED_BDO_EN_DLYD, i_PGREG_SR_SHIFT, ~i_SUPBD_ACT_n, ~i_ALD_nB_U} == 1'b1) ? sr_var_lsb : sr_const[0]; //load : hold
wire            sr_const_lsb = sr_const[0];
assign          o_INVALPG_LSB = sr_const_lsb;

//shift
SRNAND O35 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(sr_const_shift));


//sr
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(sr_const_shift == 1'b1) begin
            sr_const[11] <= sr_const_msb;
            sr_const[10:0] <= sr_const[11:1];
        end
        else begin
            sr_const <= sr_const;
        end
    end
end



//
//  COMPARATOR
//

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        o_SUMEQ_n <= ((sr_var_lsb ^ sr_const_lsb) | o_SUMEQ_n) & i_ROT20_n[19];
    end
end

endmodule

module K005297_supbdlcntr (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //control
    input   wire            i_SYS_RUN_FLAG,

    input   wire            i_4BEN_n,
    input   wire            i_BDI_EN,
    input   wire            i_SUPBD_START_n,

    input   wire            i_MSKREG_SR_LSB,
    input   wire            i_GLCNT_RD,


    output  wire            o_SUPBDLCNTR_CNT,
    output  wire            o_SUPBD_ACT_n,
    output  wire            o_SUPBD_END_n
);



///////////////////////////////////////////////////////////
//////  SUPPLEMENTARY BUBBLE DATA LENGTH COUNTER
////

//count enable
SRNAND J34 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_SUPBD_END_n), .i_R_n(i_SUPBD_START_n), .o_Q(o_SUPBD_ACT_n), .o_Q_n());

//delay something?
reg             supbd_act_n_dlyd = 1'b1;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n)) == 1'b1) begin //0-5_10-15
            supbd_act_n_dlyd <= o_SUPBD_ACT_n;
        end
        else begin
            supbd_act_n_dlyd <= supbd_act_n_dlyd;
        end
    end
end

//supplementary data count up
wire            glcnt_wr = ((~supbd_act_n_dlyd | o_SUPBD_ACT_n) & ~(i_ROT20_n[3] & i_ROT20_n[8] & ~(~(i_ROT20_n[13] & i_ROT20_n[18]) & ~i_4BEN_n)) & i_MSKREG_SR_LSB);
assign          o_SUPBDLCNTR_CNT = (i_BDI_EN == 1'b0) ? glcnt_wr : i_GLCNT_RD;

//supplementary data bit counter
reg     [3:0]   supbd_length_cntr = 4'hF;

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(o_SUPBD_ACT_n == 1'b1) begin //reset
            supbd_length_cntr <= 4'hF;
        end
        else begin
            if(o_SUPBDLCNTR_CNT == 1'b1) begin
                if(supbd_length_cntr == 4'h0) begin
                    supbd_length_cntr <= 4'hF;
                end
                else begin
                    supbd_length_cntr <= supbd_length_cntr - 4'h1;
                end
            end
            else begin
                supbd_length_cntr <= supbd_length_cntr;
            end
        end
    end
end

//flag
wire            eq14 = (supbd_length_cntr == 4'h1) ? 1'b1 : 1'b0; //4'd14
assign  o_SUPBD_END_n = (~(eq14 & ~(i_ROT20_n[0] & i_ROT20_n[5] & ~(~(i_ROT20_n[10] & i_ROT20_n[15]) & ~i_4BEN_n))) & i_SYS_RUN_FLAG); //0-5_10-15

endmodule

module K005297_supervisor (
    //master clock
    input   wire            i_MCLK,

    //chip clock from bubble cart, synchronized to i_MCLK
    input   wire            i_CLK4M_PCEN_n,

    //master reset
    input   wire            i_MRST_n,

    //halt
    input   wire            i_HALT_n,

    //subclock control
    input   wire            i_CLK2M_STOPRQ0_n,
    input   wire            i_CLK2M_STOPRQ1_n,
    output  wire            o_CLK2M_STOP_n,
    output  wire            o_CLK2M_STOP_DLYD_n,
    output  wire            o_CLK2M_PCEN_n,

    //rotators
    output  wire    [7:0]   o_ROT8,
    output  wire    [19:0]  o_ROT20_n,

    //system flags
    output  wire            o_SYS_RST_n,
    output  wire            o_SYS_RUN_FLAG,
    output  wire            o_SYS_RUN_FLAG_SET_n
);

/*
    CLOCKING INFORMATION

    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|


    NCLK
    orig in     _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|

    stage 0     ¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|________
    stage 5     __________|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯
    0 AND 5     _______________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|


    PCLK
    orig in     ¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|________

    stage 0     _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    stage 5     ¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_____
    0 AND 5     _______|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|_____


    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    4M NCLK     _______________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|
    4M PCLK     _______|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|_____

    ROT8        -(7)---|------(0)------|------(1)------|------(2)------|------(3)------|------(4)------|------(5)------|----(6)-
    ROT8[0]     _______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________________________________________________________

    C2STOPDLYn  _______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    A59 OUT     ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯
    A60 OUT     _______________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________

    A62 EN      _______________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|
    A62 OUT     _______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|

    A60         _______________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________
    A62         _______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|

    A64(01)PCLK _______________________________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|
    A66(10)NCLK _______________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|_______________________|¯¯¯¯¯¯¯|________________

    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    2MHz        ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯


    4MHz        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    2MHz        ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________

    ROT8        -(7)---|------(0)------|------(1)------|------(2)------|------(3)------|------(4)------|------(5)------|----(6)-
    PORCNTR     -----------------(7)-------------------|-------------------------------------(6)--------------------------------
    4M PCLK     _______|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|____________|¯¯|_____

    C2RDYn      ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|__|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    OPSTOP      ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________________________________________
    ROT20n      -----------------------(invalid)-----------------------|--------------(0)--------------|--------------(1)-------
*/


///////////////////////////////////////////////////////////
//////  GLOBAL CLOCKS / FLAGS
////

//all stoarge elements works at falling edge of 4M/2M
wire            CLK4P_n = i_CLK4M_PCEN_n;   //4MHz clock from bubble memory cartridge 12MHz/3
wire            CLK2P_n;                    //2MHz internal subclock that can be controlled by start/stop logic



///////////////////////////////////////////////////////////
//////  MODULE ROT8
////

K005297_supervisor_rot8 rot8_main (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_STOP_n(i_HALT_n), .o_ROT8(o_ROT8)); //FREE-RUNNING 8-BIT ROTATOR, rotates bit 1 from LSB to MSB 



///////////////////////////////////////////////////////////
//////  CLK2M(SUBCLK) CONTROL/GENERATOR
////

//subclk control
//SYS_RUN_FLAG가 0이면 clk2m시동을 걸어줌, 1로 올라간 후에는 clk2m정지 플래그들이 제어
wire            clk2m_ctrl = &{i_MRST_n, i_CLK2M_STOPRQ0_n, i_CLK2M_STOPRQ1_n} | ~o_SYS_RUN_FLAG; //A37 A36 A38

reg             A41 = 1'b0;
wire            clk2m_stop_n = i_MRST_n & A41;
wire            clk2m_stop_dlyd_n;
assign  o_CLK2M_STOP_n = clk2m_stop_n;
assign  o_CLK2M_STOP_DLYD_n = clk2m_stop_dlyd_n;

always @(posedge i_MCLK) begin
    if(!CLK4P_n) begin
        A41 <= (o_ROT8[5] == 1'b0) ? A41 : clk2m_ctrl; //MUX 0:1
    end
end

DL A42 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_EN(o_ROT8[0]), .i_D(clk2m_stop_n), .o_Q(clk2m_stop_dlyd_n), .o_Q_n());

//subclk generator
//negative clock enable신호 생성
reg             A59 = 1'b0;
always @(posedge i_MCLK) begin
    if(!CLK4P_n) begin
        A59 <= ~(A59 & clk2m_stop_dlyd_n); //1이면 flip, 0이면 1유지
    end
end

assign  CLK2P_n = ~(A59 | CLK4P_n);
assign  o_CLK2M_PCEN_n = CLK2P_n;



///////////////////////////////////////////////////////////
//////  POR CONTROL
////

//this counter is for ring counter synchronization; they follow the order below:
//rot8    3 4 5 6 7 0 1 2 3 4 5 6
//rot20   0   1   2   3   4   5

reg     [3:0]   por_cntr = 4'b1111; //cascaded T flip flops; A23 A24 A25 A27
always @(posedge i_MCLK) begin
    if(!CLK4P_n) begin
        if(~clk2m_stop_dlyd_n == 1'b1) begin //set
            por_cntr <= 4'b1111;
        end
        else begin
            if(~o_ROT8[1] == 1'b0) begin //count
                if(por_cntr == 4'b0000) begin
                    por_cntr <= 4'b1111; //loop
                end
                else begin
                    por_cntr <= por_cntr - 4'b1;
                end
            end
            else begin
                por_cntr <= por_cntr; //hold
            end
        end
    end
end

wire            op_start_n = ~&{o_ROT8[0], por_cntr[3:1], ~por_cntr[0]}; //A22
wire            op_stop;
wire            clk2m_ready_n = ~&{~por_cntr[3], ~por_cntr[0]}; //A29

wire            A30Q;
assign  op_stop = ~A30Q;

SRNAND A30 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_S_n(clk2m_ready_n), .i_R_n(clk2m_stop_n), .o_Q(A30Q), .o_Q_n());
SRNAND A21 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_S_n(op_start_n), .i_R_n(A30Q), .o_Q(o_SYS_RST_n), .o_Q_n());



///////////////////////////////////////////////////////////
//////  MODULE ROT20
////

K005297_supervisor_rot20 rot20_main (.i_CLK(i_MCLK), .i_CEN_n(CLK2P_n), .i_STOP(op_stop), .o_ROT20_n(o_ROT20_n)); //20-BIT ROTATOR, rotates bit 1 from LSB to MSB 



///////////////////////////////////////////////////////////
//////  SYS_RUN_FLAG_n
////

assign  o_SYS_RUN_FLAG_SET_n = ~(o_SYS_RST_n & ~o_ROT20_n[19]);

SRNAND C30 (.i_CLK(i_MCLK), .i_CEN_n(CLK4P_n), .i_S_n(o_SYS_RST_n), .i_R_n(o_SYS_RUN_FLAG_SET_n), .o_Q(), .o_Q_n(o_SYS_RUN_FLAG));


`ifdef K005297_DEBUG
///////////////////////////////////////////////////////////
//////  RING COUNTER DECODER
////

wire            __REF_4M = ~i_MCLK;
reg     [4:0]   __ROT20_VALUE;
reg     [2:0]   __ROT8_VALUE;

always @(*) begin
    case(o_ROT20_n)
        20'b1111_1111_1111_1111_1110: __ROT20_VALUE <= 5'd0;
        20'b1111_1111_1111_1111_1101: __ROT20_VALUE <= 5'd1;
        20'b1111_1111_1111_1111_1011: __ROT20_VALUE <= 5'd2;
        20'b1111_1111_1111_1111_0111: __ROT20_VALUE <= 5'd3;
        20'b1111_1111_1111_1110_1111: __ROT20_VALUE <= 5'd4;
        20'b1111_1111_1111_1101_1111: __ROT20_VALUE <= 5'd5;
        20'b1111_1111_1111_1011_1111: __ROT20_VALUE <= 5'd6;
        20'b1111_1111_1111_0111_1111: __ROT20_VALUE <= 5'd7;
        20'b1111_1111_1110_1111_1111: __ROT20_VALUE <= 5'd8;
        20'b1111_1111_1101_1111_1111: __ROT20_VALUE <= 5'd9;
        20'b1111_1111_1011_1111_1111: __ROT20_VALUE <= 5'd10;
        20'b1111_1111_0111_1111_1111: __ROT20_VALUE <= 5'd11;
        20'b1111_1110_1111_1111_1111: __ROT20_VALUE <= 5'd12;
        20'b1111_1101_1111_1111_1111: __ROT20_VALUE <= 5'd13;
        20'b1111_1011_1111_1111_1111: __ROT20_VALUE <= 5'd14;
        20'b1111_0111_1111_1111_1111: __ROT20_VALUE <= 5'd15;
        20'b1110_1111_1111_1111_1111: __ROT20_VALUE <= 5'd16;
        20'b1101_1111_1111_1111_1111: __ROT20_VALUE <= 5'd17;
        20'b1011_1111_1111_1111_1111: __ROT20_VALUE <= 5'd18;
        20'b0111_1111_1111_1111_1111: __ROT20_VALUE <= 5'd19;
    endcase

    case(o_ROT8)
        8'b0000_0001: __ROT8_VALUE <= 3'd0;
        8'b0000_0010: __ROT8_VALUE <= 3'd1;
        8'b0000_0100: __ROT8_VALUE <= 3'd2;
        8'b0000_1000: __ROT8_VALUE <= 3'd3;
        8'b0001_0000: __ROT8_VALUE <= 3'd4;
        8'b0010_0000: __ROT8_VALUE <= 3'd5;
        8'b0100_0000: __ROT8_VALUE <= 3'd6;
        8'b1000_0000: __ROT8_VALUE <= 3'd7;
    endcase
end
`endif


endmodule

module K005297_supervisor_rot8 (
    input   wire            i_CLK,
    input   wire            i_CEN_n,

    input   wire            i_STOP_n,
    output  wire    [7:0]   o_ROT8
);

reg     [7:0]   SR8 = 8'b0;
assign  o_ROT8 = SR8;

always @(posedge i_CLK) begin
    if(~i_CEN_n) begin
        SR8[7:1] <= SR8[6:0];
        SR8[0] <= ~|{SR8[6:0], ~i_STOP_n}; //A55 NOT
    end
end

endmodule

module K005297_supervisor_rot20 (
    input   wire            i_CLK,
    input   wire            i_CEN_n,

    input   wire            i_STOP,
    output  wire    [19:0]  o_ROT20_n
);

reg     [19:0]  SR20 = 20'b0000_0001_0000_0010_0000;
assign  o_ROT20_n = ~SR20;

always @(posedge i_CLK) begin
    if(~i_CEN_n) begin
        SR20[19:1] <= SR20[18:0];
        SR20[0] <= ~|{SR20[18:0], i_STOP};
    end
end

endmodule

module K005297_tempdet (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //control
    input   wire            i_TEMPLO_n,
    input   wire            i_CLK2M_STOP_n,
    input   wire            i_CLK2M_STOP_DLYD_n,

    output  wire            o_TEMPDROP_SET_n,
    output  wire            o_HEATEN_n
);


//register for edge detection
reg             edgedet_0, edgedet_1;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        edgedet_0 <= i_CLK2M_STOP_n & i_TEMPLO_n;
        edgedet_1 <= i_CLK2M_STOP_DLYD_n;
    end
end

//TEMPDROP flag
assign          o_TEMPDROP_SET_n = ~(edgedet_0 & ~(i_CLK2M_STOP_n & i_TEMPLO_n)); //negative edge detection


wire            heaten_clr_n = ~(~edgedet_0 & (i_CLK2M_STOP_n & i_TEMPLO_n)) & i_CLK2M_STOP_n; //positive edge detection
wire            heaten_set_n = ~((~edgedet_1 & i_CLK2M_STOP_DLYD_n & ~i_TEMPLO_n) & heaten_clr_n);

//delay
reg     [1:0]   heaten_ctrl_n;
always @(posedge i_MCLK) begin
    if(!i_CLK4M_PCEN_n) begin
        heaten_ctrl_n[1] <= heaten_clr_n;
        heaten_ctrl_n[0] <= heaten_set_n;
    end
end

//HEATEN_n out
SRNAND C20 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK4M_PCEN_n), .i_S_n(heaten_ctrl_n[1]), .i_R_n(heaten_ctrl_n[0]), .o_Q(o_HEATEN_n), .o_Q_n());

endmodule

module K005297_timer25k (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //timer
    input   wire            i_TIMER25K_CNT,
    input   wire            i_TIMER25K_OUTLATCH_LD_n,
    output  wire            o_TIMER25K_TIMEOVER_n,

    output  reg     [11:0]  o_TIMERREG_LSBS = 12'd0
);



///////////////////////////////////////////////////////////
//////  2556 TIMER(500ns*2556 = 1.278ms)
////

///////////////////////////////////////////////////////////
//////  CYCLE COUNTER
////

/*
    +1 serial up counter
*/

//shift flag
wire            timer25k_shift; 
SRNAND K3 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_ROT20_n[12]), .i_R_n(i_ROT20_n[0]), .o_Q(), .o_Q_n(timer25k_shift));


reg     [11:0]  timer25k = 12'd0; //timer
wire            timer25k_fa_sum; //msb input
wire            timer25k_fa_cout; //FA carry out
reg             timer25k_fa_cflag = 1'b0; //FA carry storage

//serial full adder cell
FA K4 (.i_A(timer25k[0]), .i_B(timer25k_fa_cflag), .i_CIN((i_TIMER25K_CNT & ~i_ROT20_n[0])), .o_S(timer25k_fa_sum), .o_COUT(timer25k_fa_cout));

//previous carry bit storage
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        timer25k_fa_cflag <= timer25k_fa_cout & i_ROT20_n[19];
    end
end

//shift register
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(timer25k_shift == 1'b1) begin
            timer25k[11] <= timer25k_fa_sum & i_TIMER25K_CNT;
            timer25k[10:0] <= timer25k[11:1];
        end
        else begin
            timer25k <= timer25k;
        end
    end
end



/*
    evaluation
*/

wire            const2555 = ~&{i_ROT20_n[11], i_ROT20_n[8], i_ROT20_n[7], i_ROT20_n[6], i_ROT20_n[5], i_ROT20_n[4], i_ROT20_n[3], i_ROT20_n[1], i_ROT20_n[0]};
reg             eq2555_flag_n = 1'b1;
reg             timeover_flag_n = 1'b1;

assign  o_TIMER25K_TIMEOVER_n = ~(~timeover_flag_n & ~i_ROT20_n[13]);

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        eq2555_flag_n <= ((timer25k_fa_sum ^ const2555) | eq2555_flag_n) & i_ROT20_n[19];
    end
end

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        timeover_flag_n <= (i_ROT20_n[12] == 1'b0) ? eq2555_flag_n : timeover_flag_n;
    end
end



/*
    counter register
*/

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(i_TIMER25K_OUTLATCH_LD_n == 1'b0) begin
            o_TIMERREG_LSBS <= timer25k;
        end
    end
end

endmodule

module K005297_z14eval (
    //master clock
    input   wire            i_MCLK,

    //clock enables
    input   wire            i_CLK4M_PCEN_n,
    input   wire            i_CLK2M_PCEN_n,

    //timing
    input   wire    [19:0]  i_ROT20_n,

    //reset
    input   wire            i_SYS_RST_n,

    //lock control
    input   wire            i_TIMER25K_TIMEOVER_n,
    input   wire            i_Z14_ERR_n,

    //lock flag related
    output  wire            o_Z14_UNLOCK_n,
    output  wire            o_Z14_LOCKED_n,

    //control
    input   wire            i_BDI_EN,

    input   wire            i_SUPBD_ACT_n,
    input   wire            i_SUPBD_END_n,

    input   wire            i_DLCNT_START_n,
    input   wire            i_SUPBDLCNTR_CNT,
    input   wire            i_ACQ_START,

    input   wire            i_MSKREG_SR_LSB,
    
    input   wire            i_BDI,
    input   wire            i_EFF_BDO,
    output  wire            o_MUXED_BDO,

    output  wire            o_TIMER25K_CNT,
    output  wire            o_TIMER25K_OUTLATCH_LD_n,

    //flags output
    output  wire            o_Z14_n,
    output  wire            o_Z11_d13_n,

    output  wire    [3:0]   o_TIMERREG_MSBS
);


reg             rot20_d18_dlyd1, rot20_d18_dlyd2;
always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        rot20_d18_dlyd1 <= ~i_ROT20_n[18];
        rot20_d18_dlyd2 <= rot20_d18_dlyd1;
    end
end


///////////////////////////////////////////////////////////
//////  Z14 FLAG EVALUATOR
////

//Actually, this is a CRC14 calculator

//Z14 lock flag bit
assign  o_Z14_UNLOCK_n = i_TIMER25K_TIMEOVER_n & o_Z11_d13_n;

//original implementation
assign  o_TIMER25K_OUTLATCH_LD_n = o_Z14_LOCKED_n | o_Z11_d13_n;

SRNAND I7 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(o_Z14_UNLOCK_n), .i_R_n(i_Z14_ERR_n), .o_Q(o_Z14_LOCKED_n), .o_Q_n(o_TIMER25K_CNT));


//SR14 control
wire            bdi_act, srctrl_en_n;
wire            srctrl_shift = (bdi_act == 1'b1) ? i_SUPBDLCNTR_CNT : rot20_d18_dlyd2; //J47 AO22

SRNAND J48 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(i_SUPBD_END_n), .i_R_n(i_DLCNT_START_n), .o_Q(), .o_Q_n(bdi_act));
SRNAND F47 (.i_CLK(i_MCLK), .i_CEN_n(i_CLK2M_PCEN_n), .i_S_n(~(i_ACQ_START & ~i_ROT20_n[0]) & i_SYS_RST_n), .i_R_n(i_DLCNT_START_n), .o_Q(srctrl_en_n), .o_Q_n());


//SR14 data in
wire            output_data_n = ~((~i_BDI_EN & i_EFF_BDO) | i_BDI); //M35
wire            output_data_n_gated = ~(output_data_n | ~o_Z14_LOCKED_n); //M7
wire            sr14_msb;
wire            sr14_lsb = (sr14_msb ^ output_data_n_gated) & ~(~i_BDI_EN & ~i_SUPBD_ACT_n);


//SR14
reg     [3:0]   sr14_4;
reg             sr14_1;
reg     [8:0]   sr14_9;
wire    [13:0]  sr14 = {sr14_9, sr14_1, sr14_4};
                       //MSB                  //LSB <- INPUT
wire    [15:0]  __DEBUG_CRC12_VAL = {sr14, 2'b00};

assign  sr14_msb = sr14[13];
assign  o_Z11_d13_n = |{sr14[13:3]} | i_ROT20_n[13];
assign  o_Z14_n = |{sr14};
assign  o_TIMERREG_MSBS = sr14[13:10];

always @(posedge i_MCLK) begin
    if(!i_CLK2M_PCEN_n) begin
        if(srctrl_en_n == 1'b1) begin //reset
            sr14_4 <= 4'b0000;
            sr14_1 <= 1'b0;
            sr14_9 <= 9'b0_0000_0000;
        end
        else begin
            if(srctrl_shift == 1'b1) begin //shift
                //sr14_4
                sr14_4[0] <= sr14_lsb;
                sr14_4[3:1] <= sr14_4[2:0];

                //sr14_1
                sr14_1 <= sr14_4[3] ^ sr14_lsb;

                //sr14_9
                sr14_9[0] <= sr14_1 ^ sr14_lsb;
                sr14_9[8:1] <= sr14_9[7:0];
            end 
            else begin //hold
                sr14_4 <= sr14_4;
                sr14_1 <= sr14_1;
                sr14_9 <= sr14_9;
            end
        end
    end
end


//bubble data output
assign  o_MUXED_BDO = ((~i_BDI_EN & ~i_SUPBD_ACT_n) == 1'b0) ? output_data_n_gated & i_MSKREG_SR_LSB : sr14_msb & i_MSKREG_SR_LSB;

endmodule

module ASYNCDL
(
    input   wire            i_SET,
    input   wire            i_EN,
    input   wire            i_D,
    output  reg             o_Q
);

always @(*) begin
    if(i_SET) begin
        o_Q <= 1'b1;
    end
    else begin
        if(i_EN) begin
            o_Q <= i_D;
        end
        else begin
            o_Q <= o_Q;
        end
    end
end

endmodule

module DL #(parameter dw=1)
(
    input   wire                i_CLK,
    input   wire                i_CEN_n,

    input   wire                i_EN,
    input   wire    [dw-1:0]    i_D,
    output  wire    [dw-1:0]    o_Q,
    output  wire    [dw-1:0]    o_Q_n
);

reg     [dw-1:0]    DFF;
wire    [dw-1:0]    OUTPUT = (i_EN == 1'b0) ? DFF : i_D;

assign  o_Q = OUTPUT;
assign  o_Q_n = ~OUTPUT;

always @(posedge i_CLK) begin
    if(!i_CEN_n) begin
        if(i_EN) begin
            DFF <= i_D;
        end
    end
end

endmodule

module FA
(
    input   wire            i_A,
    input   wire            i_B,
    input   wire            i_CIN,

    output  wire            o_S,
    output  wire            o_COUT
);

assign  o_S = (i_CIN == 1'b0) ? (i_A ^ i_B) : ~(i_A ^ i_B);
assign  o_COUT = (i_CIN == 1'b0) ? (i_A & i_B) : (i_A | i_B);

endmodule

module SRNAND
(
    input   wire            i_CLK,
    input   wire            i_CEN_n,

    input   wire            i_S_n,
    input   wire            i_R_n,
    output  wire            o_Q,
    output  wire            o_Q_n
);

reg             DFF = 1'b1;
reg             Q;

assign  o_Q = Q;
assign  o_Q_n = ~Q;

always @(posedge i_CLK) begin
    if(!i_CEN_n) begin
        case({i_S_n, i_R_n})
            2'b00: DFF <= DFF; //hold(illegal)
            2'b01: DFF <= 1'b1; //set
            2'b10: DFF <= 1'b0; //reset
            2'b11: DFF <= DFF; //hold
        endcase
    end
end

always @(*) begin
    case({i_S_n, i_R_n, DFF})
        3'b000: Q <= DFF; //illegal
        3'b001: Q <= DFF; //illegal
        3'b010: Q <= 1'b1; //set인데 DFF가 0인경우
        3'b011: Q <= DFF; //set이고 DFF가 1인경우
        3'b100: Q <= DFF; //reset이고 DFF가 0인경우
        3'b101: Q <= 1'b0; //reset인데 DFF가 1인경우
        3'b110: Q <= DFF; //유지
        3'b111: Q <= DFF; //유지
    endcase
end

endmodule

module SRNOR
(
    input   wire            i_CLK,
    input   wire            i_CEN_n,

    input   wire            i_S,
    input   wire            i_R,
    output  wire            o_Q,
    output  wire            o_Q_n
);

reg             DFF = 1'b1;
reg             Q;

assign  o_Q = Q;
assign  o_Q_n = ~Q;

always @(posedge i_CLK) begin
    if(!i_CEN_n) begin
        case({i_S, i_R})
            2'b00: DFF <= DFF; //hold
            2'b01: DFF <= 1'b0; //reset
            2'b10: DFF <= 1'b1; //set
            2'b11: DFF <= DFF; //hold(illegal)
        endcase
    end
end

always @(*) begin
    case({i_S, i_R, DFF})
        3'b000: Q <= DFF; //유지
        3'b001: Q <= DFF; //유지
        3'b010: Q <= DFF; //reset이고 DFF가 0인경우
        3'b011: Q <= 1'b0; //reset인데 DFF가 1인경우
        3'b100: Q <= 1'b1; //set인데 DFF가 0인경우
        3'b101: Q <= DFF; //set이고 DFF가 1인경우
        3'b110: Q <= DFF; //illegal
        3'b111: Q <= DFF; //illegal
    endcase
end

endmodule