module flag_likehood #( 
    parameter PAR_PHASE_WIDTH     = 16    ,                              
    parameter PAR_PHASE_INT_WIDTH = 9     ,                              
    parameter real PAR_TL         = 8.608 ,  // 7-bif diff low threshold 
    parameter real PAR_TH         = 11.750,  // 7-bif diff high threshold
    parameter PAR_WINDOW_LEN      = 17    ,                              
    //
    parameter PAR_OUT_WIDTH = 8
)(
    input  wire                              i_clk         ,  
    input  wire                              i_rst_n       ,  
    input  wire                              s_axis_tvalid ,  
    input  wire                              s_axis_tlast  ,  
    input  wire signed [PAR_PHASE_WIDTH-1:0] s_axis_tdata  ,  ///< 7-bit diff phase window
    input  wire signed [PAR_PHASE_WIDTH-1:0] s_axis_tuser  ,  ///< phase offset per 7 symbols
    output reg                               m_axis_tvalid ,  
    output reg         [  PAR_OUT_WIDTH-1:0] m_axis_tdata
);


// latency = PAR_WINDOW_LEN + 3 + (floor((PAR_WINDOW_LEN-1)/2) * CPS )
`include "log2.vh"
`include "rtoi.vh"
//============================================================


localparam K_PHASE_FRAC_WIDTH = PAR_PHASE_WIDTH - PAR_PHASE_INT_WIDTH;
localparam signed [PAR_PHASE_WIDTH-1:0] K_TL_FIX = rtoi(PAR_TL * 2**K_PHASE_FRAC_WIDTH);
localparam signed [PAR_PHASE_WIDTH-1:0] K_TH_FIX = rtoi(PAR_TH * 2**K_PHASE_FRAC_WIDTH);


//! [valid delay]
//
localparam K_DELAY = 2;
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


//! [remove phase offset]
//  latency = 1
reg signed [PAR_PHASE_WIDTH-1:0] offset_dat;

wire offset_vld = vld_R[1];

always @(posedge i_clk) begin
    if (s_axis_tvalid) begin
        offset_dat <= s_axis_tdata - s_axis_tuser;
    end
end
//! [remove phase offset]


//! [abs]
//  latency = 1
reg signed [PAR_PHASE_WIDTH-1:0] abs_dat;

wire sign    = offset_dat[PAR_PHASE_WIDTH-1];
wire abs_vld = vld_R[2];
wire abs_lst = lst_R[2];

always @(posedge i_clk) begin
    if (offset_vld) begin
        abs_dat <= sign == 1'b1 ? ~offset_dat : offset_dat;
    end
end
//! [abs]


//! [find max]
// latency = PAR_WINDOW_LEN
localparam K_INDEX_WIDTH = log2(PAR_WINDOW_LEN);

wire [PAR_PHASE_WIDTH-1:0] max_dat;
wire [K_INDEX_WIDTH-1:0]   max_idx;
wire max_vld;

max #(
    .PAR_DATA_WIDTH ( PAR_PHASE_WIDTH ),
    .PAR_USER_WIDTH ( K_INDEX_WIDTH   ),
    .PAR_SIGNED     ( 1  )
) U_max (
    .i_clk         ( i_clk   ),
    .i_rst_n       ( i_rst_n ),
    .s_axis_tvalid ( abs_vld ),
    .s_axis_tlast  ( abs_lst ),
    .s_axis_tdata  ( abs_dat ),
    .m_axis_tvalid ( max_vld ),
    .m_axis_tdata  ( max_dat ),
    .m_axis_tuser  ( max_idx ) 
);
//! [find max]


//! [is flag]
//  latency = 1 + （floor((PAR_WINDOW_LEN-1)/2) * CPS )
localparam K_PEAK_POS = PAR_WINDOW_LEN/2;

wire is_peak       = max_idx == K_PEAK_POS;
wire in_range      = max_dat > K_TL_FIX && max_dat < K_TH_FIX;
wire possible_flag = max_vld & is_peak && in_range;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        m_axis_tvalid <= 0;
    end
    else begin
        m_axis_tvalid <= max_vld;
    end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        m_axis_tdata <= 0;
    end
    else begin
        m_axis_tdata <= {PAR_OUT_WIDTH{possible_flag}};
    end
end
//! [is flag]


endmodule
