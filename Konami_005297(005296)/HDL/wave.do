onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /K005297_tb/MCLK
add wave -noupdate /K005297_tb/main/supervisor_main/i_MRST_n
add wave -noupdate /K005297_tb/main/i_TEMPLO_n
add wave -noupdate /K005297_tb/main/i_MCLK
add wave -noupdate /K005297_tb/main/supervisor_main/i_MRST_n
add wave -noupdate /K005297_tb/main/o_IRQ_n
add wave -noupdate -radix hexadecimal /K005297_tb/BubbleDrive8_emucore_0/SPIDriver_0/spi_state
add wave -noupdate /K005297_tb/BubbleDrive8_emucore_0/TimingGenerator_0/ABSPAGE
add wave -noupdate /K005297_tb/BubbleDrive8_emucore_0/SPIDriver_0/convert
add wave -noupdate -radix hexadecimal /K005297_tb/BubbleDrive8_emucore_0/SPIDriver_0/RELPAGE
add wave -noupdate /K005297_tb/main/o_BOOTEN_n
add wave -noupdate /K005297_tb/main/o_BSS_n
add wave -noupdate /K005297_tb/main/o_BSEN_n
add wave -noupdate /K005297_tb/main/o_REPEN_n
add wave -noupdate /K005297_tb/main/o_SWAPEN_n
add wave -noupdate /K005297_tb/BubbleDrive8_emucore_0/SPIDriver_0/ACCTYPE
add wave -noupdate -expand /K005297_tb/main/i_BDIN_n
add wave -noupdate -expand /K005297_tb/main/o_BDOUT_n
add wave -noupdate -radix hexadecimal /K005297_tb/bmc_address_latch
add wave -noupdate -radix unsigned /K005297_tb/main/fsm_main/fsmstat_parallel
add wave -noupdate /K005297_tb/main/o_BR_n
add wave -noupdate /K005297_tb/main/i_BG_n
add wave -noupdate /K005297_tb/BMC_BGACK_n
add wave -noupdate -radix hexadecimal /K005297_tb/AOUT_BUS
add wave -noupdate /K005297_tb/AS_n
add wave -noupdate -radix hexadecimal /K005297_tb/DIN_BUS
add wave -noupdate -radix hexadecimal /K005297_tb/DOUT_BUS
add wave -noupdate /K005297_tb/main/o_ALE
add wave -noupdate /K005297_tb/R_nW
add wave -noupdate /K005297_tb/UDS_n
add wave -noupdate /K005297_tb/LDS_n
add wave -noupdate /K005297_tb/SHAREDRAM_CS_n
add wave -noupdate /K005297_tb/SHAREDRAM_RD_n
add wave -noupdate /K005297_tb/SHAREDRAM_WR_n
add wave -noupdate -radix hexadecimal /K005297_tb/CPU_AOUT_BUS
add wave -noupdate /K005297_tb/CPU_AS_n
add wave -noupdate -radix hexadecimal -childformat {{{/K005297_tb/CPU_DIN_BUS[15]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[14]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[13]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[12]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[11]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[10]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[9]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[8]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[7]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[6]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[5]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[4]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[3]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[2]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[1]} -radix hexadecimal} {{/K005297_tb/CPU_DIN_BUS[0]} -radix hexadecimal}} -subitemconfig {{/K005297_tb/CPU_DIN_BUS[15]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[14]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[13]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[12]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[11]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[10]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[9]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[8]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[7]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[6]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[5]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[4]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[3]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[2]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[1]} {-height 15 -radix hexadecimal} {/K005297_tb/CPU_DIN_BUS[0]} {-height 15 -radix hexadecimal}} /K005297_tb/CPU_DIN_BUS
add wave -noupdate -radix hexadecimal /K005297_tb/CPU_DOUT_BUS
add wave -noupdate /K005297_tb/CPU_R_nW
add wave -noupdate /K005297_tb/CPU_UDS_n
add wave -noupdate /K005297_tb/CPU_LDS_n
add wave -noupdate /K005297_tb/BMC_CS_n
add wave -noupdate /K005297_tb/main/pgreg_main/i_PGREG_LD
add wave -noupdate /K005297_tb/main/STFLAG_CMD_ACCEPTED_n
add wave -noupdate /K005297_tb/main/STFLAG_OP_DONE_n
add wave -noupdate /K005297_tb/main/STFLAG_TEMPDROP_n
add wave -noupdate /K005297_tb/main/STFLAG_TIMER25K_LATCHED_n
add wave -noupdate /K005297_tb/main/STFLAG_TIMER25K_TIMEOVER_n
add wave -noupdate /K005297_tb/main/STFLAG_USER_Z14_ERR_n
add wave -noupdate /K005297_tb/main/STFLAG_Z14_ERR_n
add wave -noupdate /K005297_tb/main/tempdet_main/o_TEMPDROP_SET_n
add wave -noupdate -radix hexadecimal /K005297_tb/main/pgreg_main/pgreg_q
add wave -noupdate /K005297_tb/main/pgreg_main/i_PGREG_SR_LD_EN
add wave -noupdate -radix hexadecimal /K005297_tb/main/pgreg_main/pgsr
add wave -noupdate -radix hexadecimal /K005297_tb/main/abspgcntr_main/abspgcntr
add wave -noupdate /K005297_tb/main/ASYNC_LATCH_EN__CMDREG_WR_EN
add wave -noupdate /K005297_tb/main/CMDREG_RDREQ_n
add wave -noupdate /K005297_tb/main/CMDREG_WRREQ_n
add wave -noupdate /K005297_tb/main/CMDREG_RST_n
add wave -noupdate /K005297_tb/main/o_IRQ_n
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {42009199430 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 165
configure wave -valuecolwidth 79
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {4917080 ps}
