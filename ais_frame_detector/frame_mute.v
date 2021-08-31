/**
@param PAR_MUTE_LENGTH in bits
@parm s_axis_tuser represents the input start of frame
@parm m_axis_tuser represents the muted start of frame 
    
@note
    PAR_MUTE_LENGTH shall not be larger than the length of AIS frame (256)
*/

module frame_mute #( 
    parameter PAR_DATA_WIDTH = 16  ,
    parameter PAR_MUTE_LENGTH = 240 
)(
    input  wire                        i_clk         ,  
    input  wire                        i_rst_n       ,  
    input  wire                        s_axis_tvalid ,  
    input  wire [2*PAR_DATA_WIDTH-1:0] s_axis_tdata  ,  
    input  wire                        s_axis_tuser  , 
    output reg                         m_axis_tvalid ,  
    output reg  [2*PAR_DATA_WIDTH-1:0] m_axis_tdata  ,  
    output reg                         m_axis_tuser  ,
    output reg                         o_muted_signal  
);

localparam
    K_CNT_WIDTH = 16               ,      
    K_0 = {K_CNT_WIDTH{1'b0}}     ,
    K_1 = {{(K_CNT_WIDTH-1){1'b0}},1'b1},
    K_F = {K_CNT_WIDTH{1'b1}}     ;

localparam [K_CNT_WIDTH-1:0] K_MUTE_CNT_RELOAD_VALUE = PAR_MUTE_LENGTH;

reg [K_CNT_WIDTH-1:0] mute_CNT;

wire is_muting = |mute_CNT;  // mute_CNT != 0;

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        mute_CNT <= K_0;
    end
    else if (s_axis_tvalid) begin
        if (is_muting) begin
            mute_CNT <= mute_CNT - K_1;
        end
        else if (s_axis_tuser == 1'b1) begin
            mute_CNT <= K_MUTE_CNT_RELOAD_VALUE;
        end
    end
end

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        m_axis_tvalid <= 0;
        m_axis_tuser <= 0;
        m_axis_tdata <= 0;
    end
    else begin
        m_axis_tvalid <= s_axis_tvalid;
        m_axis_tdata <= s_axis_tdata;
        m_axis_tuser <= is_muting ? 1'b0 : s_axis_tuser;
        o_muted_signal <= is_muting ? s_axis_tuser : 1'b0;
    end
end

endmodule
