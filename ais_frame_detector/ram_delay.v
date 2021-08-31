module delay #( 
    parameter PAR_DATA_WIDTH = 16 ,  
    parameter PAR_DELAY_LEN  = 32    /// at least 2
)(
    input  wire                      i_clk ,  
    input  wire                      i_rst_n ,  
    input  wire                      i_ena ,  
    input  wire [PAR_DATA_WIDTH-1:0] i_dat ,  
    output reg  [PAR_DATA_WIDTH-1:0] o_dat    
);

function integer log2(input integer n);
    integer i,t;
    begin // this 'begin' can not be omitted
        t = 0;
        for (i = 0; 2 ** i < n; i = i + 1)
            t= i + 1;
        log2 = t;
    end
endfunction

//=========================================================================


//! [data ram ports]
//
localparam
    K_DATA_RAM_SIZE = PAR_DELAY_LEN;
localparam
    K_DATA_ADDR_WIDTH = log2(K_DATA_RAM_SIZE)         ,
    K_DATA_ADDR_0     = {K_DATA_ADDR_WIDTH{1'b0}}     ,
    K_DATA_ADDR_1     = {{(K_DATA_ADDR_WIDTH-1){1'b0}} ,1'b1},
    K_DATA_ADDR_F     = K_DATA_RAM_SIZE-1             ;

reg [PAR_DATA_WIDTH-1:0] ram[0:K_DATA_RAM_SIZE-1];
reg [PAR_DATA_WIDTH-1:0] ram_rd_dat, ram_wr_dat;
reg [K_DATA_ADDR_WIDTH-1:0] ram_rd_adr, ram_wr_adr;

reg ram_rd_ena, ram_wr_ena;

integer i;

initial begin
    for (i = 0; i < K_DATA_RAM_SIZE; i = i + 1) begin
        ram[i] = {PAR_DATA_WIDTH{1'b0}};
    end
end

always @(posedge i_clk) begin
    if (ram_wr_ena) begin
        ram[ram_wr_adr] <= ram_wr_dat;
    end
end

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        ram_rd_dat <= 0;
    end
    else if (ram_rd_ena) begin
        ram_rd_dat <= ram[ram_rd_adr];  // internal latency +1
    end
end
//! [data ram ports]


//! [data ram address cycle]
wire [K_DATA_ADDR_WIDTH-1:0] ram_wr_adr_nxt, ram_rd_adr_nxt;

assign ram_wr_adr_nxt = (ram_wr_adr == K_DATA_ADDR_F ) ? K_DATA_ADDR_0 : (ram_wr_adr + K_DATA_ADDR_1);
assign ram_rd_adr_nxt = (ram_rd_adr == K_DATA_ADDR_F ) ? K_DATA_ADDR_0 : (ram_rd_adr + K_DATA_ADDR_1);

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        ram_wr_adr <= K_DATA_ADDR_0;
    end
    else if (ram_wr_ena) begin
        ram_wr_adr <= ram_wr_adr_nxt;
    end
end

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        ram_rd_adr <= K_DATA_ADDR_0;
    end
    else begin
        if (ram_rd_ena) begin
            ram_rd_adr <= ram_rd_adr_nxt;
        end
    end
end
//! [data ram address cycle]


//! [data ram r/w control]
//
localparam K_RD_LATENCY = 2;

reg rd_ena;

always @(posedge i_clk) begin
    if (~i_rst_n) begin
        rd_ena <= 0;
    end
    else begin
        if (ram_wr_adr == PAR_DELAY_LEN - K_RD_LATENCY) begin
            rd_ena <= 1'b1;
        end
    end
end

always @(*) begin
    ram_wr_ena = i_ena;
    ram_wr_dat = i_dat;
    ram_rd_ena = i_ena & rd_ena;
    o_dat = ram_rd_dat;
    
end
//! [data ram r/w control]

endmodule
