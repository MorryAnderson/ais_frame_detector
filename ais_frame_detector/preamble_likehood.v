module preamble_likehood #( 
    parameter PAR_PHASE_WIDTH     = 16 ,  
    parameter PAR_PHASE_INT_WIDTH = 9 ,  
    parameter real PAR_TZ = 0.754,  // zero-cross threshold
    parameter real PAR_TO = 3.895,  // overflow threshold
    //
    parameter PAR_OUT_WIDTH = 8
)(
    input  wire                              i_clk         ,  
    input  wire                              i_rst_n       ,  
    input  wire                              s_axis_tvalid ,  
    input  wire                              s_axis_tlast  ,  
    input  wire signed [PAR_PHASE_WIDTH-1:0] s_axis_tdata  ,  
    input  wire signed [PAR_PHASE_WIDTH-1:0] s_axis_tuser  ,
    output wire                              m_axis_tvalid ,  
    output wire        [  PAR_OUT_WIDTH-1:0] m_axis_tdata  ,
    output wire signed [PAR_PHASE_WIDTH-1:0] m_axis_tuser  
);


// latency = K_WINDOW_LEN + 2
`include "rtoi.vh"
//============================================================


localparam K_PHASE_FRAC_WIDTH = PAR_PHASE_WIDTH - PAR_PHASE_INT_WIDTH;
localparam signed [PAR_PHASE_WIDTH-1:0] K_TZ_FIX = rtoi(PAR_TZ * 2**K_PHASE_FRAC_WIDTH);
localparam signed [PAR_PHASE_WIDTH-1:0] K_TO_FIX = rtoi(PAR_TO * 2**K_PHASE_FRAC_WIDTH);


//! [valid delay]
//
localparam K_DELAY = 3;

reg [K_DELAY:1] vld_R;
reg [K_DELAY:1] lst_R;

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        vld_R <= 0;
        lst_R <= 0;
    end
    else begin
        vld_R[K_DELAY:1] <= {vld_R[K_DELAY-1:1], s_axis_tvalid};
        lst_R[K_DELAY:1] <= {lst_R[K_DELAY-1:1], s_axis_tlast};
    end
end
//! [valid delay]


//! [abs]
//
reg signed [PAR_PHASE_WIDTH-1:0] abs_dat;
reg sign_R1;

wire sign = s_axis_tdata[PAR_PHASE_WIDTH-1];

always @(posedge i_clk) begin
    if (s_axis_tvalid) begin
        abs_dat <= sign == 1'b1 ? ~s_axis_tdata : s_axis_tdata;
        sign_R1 <= sign;
    end
end
//! [abs]


//! [sign]
//
localparam 
    K_SIGN_POS = 2'd1,
    K_SIGN_NEG = -2'd1,
    K_SIGN_ZERO = 2'd0,
    K_SIGN_NONE = -2'd2;

reg signed [1:0] sign_R2;

always @(posedge i_clk) begin
    if (vld_R[1]) begin
        if (abs_dat < K_TZ_FIX || abs_dat > K_TO_FIX) begin
            sign_R2 <= K_SIGN_ZERO;
        end
        else begin
            case (sign_R1)
            1'b0: begin
                sign_R2 <= K_SIGN_POS;
            end
            1'b1: begin
                sign_R2 <= K_SIGN_NEG;
            end
            endcase
        end
    end
end
//! [sign]


//! [match]
//
reg signed [1:0] sign_R3;
reg alternating_R2;
reg possible_R3;
reg matched_R3;

// when not alterning sign, then it becomes impossible
wire possible_nxt_R2 = possible_R3 && alternating_R2;

always @(*) begin
    case ({sign_R3, sign_R2})
    {K_SIGN_NONE, K_SIGN_POS}, 
    {K_SIGN_NONE, K_SIGN_NEG}, 
    {K_SIGN_POS, K_SIGN_NEG}, 
    {K_SIGN_NEG, K_SIGN_POS}: 
    begin
        alternating_R2 = 1'b1;
    end
    default: begin
        alternating_R2 = 1'b0;
    end
    endcase
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        sign_R3     <= K_SIGN_NONE;
        possible_R3 <= 1'b1       ;
        matched_R3  <= 0          ;
    end
    else if (vld_R[2]) begin
        if (lst_R[2]) begin
            sign_R3     <= K_SIGN_NONE;
            possible_R3 <= 1'b1       ;
            matched_R3  <= possible_nxt_R2;
        end
        else begin
            sign_R3     <= sign_R2;
            possible_R3 <= possible_nxt_R2;
        end
    end
end
//! [match]


//! [user data delay]
//
reg signed [PAR_PHASE_WIDTH-1:0] user_dat_R[1:3];

// divided by 2
always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        user_dat_R[1]  <= 0;
    end
    else begin
        if (s_axis_tvalid & s_axis_tlast) begin
            user_dat_R[1] <= (s_axis_tuser >>> 1);  
        end   
    end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        user_dat_R[2]  <= 0;
    end
    else begin
        if (lst_R[1] & vld_R[1]) begin
            user_dat_R[2] <=  user_dat_R[1];
        end
        
    end
end

// updated only when matched
always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        user_dat_R[3]  <= 0;
    end
    else begin
        if (lst_R[2] & vld_R[2] & possible_nxt_R2) begin
            user_dat_R[3] <=  user_dat_R[2];
        end        
    end
end
//! [user data delay]


//! [output]
//
assign m_axis_tvalid = lst_R[3] & vld_R[3];
assign m_axis_tdata  = {PAR_OUT_WIDTH{matched_R3}};
assign m_axis_tuser  = user_dat_R[3];
//! [output]


endmodule
