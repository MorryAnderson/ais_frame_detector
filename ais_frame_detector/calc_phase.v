module calc_phase #(
    parameter PAR_DATA_WIDTH      = 16 ,
    parameter PAR_PHASE_WIDTH     = 16 ,
    parameter PAR_PHASE_INT_WIDTH = 9
)(
    input  wire                               i_clk         ,
    input  wire                               i_rst_n       ,
    input  wire                               s_axis_tvalid ,
    input  wire        [PAR_DATA_WIDTH*2-1:0] s_axis_tdata  ,
    output wire                               s_axis_tready ,
    output wire                               m_axis_tvalid ,
    output wire signed [ PAR_PHASE_WIDTH-1:0] m_axis_tdata
);

// latency  = PAR_DATA_WIDTH + 15
// interval = 17
//============================================================


// s_axis_tdata[31:0] = {imag[15:0], real[15:0]}
wire signed [PAR_DATA_WIDTH-1:0] data_i = s_axis_tdata[             0+:PAR_DATA_WIDTH];
wire signed [PAR_DATA_WIDTH-1:0] data_q = s_axis_tdata[PAR_DATA_WIDTH+:PAR_DATA_WIDTH];


//! [normalize]
//  latency = PAR_DATA_WIDTH + 1:
wire normalize_vld;
wire signed [PAR_DATA_WIDTH-1:0] normalize_dat_i;
wire signed [PAR_DATA_WIDTH-1:0] normalize_dat_q;

normalize #(
    .PAR_DATA_WIDTH ( PAR_DATA_WIDTH )
) U_normalize (
    .i_clk   ( i_clk           ),
    .i_rst_n ( i_rst_n         ),
    .i_vld   ( s_axis_tvalid   ),
    .i_dat_1 ( data_i          ),
    .i_dat_2 ( data_q          ),
    .o_rdy   ( s_axis_tready   ),
    .o_vld   ( normalize_vld   ),
    .o_dat_1 ( normalize_dat_i ),
    .o_dat_2 ( normalize_dat_q )
);

//! [normalize]


//! [convert to 1Qn format]
//  latency = 0
wire data_i_sign = normalize_dat_i[PAR_DATA_WIDTH-1];
wire data_q_sign = normalize_dat_q[PAR_DATA_WIDTH-1];

wire signed [PAR_DATA_WIDTH-1:0] data_i_1qn = {{2{data_i_sign}}, normalize_dat_i[1+:PAR_DATA_WIDTH-2]};
wire signed [PAR_DATA_WIDTH-1:0] data_q_1qn = {{2{data_q_sign}}, normalize_dat_q[1+:PAR_DATA_WIDTH-2]};

wire [(PAR_DATA_WIDTH)*2-1:0] data_1qn = {data_q_1qn, data_i_1qn};

//! [convert to 1Qn format]


//! [atan]
//  latency = 14
cordic_atan_0 U_atan (
  .aclk                    ( i_clk         ),
  .aresetn                 ( i_rst_n       ),
  .s_axis_cartesian_tvalid ( normalize_vld ),
  .s_axis_cartesian_tdata  ( data_1qn      ),  // [31 : 0] , fix16_14, [31:16], [15:0]
  .m_axis_dout_tvalid      ( m_axis_tvalid ),
  .m_axis_dout_tdata       ( m_axis_tdata  )   // [15 : 0] , fix10_7
);
//! [atan]


endmodule
