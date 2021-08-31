module diff_phase #(
    parameter PAR_PHASE_WIDTH     = 16 ,  
    parameter PAR_PHASE_INT_WIDTH = 9   
)(
    input  wire                               i_clk         ,  
    input  wire                               i_rst_n       ,  
    input  wire                               s_axis_tvalid ,  
    input  wire signed [PAR_PHASE_WIDTH-1:0]  s_axis_tdata  , 
    output wire                               m_axis_tvalid ,  
    output wire signed [PAR_PHASE_WIDTH-1:0]  m_axis_tdata     
);

// latency = 3
//============================================================


wire signed [PAR_PHASE_WIDTH-1:0] phase_dat = s_axis_tdata;


//! [diff]
//
localparam K_PI_FRAC_REF = 16'b0010_0100_0100_0000;   // 0.1416015625

localparam 
    K_PHASE_FRAC_WIDTH = PAR_PHASE_WIDTH - PAR_PHASE_INT_WIDTH,
    K_PI_INT  = {{(PAR_PHASE_INT_WIDTH-2){1'b0}},2'd3},  // 3
    K_PI_FRAC = K_PI_FRAC_REF[15-:K_PHASE_FRAC_WIDTH],
    K_PI      = {K_PI_INT, K_PI_FRAC},
    K_2PI     = K_PI << 1;

reg signed [PAR_PHASE_WIDTH-1:0] 
    phase_R1, 
    phase_diff_R1, 
    phase_diff_R2, 
    phase_diff_abs_R2,  // simply invert bits
    phase_diff_limited_R3;

wire phase_diff_sign_R1;
reg phase_diff_sign_R2;

reg [3:1] phase_vld_R;

assign phase_diff_sign_R1 = phase_diff_R1[PAR_PHASE_WIDTH-1];

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        phase_vld_R <= 0;
    end
    else begin
        phase_vld_R[3:1] <= {phase_vld_R[2:1], s_axis_tvalid};   
    end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        phase_R1      <= 0;
        phase_diff_R1 <= 0;
    end
	else if (s_axis_tvalid) begin
        phase_R1      <= phase_dat;
        phase_diff_R1 <= phase_dat - phase_R1;
    end
end

always @(posedge i_clk) begin
	if (phase_vld_R[1]) begin
        phase_diff_R2      <= phase_diff_R1     ;
        phase_diff_sign_R2 <= phase_diff_sign_R1;
        phase_diff_abs_R2  <= (phase_diff_sign_R1 == 1'b1) ? ~phase_diff_R1 : phase_diff_R1;
    end
end

always @(posedge i_clk) begin
	if (phase_vld_R[2]) begin
        if (phase_diff_abs_R2 > K_PI) begin
            case (phase_diff_sign_R2)
            1'b1: begin
                phase_diff_limited_R3 <= phase_diff_R2 + K_2PI;
            end
            1'b0: begin
                phase_diff_limited_R3 <= phase_diff_R2 - K_2PI;
            end
            endcase
        end
        else begin
            phase_diff_limited_R3 <= phase_diff_R2;
        end
    end
end
//! [diff]


//! [output]
//
assign m_axis_tvalid = phase_vld_R[3];
assign m_axis_tdata  = phase_diff_limited_R3;
//! [output]


endmodule
