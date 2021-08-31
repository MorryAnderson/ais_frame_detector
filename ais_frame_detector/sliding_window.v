module sliding_window #( 
    parameter PAR_DATA_WIDTH = 16  ,  
    parameter PAR_DELAY_LEN  = 128 ,  
    // hidden params
    parameter PAR_IDX_WIDTH  = log2(PAR_DELAY_LEN)    
)(
    input  wire                      i_clk         ,  
    input  wire                      i_rst_n       ,  
    input  wire                      s_axis_tvalid ,  
    input  wire [PAR_DATA_WIDTH-1:0] s_axis_tdata  ,  
    output reg                       s_axis_tready ,  
    output reg                       m_axis_tvalid ,  
    output reg                       m_axis_tlast  ,  
    output reg  [PAR_DATA_WIDTH-1:0] m_axis_tdata  ,  
    output reg  [ PAR_IDX_WIDTH-1:0] m_axis_tuser     
);

/// latency = 2

`include "log2.vh"
/*============================================================
[DRC REQP-1840] RAMB18 async control check: 
The RAMB18E1 buffer_ram_reg has an input control pin buffer_ram_reg/ENARDEN 
(net: ram_wr_ena) which is driven by a register that has an active asychronous set or reset. 

This may cause corruption of the memory contents and/or read values 
    when the set/reset is asserted and is not analyzed by the default static timing analysis. 
    
It is suggested to eliminate the use of a set/reset to registers driving this RAMB pin or else 
    use a synchronous reset in which the assertion of the reset is timed by default.

//============================================================*/


//! [ram ports]
//
localparam
    K_RAM_ADDR_WIDTH = log2(PAR_DELAY_LEN)         ,      
    K_RAM_ADDR_0     = {K_RAM_ADDR_WIDTH{1'b0}}     ,      
    K_RAM_ADDR_1     = {{(K_RAM_ADDR_WIDTH-1){1'b0}} ,1'b1},
    K_RAM_ADDR_F     = PAR_DELAY_LEN-1             ;       

reg [PAR_DATA_WIDTH-1:0]   buffer_ram[0:PAR_DELAY_LEN-1];
reg [K_RAM_ADDR_WIDTH-1:0] ram_rd_adr, ram_wr_adr;
reg [PAR_DATA_WIDTH-1:0]   ram_rd_dat, ram_wr_dat;

reg ram_rd_ena, ram_wr_ena;

always @(posedge i_clk) begin
    if (ram_wr_ena) begin
        buffer_ram[ram_wr_adr] <= ram_wr_dat;
    end
end

always @(posedge i_clk) begin
    if (ram_rd_ena) begin
        ram_rd_dat <= buffer_ram[ram_rd_adr];
    end
end

//! [ram ports]


//! [state machine]
//
reg [1:0] state;

wire reading_last_address;
wire writing_last_address;

localparam
    STATE_RESET  = 2'b11 ,
    STATE_IDLE   = 2'b00 ,
    STATE_READ   = 2'b01 ;

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        state <= STATE_RESET;
    end
    else begin
        case (state)
        STATE_RESET: begin
            if (writing_last_address) begin
                state <= STATE_IDLE;
            end
        end
        STATE_IDLE: begin
            if (s_axis_tvalid) begin
                state <= STATE_READ;
            end
        end
        STATE_READ: begin
            if (reading_last_address && (!ram_wr_ena)) begin
                state <= STATE_IDLE;
            end
        end
        default: begin
            state <= STATE_RESET;
        end
        endcase
    
    end
end
//! [state machine]


//! [ram r/w enable]
//
wire ram_wr_rdy = state == STATE_IDLE || reading_last_address;

always @(*) begin
    ram_wr_dat = (state == STATE_RESET) ? 0 : s_axis_tdata;
    ram_wr_ena = (state == STATE_RESET) || (ram_wr_rdy && s_axis_tvalid);
    ram_rd_ena = (state == STATE_READ);
end
//! [ram r/w enable]


//! [ram address cycle]
wire [K_RAM_ADDR_WIDTH-1:0] ram_wr_adr_nxt, ram_rd_adr_nxt;
reg  [K_RAM_ADDR_WIDTH-1:0] previous_wr_adr;

assign ram_wr_adr_nxt = (ram_wr_adr == K_RAM_ADDR_F ) ? K_RAM_ADDR_0 : (ram_wr_adr + K_RAM_ADDR_1);
assign ram_rd_adr_nxt = (ram_rd_adr == K_RAM_ADDR_F ) ? K_RAM_ADDR_0 : (ram_rd_adr + K_RAM_ADDR_1);

assign reading_last_address = (state == STATE_READ) && (ram_rd_adr == previous_wr_adr);
assign writing_last_address = (state != STATE_IDLE) && (ram_wr_adr == K_RAM_ADDR_F);

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        ram_wr_adr <= K_RAM_ADDR_0;
    end
    else if (ram_wr_ena) begin
        ram_wr_adr <= ram_wr_adr_nxt;
    end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        ram_rd_adr <= K_RAM_ADDR_0;
    end
    else begin
        if (ram_wr_ena) begin
            ram_rd_adr <= ram_wr_adr_nxt;
        end
        else if (ram_rd_ena) begin
            ram_rd_adr <= ram_rd_adr_nxt;        
        end
    end
end

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        previous_wr_adr <= K_RAM_ADDR_0;
    end
    else if (ram_wr_ena) begin
        previous_wr_adr <= ram_wr_adr;
    end
end
//! [ram address cycle]


//! [data index]
//
localparam
    K_INDEX_WIDTH = PAR_IDX_WIDTH     ,      
    K_INDEX_0 = {K_INDEX_WIDTH{1'b0}}     ,
    K_INDEX_1 = {{(K_INDEX_WIDTH-1){1'b0}},1'b1};

always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        m_axis_tuser <= K_INDEX_0;
    end
    else begin
        if (m_axis_tlast) begin
            m_axis_tuser <= K_INDEX_0;
        end
        else if (m_axis_tvalid) begin
            m_axis_tuser <= m_axis_tuser + K_INDEX_1;          
        end
    end
end
//! [data index]


//! [output ports]
//
always @(posedge i_clk/*, negedge i_rst_n*/) begin
    if (~i_rst_n) begin
        m_axis_tlast  <= 0;
        m_axis_tvalid <= 0;
    end
    else begin
        m_axis_tlast  <= reading_last_address;
        m_axis_tvalid <= ram_rd_ena;
    end
end

always @(*) begin
    m_axis_tdata <= ram_rd_dat;
end

always @(*) begin
    s_axis_tready = ram_wr_rdy;
end
//! [output ports]


endmodule
