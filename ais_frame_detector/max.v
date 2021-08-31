module max #( 
    parameter PAR_DATA_WIDTH = 16 ,  
    parameter PAR_USER_WIDTH = 16 ,  
    parameter PAR_SIGNED     = 0     
)(
    input  wire                      i_clk         ,  
    input  wire                      i_rst_n       ,  
    input  wire                      s_axis_tvalid ,  
    input  wire                      s_axis_tlast  ,  
    input  wire [PAR_DATA_WIDTH-1:0] s_axis_tdata  ,
    output reg                       m_axis_tvalid ,  
    output reg  [PAR_DATA_WIDTH-1:0] m_axis_tdata  ,  
    output reg  [PAR_USER_WIDTH-1:0] m_axis_tuser     
);


//! [is first data ?]
//
reg is_first_data;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        is_first_data <= 1'b1;
    end
    else if (s_axis_tvalid) begin
        if (s_axis_tlast) begin
            is_first_data <= 1'b1;
        end
        else begin
            is_first_data <= 1'b0;
        end
    end
end
//! [is first data ?]


//! [compare]
//
localparam    
    K_INDEX_0 = {PAR_USER_WIDTH{1'b0}}     ,
    K_INDEX_1 = {{(PAR_USER_WIDTH-1){1'b0}},1'b1};


reg  [PAR_DATA_WIDTH-1:0] max_value_dat;
reg  [PAR_USER_WIDTH-1:0] cur_index_dat;
reg  [PAR_USER_WIDTH-1:0] max_index_dat;

wire [PAR_DATA_WIDTH-1:0] max_value_nxt;
wire [PAR_USER_WIDTH-1:0] cur_index_nxt;
wire [PAR_USER_WIDTH-1:0] max_index_nxt;

wire next_is_bigger;

generate if (PAR_SIGNED == 0) begin
    assign next_is_bigger = s_axis_tdata > max_value_dat;
end
else begin
    assign next_is_bigger = $signed(s_axis_tdata) > $signed(max_value_dat);
end
endgenerate


assign max_value_nxt = next_is_bigger ? s_axis_tdata : max_value_dat;
assign cur_index_nxt = cur_index_dat + K_INDEX_1;
assign max_index_nxt = next_is_bigger ? cur_index_nxt : max_index_dat;

always @(posedge i_clk) begin
    if (s_axis_tvalid) begin
        if (is_first_data) begin
            max_value_dat <= s_axis_tdata;
            cur_index_dat <= K_INDEX_0;
            max_index_dat <= K_INDEX_0;
        end
        else begin
            max_value_dat <= max_value_nxt;
            cur_index_dat <= cur_index_nxt;
            max_index_dat <= max_index_nxt;
        end
    end
end
//! [compare]


//! [output]
//
always @(posedge i_clk) begin
    if (s_axis_tvalid & s_axis_tlast) begin
        m_axis_tdata  <= max_value_nxt;
        m_axis_tuser  <= max_index_nxt;
    end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        m_axis_tvalid <= 0;
    end
    else begin
        m_axis_tvalid <= s_axis_tvalid & s_axis_tlast;
    end
end
//! [output]


endmodule
