module centralize #( 
    parameter PAR_DATA_WIDTH = 16 ,  
    parameter PAR_WINDOW_LEN = 128,
    parameter PAR_USER_WIDTH = log2(PAR_WINDOW_LEN)
)(
    input  wire                             i_clk         ,  
    input  wire                             i_rst_n       ,  
    input  wire                             s_axis_tvalid ,  
    input  wire                             s_axis_tlast  ,  
    input  wire signed [PAR_DATA_WIDTH-1:0] s_axis_tdata  ,  
    input  wire        [PAR_USER_WIDTH-1:0] s_axis_tuser  ,  
    output wire                             s_axis_tready ,  
    output wire                             m_axis_tvalid ,  
    output wire                             m_axis_tlast  ,  
    output wire signed [PAR_DATA_WIDTH-1:0] m_axis_tdata  ,  
    output wire        [PAR_USER_WIDTH-1:0] m_axis_tuser  ,  
    output reg  signed [PAR_DATA_WIDTH-1:0] o_mean_dat   
);

// latency = PAR_WINDOW_LEN + 3
`include "log2.vh"
//============================================================


// [8~15] = 8, [16~31] = 16
localparam K_SUM_COUNT_LOG2 = log2(PAR_WINDOW_LEN+1)-1;
localparam K_SUM_COUNT = 2**(K_SUM_COUNT_LOG2);


//! [sum]
//  latency = PAR_WINDOW_LEN
localparam K_SUM_WIDTH = PAR_DATA_WIDTH + PAR_USER_WIDTH;

reg  total_sum_vld;
reg  signed [K_SUM_WIDTH-1:0] cumulative_sum, total_sum_dat;
wire signed [K_SUM_WIDTH-1:0] cumulative_sum_nxt;


assign cumulative_sum_nxt = cumulative_sum + s_axis_tdata;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		cumulative_sum <= 0;
	end
	else if (s_axis_tvalid) begin
		if (s_axis_tlast) begin
            cumulative_sum <= 0;
        end
        else begin
            cumulative_sum <= cumulative_sum_nxt;
        end
	end
end

always @(posedge i_clk) begin
	if (s_axis_tvalid && (s_axis_tuser==K_SUM_COUNT-1)) begin
        total_sum_dat <= cumulative_sum_nxt;
    end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		total_sum_vld <= 0;
	end
	else begin
		total_sum_vld <= s_axis_tvalid & s_axis_tlast;
	end
end
//! [sum]


//! [mean]
//  latency = 2
reg signed [PAR_DATA_WIDTH-1:0] mean_dat, mean_dat_R;
reg mean_vld, mean_vld_R;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		mean_vld   <= 0;
		mean_vld_R <= 0;
	end
	else begin
		mean_vld   <= total_sum_vld;
		mean_vld_R <= mean_vld;
	end
end

always @(posedge i_clk) begin
	if (total_sum_vld) begin
		mean_dat <= (total_sum_dat >>> K_SUM_COUNT_LOG2);
	end
end

always @(posedge i_clk) begin
	if (mean_vld) begin
		mean_dat_R <= mean_dat;
	end
end
//! [mean]


//! [data delay]
//  latency(@input) = PAR_WINDOW_LEN + 2 
wire signed [PAR_DATA_WIDTH-1:0] fifo_delay_dat; 
wire        [PAR_USER_WIDTH-1:0] fifo_delay_idx; 
wire fifo_delay_vld;
wire fifo_delay_lst;

axis_data_fifo_1 U_data_fifo_delay (
  .s_aclk         ( i_clk          ),                         
  .s_aresetn      ( i_rst_n        ),                         
  .s_axis_tvalid  ( s_axis_tvalid  ),                         
  .s_axis_tready  ( s_axis_tready  ),                         
  .s_axis_tdata   ( s_axis_tdata   ),  // input wire [15 : 0] 
  .s_axis_tlast   ( s_axis_tlast   ),                         
  .s_axis_tuser   ( s_axis_tuser   ),  // input wire [7 : 0]  
  .m_axis_tready  ( 1'b1           ),                         
  .m_axis_tvalid  ( fifo_delay_vld ),                         
  .m_axis_tlast   ( fifo_delay_lst ),                         
  .m_axis_tdata   ( fifo_delay_dat ),  // output wire [15 : 0]
  .m_axis_tuser   ( fifo_delay_idx )   // output wire [7 : 0] 
);

//! [data delay]


//! [centralize]
//  latency = 1
reg signed [PAR_DATA_WIDTH-1:0] centralized_dat;
reg signed [PAR_USER_WIDTH-1:0] centralized_idx;
reg centralized_vld;
reg centralized_lst;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		centralized_vld <= 0;
		centralized_lst <= 0;
	end
	else begin
		centralized_vld <= fifo_delay_vld;
		centralized_lst <= fifo_delay_lst;
	end
end

always @(posedge i_clk) begin
	if (fifo_delay_vld) begin
		centralized_dat <= fifo_delay_dat - mean_dat_R;
        centralized_idx <= fifo_delay_idx;
	end
end
//! [centralize]


//! [output]
//
assign m_axis_tvalid = centralized_vld;
assign m_axis_tlast  = centralized_lst;
assign m_axis_tdata  = centralized_dat;
assign m_axis_tuser  = centralized_idx;

always @(posedge i_clk) begin
	if (mean_vld_R) begin
		o_mean_dat <= mean_dat_R;
	end
end
//! [output]


endmodule
