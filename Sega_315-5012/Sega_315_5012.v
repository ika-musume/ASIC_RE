module Sega_315_5012 (
    input   wire            i_MCLK,
    input   wire            i_CLK5MNCEN, //5M on schematics, the actual chip inverts the clock internally
    input   wire            i_CLK10MPCEN, ///10M on schematics, same as above

    //signals from PALs near the main CPU
    output  wire            o_DMAEND,
    input   wire            i_DMAON_n,
    input   wire            i_ONELINE_n,

    //CPU control
    input   wire    [10:0]  i_AD,
    input   wire            i_OBJ_n,
    input   wire            i_RD_n,
    input   wire            i_WR_n,

    //CPU RW gate control
    output  wire            o_BUFENH_n, //pin21(no name)
    output  wire            o_BUFENL_n, //pin20(no name)

    //sprite engine timing input?
    input   wire            i_OBJEND_n,
    input   wire            i_PTEND,

    //use with 315-5011
    output  wire            o_LOHP_n,
    output  wire            o_CWEN,
    output  wire            o_VCUL_n,   //line comparator enable
    input   wire            i_VEN_n,    //line match
    output  wire            o_DELTAX_n,
    output  wire            o_ALULO_n,
    output  wire            o_ONTRF,

    //sprite RAM control
    output  wire            o_RCS_n,
    output  wire            o_RAMWRH_n,
    output  wire            o_RAMWRL_n,
    output  wire    [9:0]   o_RA
);


/*
    SPRITE RAM INFORMATION

    total address space: 11bits - 128 * 16bytes
*/


///////////////////////////////////////////////////////////
//////  Clocks
////

wire            mclk = i_MCLK;
wire            clk5m_ncen = i_CLK5MNCEN;
wire            clk10m_pcen = i_CLK10MPCEN;



///////////////////////////////////////////////////////////
//////  Counter for the FSM
////

//define counter register
reg     [2:0]   fsmcntr;

//define counter decoder output
wire            fsmcntr0, fsmcntr1, fsmcntr2, fsmcntr3, fsmcntr4;
reg             fsmcntr3_z;
always @(posedge mclk) if(clk5m_ncen) fsmcntr3_z <= fsmcntr3;

//counter control
wire            fsmcntr_ld_n = ~((i_VEN_n & i_ONELINE_n) & fsmcntr0);

wire            fsmcntr_rst_n_d = ~i_DMAON_n & i_OBJ_n;
reg             fsmcntr_rst_n_reg;
wire            fsmcntr_rst_n = fsmcntr_rst_n_reg & fsmcntr_rst_n_d;
always @(posedge mclk) if(clk5m_ncen) fsmcntr_rst_n_reg <= fsmcntr_rst_n_d;

//fsmcntr_cnt jkff control
wire            fsmcntr_cnt;
wire            fsmcntr_cnt_j = ~(~i_PTEND & i_OBJ_n);
wire            fsmcntr_cnt_k = ~fsmcntr3_z;
Sega_315_5012_jkff u_13G (.i_MCLK(mclk), .i_CEN(clk5m_ncen), .i_SET_n(i_ONELINE_n),
                          .i_J(fsmcntr_cnt_j), .i_K_n(fsmcntr_cnt_k), .o_Q(fsmcntr_cnt), .o_Q_n());

//counter
wire            fsmcntr_ctrlwire0 = fsmcntr_ld_n & ~fsmcntr[2];
wire            fsmcntr_ctrlwire1 = fsmcntr_ctrlwire0 & fsmcntr_cnt;
always @(posedge mclk) begin
    if(clk5m_ncen) begin
        if(!fsmcntr_rst_n) begin
            fsmcntr <= 3'd0;
        end
        else begin
            //hold: 01
            //cnt:  11
            //load: 00
            fsmcntr[0] <= &{ fsmcntr[0], fsmcntr_ctrlwire0,      ~ fsmcntr_ctrlwire1} |
                          &{~fsmcntr[0],                           fsmcntr_ctrlwire1};

            fsmcntr[1] <= &{ fsmcntr[1], fsmcntr_ctrlwire0,      ~(fsmcntr_ctrlwire1 & fsmcntr[0])} |
                          &{ fsmcntr[0], ~fsmcntr[1],              fsmcntr_ctrlwire1};

            fsmcntr[2] <= &{ fsmcntr[2], fsmcntr_ctrlwire0,      ~(fsmcntr_ctrlwire1 & fsmcntr[0] & fsmcntr[1])} |
                          &{ fsmcntr[0],  fsmcntr[1], ~fsmcntr[2], fsmcntr_ctrlwire1};
        end
    end
