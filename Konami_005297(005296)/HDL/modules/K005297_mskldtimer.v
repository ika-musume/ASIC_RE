module K005297_mskldtimer
(
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