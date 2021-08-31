module moving_sum#(
    parameter PAR_DATA_WIDTH = 16 ,  
    parameter PAR_MOV_LEN = 16     
)(
    input  wire                              i_clk         ,  
    input  wire                              i_rst_n       ,  
    input  wire                              s_axis_tvalid ,  
    input  wire signed [PAR_DATA_WIDTH-1:0]  s_axis_tdata  ,
    output wire                              m_axis_tvalid ,  
    output wire signed [PAR_DATA_WIDTH-1:0]  m_axis_tdata     
);


// latency = 2
// y[n] = y[n-1] + x[n] - x[n-L];
// L = PAR_WINDOW_LEN
//============================================================


//! [x(n-L)]
//
wire signed [PAR_DATA_WIDTH-1:0] x = s_axis_tdata;
wire signed [PAR_DATA_WIDTH-1:0] x_RL;

reg [PAR_MOV_LEN-1:0] shift_reg [PAR_DATA_WIDTH-1:0];

integer srl_index;
initial begin
    for (srl_index = 0; srl_index < PAR_DATA_WIDTH; srl_index = srl_index + 1) begin
        shift_reg[srl_index] = {PAR_MOV_LEN{1'b0}};
    end
end

genvar i;
generate
    for (i=0; i < PAR_DATA_WIDTH; i=i+1) begin: DELAY_CHAIN
        always @(posedge i_clk) begin
            if (s_axis_tvalid) begin
                shift_reg[i] <= {shift_reg[i][PAR_MOV_LEN-2:0], x[i]};
            end
        end
        assign x_RL[i] = shift_reg[i][PAR_MOV_LEN-1];
    end
endgenerate
//! [x(n-L)]


//! [x(n)-x(n-L)]
//
reg x_diff_vld;
reg y_vld;
reg signed [PAR_DATA_WIDTH-1:0] x_diff;
reg signed [PAR_DATA_WIDTH-1:0] y; 

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		x_diff_vld <= 0;
	end
	else begin
		x_diff_vld <= s_axis_tvalid;
	end
end

always @(posedge i_clk) begin
	if (s_axis_tvalid) begin
        x_diff <= x - x_RL;
    end
end
//! [x(n)-x(n-L)]


//! [y(n)]
// y[n] = y[n-1] + x[n] - x[n-L];
always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		y_vld <= 0;
	end
	else begin
		y_vld <= x_diff_vld;
	end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		y <= 0;
	end
	else if (x_diff_vld) begin
        y <= y + x_diff;
    end
end
//! [y(n)]


//! [output]
//
assign m_axis_tvalid = y_vld;
assign m_axis_tdata  = y;
//! [output]


endmodule