end

//counter decoder
assign  fsmcntr0 = (fsmcntr == 3'd0) & (fsmcntr_rst_n_reg & fsmcntr_cnt);
assign  fsmcntr1 = (fsmcntr == 3'd1) & (fsmcntr_rst_n_reg & fsmcntr_cnt);
assign  fsmcntr2 = (fsmcntr == 3'd2) & (fsmcntr_rst_n_reg & fsmcntr_cnt);
assign  fsmcntr3 = (fsmcntr == 3'd3) & (fsmcntr_rst_n_reg & fsmcntr_cnt);
assign  fsmcntr4 = (fsmcntr == 3'd4) & (fsmcntr_rst_n_reg & fsmcntr_cnt);



///////////////////////////////////////////////////////////
//////  Sprite RAM low address counter
////

//declare low address counter
reg     [3:0]   addrcntrlo;

//address counter control timings(a and b)
wire            addrcntrlo_timing_a = (!fsmcntr_ld_n) ? 1'b0 :
                                                        (!i_ONELINE_n) ? ~fsmcntr[0] : 
                                                                         fsmcntr2 | fsmcntr4;

wire            addrcntrlo_timing_b = (!fsmcntr_ld_n) ? 1'b0 :
                                                        (!i_ONELINE_n) ? fsmcntr0 | fsmcntr4 : 
                                                                         fsmcntr0 | fsmcntr1 | fsmcntr2 | fsmcntr4;

//misc output signal(goes to 315-5011)
assign          o_ALULO_n           = (!fsmcntr_ld_n) ? 1'b0 :
                                                        (!i_ONELINE_n) ? ~fsmcntr2 : 
                                                                         ~fsmcntr2 & ~fsmcntr3;

//PLA inputs
wire            addrcntrlo_pla_in3  = ~(~addrcntrlo[1] | ~addrcntrlo_timing_a);
wire            addrcntrlo_pla_in2  = ~( addrcntrlo[1] |  addrcntrlo_timing_a);
wire            addrcntrlo_pla_in1  = ~(~addrcntrlo[0] | ~addrcntrlo_timing_b);
wire            addrcntrlo_pla_in0  = ~( addrcntrlo[0] |  addrcntrlo_timing_b);

//low address counter bits(so ugly)
always @(posedge mclk) if(clk5m_ncen) begin
    if(!fsmcntr_rst_n) begin
        addrcntrlo[0] <= 1'b0;
        addrcntrlo[1] <= 1'b0;
        addrcntrlo[2] <= 1'b0;
        addrcntrlo[3] <= 1'b0;
    end
    else begin
        //BIT0
        addrcntrlo[0] <=    ~addrcntrlo_pla_in0 & ~addrcntrlo_pla_in1;

        //BIT1
        addrcntrlo[1] <=    (~addrcntrlo_pla_in0 &  addrcntrlo_pla_in1) ^       //13L AND2

                            (~addrcntrlo_pla_in2 & ~addrcntrlo_pla_in3);        //18N AND2

        //BIT2
        addrcntrlo[2] <=    (~( addrcntrlo_pla_in0 & ~addrcntrlo_pla_in3) &     //16L NAND2
                             ~(~addrcntrlo_pla_in1 & ~addrcntrlo_pla_in3) &     //14K NAND2
                              (~addrcntrlo_pla_in2                      )) ^    //15L AND3

                            ( addrcntrlo[2]                              );
        
        //BIT3
        addrcntrlo[3] <=    (~( addrcntrlo_pla_in0 & ~addrcntrlo_pla_in3) &     //16L NAND2
                             ~(~addrcntrlo_pla_in1 & ~addrcntrlo_pla_in3) &     //14K NAND2
                              (~addrcntrlo_pla_in2                      ) &
                              ( addrcntrlo[2]                           )) ^    //15K AND4

                            (~( fsmcntr_ld_n       & ~addrcntrlo[3]     ) &
                             ~(~fsmcntr_ld_n       &  addrcntrlo[3]     ));
    end
end

//address counter high ENT/ENP
wire            addrcntrhi_cnt = ~(~(~fsmcntr_ld_n &  addrcntrlo[3]) &  addrcntrlo_pla_in0 & ~addrcntrlo_pla_in3) &  //13O
                                 ~(~(~fsmcntr_ld_n &  addrcntrlo[3]) & ~addrcntrlo_pla_in1 & ~addrcntrlo_pla_in3) &  //13N
                                 ~(~(~fsmcntr_ld_n &  addrcntrlo[3]) &  addrcntrlo_pla_in2                      ) &  //14O
                                 ~(~(~fsmcntr_ld_n &  addrcntrlo[3]) & ~addrcntrlo[2]                           ) &  //10O
                                  (~( fsmcntr_ld_n & ~addrcntrlo[3])                                            );   //11P 5-IN AND



///////////////////////////////////////////////////////////
//////  Sprite RAM high address counter
////

//declare high address counter
reg     [3:0]   addrcntrhi;

//high address counter bits
always @(posedge mclk) if(clk5m_ncen) begin
    if(!fsmcntr_rst_n) addrcntrhi <= 4'd0;
    else begin
        if(addrcntrhi_cnt) begin
            if(addrcntrhi == 4'd15) addrcntrhi <= 4'd0;
            else addrcntrhi <= addrcntrhi + 4'd1;
        end
    end
end



///////////////////////////////////////////////////////////
//////  Peripheral control
////

reg             obj_latched_n;
always @(posedge mclk) if(clk5m_ncen) obj_latched_n <= i_OBJ_n;

assign  o_LOHP_n = ~(fsmcntr1 & i_ONELINE_n);

assign  o_ONTRF = ~(~fsmcntr3_z & fsmcntr_cnt) & obj_latched_n;

assign  o_VCUL_n = ~fsmcntr0;
assign  o_DELTAX_n = ~fsmcntr2;

Sega_315_5012_jkff u_19P (.i_MCLK(mclk), .i_CEN(clk5m_ncen), .i_SET_n(~fsmcntr_cnt),
                          .i_J(~fsmcntr_cnt), .i_K_n(1'b0), .o_Q(), .o_Q_n(o_CWEN));




///////////////////////////////////////////////////////////
//////  Object RAM bus control
////

reg             dma_ram_wr_n;
always @(posedge mclk) if(clk10m_pcen) begin
    if(fsmcntr3_z) dma_ram_wr_n <= ~dma_ram_wr_n;
    else dma_ram_wr_n <= 1'b1;
end

wire            cpu_ram_wr_lo_n = ~(~(obj_latched_n | i_WR_n) & ~i_AD[0]);
wire            cpu_ram_wr_hi_n = ~(~(obj_latched_n | i_WR_n) &  i_AD[0]);

assign  o_RAMWRL_n = (obj_latched_n) ? dma_ram_wr_n : cpu_ram_wr_lo_n;
assign  o_RAMWRH_n = (obj_latched_n) ? dma_ram_wr_n : cpu_ram_wr_hi_n;

assign  o_BUFENL_n = ~(~(obj_latched_n | (i_WR_n & i_RD_n)) & ~i_AD[0]);
assign  o_BUFENH_n = ~(~(obj_latched_n | (i_WR_n & i_RD_n)) &  i_AD[0]);

assign  o_RA = (obj_latched_n) ? {2'b00, addrcntrhi, addrcntrlo} : i_AD[10:1];

assign  o_RCS_n = ~fsmcntr_cnt & obj_latched_n;

assign  o_DMAEND = ~&{~&{addrcntrhi_cnt, addrcntrhi}, ~&{~i_OBJEND_n, fsmcntr_cnt, fsmcntr0}, i_OBJ_n};

endmodule


module Sega_315_5012_jkff (
    input   wire            i_MCLK,
    input   wire            i_CEN,
    input   wire            i_SET_n,
    input   wire            i_J, i_K_n,
    output  wire            o_Q, o_Q_n
);

reg             jkff_reg;
always @(posedge i_MCLK) if(i_CEN) begin
    if(!i_SET_n) jkff_reg <= 1'b1;
    else begin
        case({i_J, i_K_n})
            2'b00: jkff_reg <= 1'b0;
            2'b01: jkff_reg <= jkff_reg;
            2'b10: jkff_reg <= ~jkff_reg;
            2'b11: jkff_reg <= 1'b1;
        endcase
    end
end

assign  o_Q = jkff_reg | ~i_SET_n;
assign  o_Q_n = ~o_Q;

endmodule