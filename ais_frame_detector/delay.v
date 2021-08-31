module delay #( 
    parameter PAR_DATA_WIDTH       = 32  ,  
    parameter PAR_LONG_STEP_DELAY  = 512 ,  
    parameter PAR_SHORT_STEP_DELAY = 64   
)(
    input  wire                      i_clk         ,  
    input  wire                      s_axis_tvalid ,  
    input  wire [PAR_DATA_WIDTH-1:0] s_axis_tdata  ,  
    output wire                      m_axis_tvalid ,  
    output wire [PAR_DATA_WIDTH-1:0] m_axis_tdata     
);


localparam K_LONG_STEP_WIDTH  =  PAR_DATA_WIDTH;
localparam K_SHORT_STEP_WIDTH =  PAR_DATA_WIDTH + 1;

(* srl_style = "block"       *) reg [PAR_LONG_STEP_DELAY-1 :0] long_step_shf[PAR_DATA_WIDTH-1:0];
(* srl_style = "reg_srl_reg" *) reg [PAR_SHORT_STEP_DELAY-1:0] short_step_shf[K_SHORT_STEP_WIDTH-1:0];

wire [K_LONG_STEP_WIDTH-1:0]  long_step_dat;
wire [K_SHORT_STEP_WIDTH-1:0] short_step_dat;

wire [K_SHORT_STEP_WIDTH-1:0] long_step_vld_dat = {s_axis_tvalid, long_step_dat};

//=========================================================================

//! [initialization]
//
integer srl_index;

initial begin
    for (srl_index = 0; srl_index < K_LONG_STEP_WIDTH; srl_index = srl_index + 1) begin
        long_step_shf[srl_index] = {PAR_LONG_STEP_DELAY{1'b0}};
    end
    for (srl_index = 0; srl_index < K_SHORT_STEP_WIDTH; srl_index = srl_index + 1) begin
        short_step_shf[srl_index] = {PAR_SHORT_STEP_DELAY{1'b0}};
    end
end
//! [initialization]


genvar i;
generate

//! [delayed by sample]
//  @note: s_axis_tvalid is not delayed
for (i=0; i < K_LONG_STEP_WIDTH; i=i+1) begin: LONG_SHIFT
    always @(posedge i_clk) begin
        if (s_axis_tvalid) begin
            long_step_shf[i] <= {long_step_shf[i][PAR_LONG_STEP_DELAY-2:0], s_axis_tdata[i]};
        end
    end
    assign long_step_dat[i] = long_step_shf[i][PAR_LONG_STEP_DELAY-1];
end
//! [data delayed by sample]


//! [delayed by clock]
//  @note: s_axis_tvalid is also delayed
for (i=0; i < K_SHORT_STEP_WIDTH; i=i+1) begin: SHORT_SHIFT
    always @(posedge i_clk) begin
        short_step_shf[i] <= {short_step_shf[i][PAR_SHORT_STEP_DELAY-2:0], long_step_vld_dat[i]};
    end
    assign short_step_dat[i] = short_step_shf[i][PAR_SHORT_STEP_DELAY-1];
end
//! [delayed by clock]


endgenerate


//! [output]
//
assign m_axis_tvalid = short_step_dat[K_SHORT_STEP_WIDTH-1];
assign m_axis_tdata  = short_step_dat[0+:PAR_DATA_WIDTH];
//! [output]

endmodule
