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
//////  MODULES
////

`include "./K005297_abspgcntr.v"        //absolute page counter
`include "./K005297_accmodeflag.v"      //access mode flag
`include "./K005297_bubctrlfe.v"        //bubble control frontend
`include "./K005297_bubrdfe.v"          //bubble read frontend
`include "./K005297_bubwrfe.v"          //bubble write frontend
`include "./K005297_busctrlfe.v"        //bus control frontend
`include "./K005297_byteacqcntr.v"      //byte acqusition counter
`include "./K005297_cyclecntr.v"        //cycle counter
`include "./K005297_dlcntr.v"           //data length counter
`include "./K005297_dleval.v"           //data length evaluator
`include "./K005297_dmaaddrcntr.v"      //DMA address counter
`include "./K005297_dmadreg.v"          //DMA data register
`include "./K005297_dmadregldctrl.v"    //DMA data register load control
`include "./K005297_dmafe.v"            //DMA frontend
`include "./K005297_dmatiming.v"        //DMA timing
`include "./K005297_fsm.v"              //FSM
`include "./K005297_functrig.v"         //bubble function trigger
`include "./K005297_invalpgdet.v"       //invalid page detector
`include "./K005297_invalpgdgen.v"      //invalid page data generator
`include "./K005297_mskldtimer.v"       //bad loop mask load timer
`include "./K005297_mskreg.v"           //bad loop mask register
`include "./K005297_pgcmp.v"            //page comparator
`include "./K005297_pgreg.v"            //page register
`include "./K005297_primitives.v"       //primitives
`include "./K005297_relpgcntr.v"        //relative page counter
`include "./K005297_spdet.v"            //synchronization pattern detector
`include "./K005297_sumcmp.v"           //checksum comparator
`include "./K005297_supbdlcntr.v"       //supplement bubble data length counter
`include "./K005297_supervisor.v"       //supervisor
`include "./K005297_tempdet.v"          //temperature detector
`include "./K005297_timer25k.v"         //25k timer
`include "./K005297_z14eval.v"          //CRC14 evaluator



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
ASYNCDL primitive_C20 (.i_SET(ASYNC_LATCH_EN__STFLAG_CLR), .i_EN(~TEMPDROP_SET_n),           .i_D(1'b0), .o_Q(STFLAG_TEMPDROP_n));


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