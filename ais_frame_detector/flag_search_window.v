module flag_search_window #(
    parameter PAR_WINDOW_DELAY = 6*8 ,
    parameter PAR_WINDOW_LEN   = 3*8    
)(
    input  wire i_clk      ,  
    input  wire i_rst_n    ,  
    input  wire i_vld      ,  
    input  wire i_preamble ,  
    output reg  o_vld      ,
    output wire o_window      
);

// latency = 3
`include "log2.vh"
//============================================================


//! [filtering]
//  latency = 1
reg preamble_R;
reg preamble_filtered;
reg preamble_vld;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		preamble_R <= 0;
		preamble_filtered <= 0;
	end
	else if (i_vld) begin
		preamble_R <= i_preamble;
		preamble_filtered <= i_preamble && preamble_R;
	end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        preamble_vld <= 0;
    end
    else begin
        preamble_vld <= i_vld;
    end
end
//! [filtering]


//! [expand]
//  latency = 1
//  count from K_CNT_F to 1, duration = K_CNT_F
//  duration = PAR_WINDOW_LEN = K_CNT_F
localparam 
    K_CNT_F     = PAR_WINDOW_LEN,
    K_CNT_WIDTH = log2(K_CNT_F+1),
    K_CNT_0     = {(K_CNT_WIDTH){1'b0}},
    K_CNT_1     = {{(K_CNT_WIDTH-1){1'b0}},1'b1};
    
    
reg [K_CNT_WIDTH-1:0] window_cnt;
reg window_vld;

wire counter_not_zero = |window_cnt;  

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        window_vld <= 0;
    end
    else begin
        window_vld <= preamble_vld;
    end
end


always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        window_cnt <= K_CNT_0;
    end
    else if (preamble_vld) begin
        if (preamble_filtered) begin
            window_cnt <= K_CNT_F;
        end
        else if (counter_not_zero) begin
            window_cnt <= window_cnt - K_CNT_1;
        end
        else begin
            window_cnt <= window_cnt;
        end
    end
end
//! [expand]


//! [delay]
//  latency = 1
localparam K_DELAY_LEN = PAR_WINDOW_DELAY + 1;

(* srl_style = "reg_srl_reg" *) 
reg [K_DELAY_LEN-1:0] shift_reg = {K_DELAY_LEN{1'b0}};

always @(posedge i_clk) begin
    if (window_vld) begin
        shift_reg <= {shift_reg[K_DELAY_LEN-2:0], counter_not_zero};
    end
end
//! [delay]


//! [output]
//
assign o_window = shift_reg[K_DELAY_LEN-1];

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        o_vld <= 0;
    end
    else begin
        o_vld <= window_vld; 
    end
end

//! [output]

endmodule
