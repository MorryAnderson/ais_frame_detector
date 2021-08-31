module normalize #( 
    parameter PAR_DATA_WIDTH = 16 
)(
    input  wire                      i_clk   ,  
    input  wire                      i_rst_n , 
    input  wire                      i_vld   ,
    input  wire [PAR_DATA_WIDTH-1:0] i_dat_1 ,  
    input  wire [PAR_DATA_WIDTH-1:0] i_dat_2 ,
    output reg                       o_rdy   ,
    output reg                       o_vld   ,
    output reg  [PAR_DATA_WIDTH-1:0] o_dat_1 ,
    output reg  [PAR_DATA_WIDTH-1:0] o_dat_2 
);

/// latency = PAR_DATA_WIDTH + 1
//============================================================


//! [progress]
//

/// indicates when to output the result
/// when new data comes, it is set to '1000', 
/// then shifts right at every posedge of i_clk,
/// the output is valid atfer it equals '0001' (LSB == 1)
/// i_vld - 1000 - 0100 - 0010 - 0001 - o_vld
reg [PAR_DATA_WIDTH-1:0] progress;
reg processing;

wire end_of_processing = (progress[0] == 1'b1);

always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
        progress   <= 0;
        processing <= 0;
        o_rdy      <= 0;
	end
	else begin
        if (!processing) begin
            if (i_vld) begin
                progress   <= {1'b1, {(PAR_DATA_WIDTH-1){1'b0}}};
                processing <= 1'b1;
                o_rdy      <= 1'b0;
            end
            else begin
                o_rdy <= 1'b1;
            end
        end
        else begin
            progress <= progress >> 1;
            if (end_of_processing) begin
                processing <= 1'b0;
                o_rdy <= 1'b1;
            end
        end
	end
end
//! [progress]


//! [shift]
//
reg [PAR_DATA_WIDTH-1:0] data_1_R;
reg [PAR_DATA_WIDTH-1:0] data_2_R;

wire data_1_need_shift = ~(data_1_R[PAR_DATA_WIDTH-1] ^ data_1_R[PAR_DATA_WIDTH-2]);
wire data_2_need_shift = ~(data_2_R[PAR_DATA_WIDTH-1] ^ data_2_R[PAR_DATA_WIDTH-2]);
wire data_need_shift   = data_1_need_shift && data_2_need_shift;  // '&&' not '||'

always @(posedge i_clk) begin
    if (i_vld && o_rdy) begin
        data_1_R <= i_dat_1;
        data_2_R <= i_dat_2;		       
    end
    else if (processing && data_need_shift) begin
        data_1_R <= data_1_R << 1;
        data_2_R <= data_2_R << 1;
    end
end
//! [shift]


//! [output]
//
always @(posedge i_clk/*, negedge i_rst_n*/) begin
	if (~i_rst_n) begin
		o_vld   <= 0;
	end
	else begin
		o_vld <= end_of_processing;
	end
end

always @(posedge i_clk) begin
    if (end_of_processing) begin
        o_dat_1 <= data_1_R;
        o_dat_2 <= data_2_R;
    end
end
//! [output]


endmodule
