/**
@copyright
@brief      Detect the start of AIS frame
@author     morry4c@qq.com
@version    1.0.0
@date       2021/5/21
@details    
    input data format: complex IQ, signed, width = PAR_DATA_WIDTH
    I = real = s_axis_tdata[             0 +: PAR_DATA_WIDTH]
    Q = imag = s_axis_tdata[PAR_DATA_WIDTH +: PAR_DATA_WIDTH]
    
@param PAR_CPS clocks per sample 
@param PAR_SPS samples per symbol 

@parm m_axis_tuser represents the start of frame
    
@note
    PAR_CPS shall not be smaller than (K_PREAMBLE_LEN-2)*PAR_SPS + 1
        where constant K_PREAMBLE_LEN = 24,
    thus PAR_CPS >= 22*PAR_SPS + 1
*/

module ais_frame_detector #( 
    parameter PAR_DATA_WIDTH = 16  ,  
    parameter PAR_CPS        = 234 ,  ///< clocks per sample
    parameter PAR_SPS        = 8      ///< samples per symbol
)(
    input  wire                        i_clk         ,  
    input  wire                        i_rst_n       ,  
    input  wire                        s_axis_tvalid ,  
    input  wire [2*PAR_DATA_WIDTH-1:0] s_axis_tdata  ,  
    output wire                        s_axis_tready ,  
    output wire                        m_axis_tvalid ,  
    output wire [2*PAR_DATA_WIDTH-1:0] m_axis_tdata  ,  
    output wire                        m_axis_tuser            
);

