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