`include "log2.vh"




//! [constants]
//  assert: 
//      PAR_CPS > K_PREAMBLE_WINDOW_LEN
//      K_FLAG_WINDOW_SIDE_LEN >= 2
localparam real K_PI = 3.14159;

localparam K_PREAMBLE_LEN = 24;
localparam K_FLAG_LEN     = 8;

localparam K_PHASE_WIDTH         = 16;
localparam K_PHASE_INT_WIDTH     = 9;   ///< related to "CORDIC" IP coefficients
localparam K_PREAMBLE_WINDOW_LEN = (K_PREAMBLE_LEN-2)*PAR_SPS + 1;

localparam K_SEARCH_WINDOW_LEN   = 3*PAR_SPS;
localparam K_SEARCH_WINDOW_DELAY = 6*PAR_SPS;

localparam K_FLAG_WINDOW_SIDE_LEN = PAR_SPS;
localparam K_FLAG_WINDOW_LEN      = 2*K_FLAG_WINDOW_SIDE_LEN + 1;

localparam K_EXTRA_MARGIN         = 8*PAR_SPS;  // margin between start of frame and start of preamble

//! [constants]


//! [variables]
//
localparam K_TZ = (0.74-0.5)*K_PI;
localparam K_TO = (0.74+0.5)*K_PI;
localparam K_TL = (3.24-0.5)*K_PI;
localparam K_TH = (3.24+0.5)*K_PI;
//! [variables]


//! [ ]
//
//! [==================]
//


//! [diff phase]
//  latency = (PAR_DATA_WIDTH + 15) + (3)
wire signed [K_PHASE_WIDTH-1:0] phase_dat;
wire signed [K_PHASE_WIDTH-1:0] phase_diff_dat;
wire signed [K_PHASE_WIDTH-1:0] bit2_diff_dat;
wire signed [K_PHASE_WIDTH-1:0] bit7_diff_dat;

wire phase_vld;
wire phase_diff_vld;
wire bit2_diff_vld;
wire bit7_diff_vld;

wire phase_rdy;


calc_phase #(
    .PAR_DATA_WIDTH      ( PAR_DATA_WIDTH ),
    .PAR_PHASE_WIDTH     ( K_PHASE_WIDTH ),
    .PAR_PHASE_INT_WIDTH ( K_PHASE_INT_WIDTH  )
) U_calc_phase (
    .i_clk         ( i_clk         ),
    .i_rst_n       ( i_rst_n       ),
    .s_axis_tvalid ( s_axis_tvalid ),
    .s_axis_tdata  ( s_axis_tdata  ),
    .s_axis_tready ( phase_rdy     ),
    .m_axis_tvalid ( phase_vld     ),
    .m_axis_tdata  ( phase_dat     ) 
);


diff_phase #(
    .PAR_PHASE_WIDTH     ( K_PHASE_WIDTH ),
    .PAR_PHASE_INT_WIDTH ( K_PHASE_INT_WIDTH  )
) U_diff_phase (
    .i_clk         ( i_clk      ),
    .i_rst_n       ( i_rst_n    ),
    .s_axis_tvalid ( phase_vld  ),
    .s_axis_tdata  ( phase_dat  ),
    .m_axis_tvalid ( phase_diff_vld ),
    .m_axis_tdata  ( phase_diff_dat ) 
);
//! [diff phase]

//! [ ]
//

//! [detect preamble {] 
//  latency(@input) = (PAR_DATA_WIDTH + 15) + 3 + 2 + 2 + K_PREAMBLE_WINDOW_LEN + 3 + 1 + K_PREAMBLE_WINDOW_LEN + 2 + 3
//                  = PAR_DATA_WIDTH + 2*K_PREAMBLE_WINDOW_LEN + 31
//                  = 16 + 2*(22*PAR_SPS + 1) + 31
//                  = 44*PAR_SPS + 49
//                  = 401

//! [   2-bit diff]
//  latency = 2
moving_sum #(
    .PAR_DATA_WIDTH ( K_PHASE_WIDTH ),
    .PAR_MOV_LEN    ( PAR_SPS*2 )
) U_2bit_diff_phase (
    .i_clk         ( i_clk          ),
    .i_rst_n       ( i_rst_n        ),
    .s_axis_tvalid ( phase_diff_vld ),
    .s_axis_tdata  ( phase_diff_dat ),
    .m_axis_tvalid ( bit2_diff_vld  ),
    .m_axis_tdata  ( bit2_diff_dat  ) 
);
//! [2-bit diff]


//! [   sliding window]
//  latency = 2
localparam K_INDEX_WIDTH = log2(K_PREAMBLE_WINDOW_LEN);


wire signed [K_PHASE_WIDTH-1:0] bit2_sliding_dat;
wire        [K_INDEX_WIDTH-1:0] bit2_sliding_idx;
wire bit2_sliding_vld;
wire bit2_sliding_lst;
wire bit2_sliding_rdy;

sliding_window #(
    .PAR_DATA_WIDTH ( K_PHASE_WIDTH         ),
    .PAR_DELAY_LEN  ( K_PREAMBLE_WINDOW_LEN ),
    .PAR_IDX_WIDTH  ( K_INDEX_WIDTH         ) 
) U_bit2_sliding_window (
    .i_clk         ( i_clk            ),
    .i_rst_n       ( i_rst_n          ),
    .s_axis_tvalid ( bit2_diff_vld    ),
    .s_axis_tdata  ( bit2_diff_dat    ),
    .s_axis_tready ( bit2_sliding_rdy ),
    .m_axis_tvalid ( bit2_sliding_vld ),
    .m_axis_tlast  ( bit2_sliding_lst ),
    .m_axis_tdata  ( bit2_sliding_dat ),
    .m_axis_tuser  ( bit2_sliding_idx ) 
);
//! [sliding window]


//! [   centralize]
//  latency = K_PREAMBLE_WINDOW_LEN + 3
wire signed [K_PHASE_WIDTH-1:0] freq_offset_per2_dat;   ///< phase_offset per  2 symbols
reg  signed [K_PHASE_WIDTH-1:0] freq_offset_per14_dat;  ///< phase_offset per 14 symbols
wire signed [K_PHASE_WIDTH-1:0] freq_offset_per7_dat;   ///< phase_offset per  7 symbols

wire signed [K_PHASE_WIDTH-1:0] centralized_dat;
wire        [K_INDEX_WIDTH-1:0] centralized_idx;
wire centralized_vld;
wire centralized_lst;
wire centralized_rdy;

centralize #(
    .PAR_DATA_WIDTH ( K_PHASE_WIDTH         ),
    .PAR_WINDOW_LEN ( K_PREAMBLE_WINDOW_LEN )
) U_centralize (
    .i_clk         ( i_clk                ),
    .i_rst_n       ( i_rst_n              ),
    .s_axis_tvalid ( bit2_sliding_vld     ),
    .s_axis_tlast  ( bit2_sliding_lst     ),
    .s_axis_tdata  ( bit2_sliding_dat     ),
    .s_axis_tuser  ( bit2_sliding_idx     ),
    .s_axis_tready ( centralized_rdy      ),
    .m_axis_tvalid ( centralized_vld      ),
    .m_axis_tlast  ( centralized_lst      ),
    .m_axis_tdata  ( centralized_dat      ),
    .m_axis_tuser  ( centralized_idx      ),
    .o_mean_dat    ( freq_offset_per2_dat ) 
);
//! [centralize]


//! [   downsample]
//  latency = 1
localparam K_DOWN_SAMPLE_POWER      = 4;  // factor = 2^POWER
localparam K_DOWN_SAMPLED_IDX_WIDTH = K_INDEX_WIDTH - K_DOWN_SAMPLE_POWER;
localparam K_LAST_SAMPLE_IDX        = K_PREAMBLE_WINDOW_LEN[K_DOWN_SAMPLE_POWER+:K_DOWN_SAMPLED_IDX_WIDTH];

reg  signed [K_PHASE_WIDTH-1           :0] downsampled_dat ;
wire        [K_DOWN_SAMPLED_IDX_WIDTH-1:0] partial_centralized_idx;
reg  downsampled_vld ;
reg  downsampled_lst ;

wire sampled_ena = ~|centralized_idx[0+:K_DOWN_SAMPLE_POWER] & centralized_vld;

assign partial_centralized_idx = centralized_idx[K_DOWN_SAMPLE_POWER+:K_DOWN_SAMPLED_IDX_WIDTH];


always @(posedge i_clk) begin
    if (sampled_ena) begin
        freq_offset_per14_dat <= (freq_offset_per2_dat <<< 3) - freq_offset_per2_dat;  // 8x-x = 7x
    end
end

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        downsampled_vld <= 0;
    end
    else begin
        downsampled_vld <= sampled_ena;
    end
end

always @(posedge i_clk) begin
    if (sampled_ena) begin
        downsampled_dat <= centralized_dat;
    end
end

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        downsampled_lst <= 0;
    end
    else if (sampled_ena) begin
        downsampled_lst <= (partial_centralized_idx == K_LAST_SAMPLE_IDX);
    end
end
//! [downsample]


//! [   preamble likehood]
//  latency = K_PREAMBLE_WINDOW_LEN + 2
localparam K_LIKEHOOD_WIDTH = 1;

wire [K_LIKEHOOD_WIDTH-1:0] is_preamble;
wire preamble_vld;

preamble_likehood #(
    .PAR_PHASE_WIDTH     ( K_PHASE_WIDTH     ),
    .PAR_PHASE_INT_WIDTH ( K_PHASE_INT_WIDTH ),
    .PAR_TZ              ( K_TZ              ),
    .PAR_TO              ( K_TO              ),
    .PAR_OUT_WIDTH       ( K_LIKEHOOD_WIDTH  ) 
) U_preamble_likehood (
    .i_clk         ( i_clk                 ),
    .i_rst_n       ( i_rst_n               ),
    .s_axis_tvalid ( downsampled_vld       ),
    .s_axis_tlast  ( downsampled_lst       ),
    .s_axis_tdata  ( downsampled_dat       ),
    .s_axis_tuser  ( freq_offset_per14_dat ),
    .m_axis_tvalid ( preamble_vld          ),
    .m_axis_tdata  ( is_preamble           ),
    .m_axis_tuser  ( freq_offset_per7_dat  ) 
);
//! [preamble likehood]


//! [   flag search window]
//  latency = 3
wire search_window;
wire search_window_vld;

flag_search_window #(
    .PAR_WINDOW_DELAY ( K_SEARCH_WINDOW_DELAY ),
    .PAR_WINDOW_LEN   ( K_SEARCH_WINDOW_LEN )
) U_flag_search_window (
    .i_clk      ( i_clk             ),
    .i_rst_n    ( i_rst_n           ),
    .i_vld      ( preamble_vld      ),
    .i_preamble ( is_preamble[0]    ),
    .o_vld      ( search_window_vld ),
    .o_window   ( search_window     ) 
);
//! [flag search window]


//! [}]
//
//! [ ]
//


//! [detect start flag {]
//  latency(@input) = (PAR_DATA_WIDTH + 15) + 3 + 2 + 2 + K_FLAG_WINDOW_LEN + 3 + { floor((K_FLAG_WINDOW_LEN-1)/2) * PAR_CPS }
//                  = PAR_DATA_WIDTH + K_FLAG_WINDOW_LEN + 25 + { floor((K_FLAG_WINDOW_LEN-1)/2) * PAR_CPS }
//                  = 16 + (2*N + 1) + 25 + N*PAR_CPS
//                  = 42 + N*(PAR_CPS + 2)


//! [   7-bit diff]
//  latency = 2
moving_sum #(
    .PAR_DATA_WIDTH ( K_PHASE_WIDTH ),
    .PAR_MOV_LEN    ( PAR_SPS*7 )
) U_7bit_diff_phase (
    .i_clk         ( i_clk          ),
    .i_rst_n       ( i_rst_n        ),
    .s_axis_tvalid ( phase_diff_vld ),
    .s_axis_tdata  ( phase_diff_dat ),
    .m_axis_tvalid ( bit7_diff_vld  ),
    .m_axis_tdata  ( bit7_diff_dat  ) 
);
//! [7-bit diff]


//! [   sliding window]
//  latency = 2
localparam K_FLAG_INDEX_WIDTH = log2(K_FLAG_WINDOW_LEN);


wire signed [K_PHASE_WIDTH-1     :0] bit7_sliding_dat ;
wire        [K_FLAG_INDEX_WIDTH-1:0] bit7_sliding_idx ;

wire bit7_sliding_vld ;
wire bit7_sliding_lst ;
wire bit7_sliding_rdy ;

sliding_window #(
    .PAR_DATA_WIDTH ( K_PHASE_WIDTH      ),
    .PAR_DELAY_LEN  ( K_FLAG_WINDOW_LEN  ),
    .PAR_IDX_WIDTH  ( K_FLAG_INDEX_WIDTH ) 
) U_bit7_sliding_window (
    .i_clk         ( i_clk            ),
    .i_rst_n       ( i_rst_n          ),
    .s_axis_tvalid ( bit7_diff_vld    ),
    .s_axis_tdata  ( bit7_diff_dat    ),
    .s_axis_tready ( bit7_sliding_rdy ),
    .m_axis_tvalid ( bit7_sliding_vld ),
    .m_axis_tlast  ( bit7_sliding_lst ),
    .m_axis_tdata  ( bit7_sliding_dat ),
    .m_axis_tuser  ( bit7_sliding_idx ) 
);
//! [sliding window]


//! [   flag likehood]
//  latency = K_FLAG_WINDOW_LEN + 3 + { K_FLAG_WINDOW_SIDE_LEN * PAR_CPS }
wire [K_LIKEHOOD_WIDTH-1:0] potential_flag;
wire potential_flag_vld;

flag_likehood #(
    .PAR_PHASE_WIDTH     ( K_PHASE_WIDTH     ),
    .PAR_PHASE_INT_WIDTH ( K_PHASE_INT_WIDTH ),
    .PAR_TL              ( K_TL              ),
    .PAR_TH              ( K_TH              ),
    .PAR_WINDOW_LEN      ( K_FLAG_WINDOW_LEN ),
    .PAR_OUT_WIDTH       ( K_LIKEHOOD_WIDTH  )
) U_flag_likehood (
    .i_clk         ( i_clk                ),
    .i_rst_n       ( i_rst_n              ),
    .s_axis_tvalid ( bit7_sliding_vld     ),
    .s_axis_tlast  ( bit7_sliding_lst     ),
    .s_axis_tdata  ( bit7_sliding_dat     ),
    .s_axis_tuser  ( freq_offset_per7_dat ),
    .m_axis_tvalid ( potential_flag_vld   ),
    .m_axis_tdata  ( potential_flag       )
);
//! [flag likehood]


//! [}]
//
//! [ ]
//


//! [synchronization {]
//


//! [   align search window with flag]
//
localparam K_PREAMBLE_DETECTION_LATENCY = PAR_DATA_WIDTH + 2*K_PREAMBLE_WINDOW_LEN + 31;
localparam K_FLAG_DETECTION_LATENCY     = PAR_DATA_WIDTH + K_FLAG_WINDOW_LEN + 25 + K_FLAG_WINDOW_SIDE_LEN * PAR_CPS;
// K_FLAG_WINDOW_SIDE_LEN >= 2, thus K_FLAG_WINDOW_LEN >= 5
// PAR_CPS > K_PREAMBLE_WINDOW_LEN, therefore K_FLAG_DETECTION_LATENCY > K_PREAMBLE_DETECTION_LATENCY
localparam K_WINDOW_FLAG_DISTANCE       = K_FLAG_DETECTION_LATENCY - K_PREAMBLE_DETECTION_LATENCY;  // asserted to be positive


localparam K_DELAY_LEN = K_WINDOW_FLAG_DISTANCE;

(* srl_style = "block" *) 
reg [K_DELAY_LEN-1:0] shift_reg = {K_DELAY_LEN{1'b0}};
wire search_window_delayed;

always @(posedge i_clk) begin
    shift_reg <= {shift_reg[K_DELAY_LEN-2:0], search_window};
end

assign search_window_delayed = shift_reg[K_DELAY_LEN-1];
//! [align search window with flag]


//! [   arbitration]
//  latency = 1
reg is_flag;
reg is_flag_vld;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        is_flag <= 0;
        is_flag_vld <= 0;
    end
    else begin
        is_flag <= search_window_delayed & potential_flag[0];
        is_flag_vld <= potential_flag_vld;
    end
end
//! [arbitration]


//! [   align data with flag]
//  there is a constant delay (=K_PREAMBLE_LEN+K_FLAG_LEN-1 samples) between start flag and preamble
//  K_FLAG_DETECTION_LATENCY = (PAR_DATA_WIDTH + K_FLAG_WINDOW_LEN + 25) + (K_FLAG_WINDOW_SIDE_LEN)* PAR_CPS;
//  K_FLAG_DETECTION_LATENCY / PAR_CPS = K_FLAG_WINDOW_SIDE_LEN
//  K_FLAG_DETECTION_LATENCY % PAR_CPS = (PAR_DATA_WIDTH + K_FLAG_WINDOW_LEN + 25)
//
//  K_DATA_LONG_STEP_DELAY   is counted by samples
//  K_DATA_SHORT_STEP_DELAY  is counted by clocks
localparam K_PREAMBLE_FLAG_DISTANCE = (K_PREAMBLE_LEN+K_FLAG_LEN-1)*PAR_SPS;
localparam K_DATA_LONG_STEP_DELAY   = K_FLAG_WINDOW_SIDE_LEN + K_PREAMBLE_FLAG_DISTANCE + K_EXTRA_MARGIN;
localparam K_DATA_SHORT_STEP_DELAY  = (PAR_DATA_WIDTH + K_FLAG_WINDOW_LEN + 25) + 1;  // +1 latency of arbitration

wire [PAR_DATA_WIDTH*2 -1:0] input_qi_aligned_dat;
wire input_qi_aligned_vld;

delay #(
    .PAR_DATA_WIDTH       ( PAR_DATA_WIDTH*2        ),
    .PAR_LONG_STEP_DELAY  ( K_DATA_LONG_STEP_DELAY  ),
    .PAR_SHORT_STEP_DELAY ( K_DATA_SHORT_STEP_DELAY ) 
) U_delay (
    .i_clk         ( i_clk                ),
    .s_axis_tvalid ( s_axis_tvalid        ),
    .s_axis_tdata  ( s_axis_tdata         ),
    .m_axis_tvalid ( input_qi_aligned_vld ),
    .m_axis_tdata  ( input_qi_aligned_dat ) 
);
//! [align data with flag]

//! [}]
//
//! [ ]
//


//! [output]
//  check out "input_qi_aligned_vld" and "is_flag_vld" is aligned
assign m_axis_tdata  = input_qi_aligned_dat;
assign m_axis_tvalid = input_qi_aligned_vld & is_flag_vld;
assign m_axis_tuser  = is_flag;
assign s_axis_tready = bit2_sliding_rdy & bit7_sliding_rdy & centralized_rdy;
//! [output]


endmodule
