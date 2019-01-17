/********************MangoMIPS32*******************
Filename:   Data_Cache.v
Author:     RickyTino
Version:    v1.0.1
**************************************************/
`include "../Config.v"
`include "../Defines.v"

module Data_Cache (
    input  wire            aclk,
    input  wire            aresetn,
    output reg  [  3 : 0 ] arid,
    output reg  [ 31 : 0 ] araddr,
    output reg  [  3 : 0 ] arlen,
    output reg  [  2 : 0 ] arsize,
    output wire [  1 : 0 ] arburst,
    output wire [  1 : 0 ] arlock,
    output wire [  3 : 0 ] arcache,
    output wire [  2 : 0 ] arprot,
    output reg             arvalid,
    input  wire            arready,
    input  wire [  3 : 0 ] rid,
    input  wire [ 31 : 0 ] rdata,
    input  wire [  1 : 0 ] rresp,
    input  wire            rlast,
    input  wire            rvalid,
    output wire            rready,
    output wire [  3 : 0 ] awid,
    output reg  [ 31 : 0 ] awaddr,
    output reg  [  3 : 0 ] awlen,
    output reg  [  2 : 0 ] awsize,
    output wire [  1 : 0 ] awburst,
    output wire [  1 : 0 ] awlock,
    output wire [  3 : 0 ] awcache,
    output wire [  2 : 0 ] awprot,
    output reg             awvalid,
    input  wire            awready,
    output wire [  3 : 0 ] wid,
    output wire [ 31 : 0 ] wdata,
    output reg  [  3 : 0 ] wstrb,
    output reg             wlast,
    output reg             wvalid,
    input  wire            wready,
    input  wire [  3 : 0 ] bid,
    input  wire [  1 : 0 ] bresp,
    input  wire            bvalid,
    output wire            bready,

    input  wire            bus_en,
    input  wire [`ByteWEn] bus_wen,
    input  wire [`AddrBus] bus_addr,
    output wire [`DataBus] bus_rdata,
    input  wire [`DataBus] bus_wdata,
    input  wire [`AXISize] bus_size,
    output wire            bus_streq,
    input  wire            bus_stall,
    input  wire            bus_cached,

    input  wire [`CacheOp] cacheop,
    input  wire [`DataBus] cop_taglo
);

    assign arburst  = 2'b01;
    assign arlock   = 2'b0;
    assign arcache  = 4'b0;
    assign arprot   = 3'b0;
    assign rready   = 1'b1;
    assign awid     = 4'b0;
    assign awburst  = 2'b01;
    assign awlock   = 2'b0;
    assign awcache  = 4'b0;
    assign awprot   = 3'b0;
    assign wid      = 4'b0;
    assign bready   = 1'b1;

    wire refs   = bus_wen != `WrDisable;
    wire cop_en = cacheop != `COP_NOP;
    wire rreq   = bus_en & !refs;
    wire wreq   = bus_en &  refs;

    // Cached Channel
    reg             ca_enb;
    reg  [`ByteWEn] ca_wea,   ca_web;
    reg  [`D_ramad] ca_ada,   ca_adb;
    reg  [`DataBus] ca_dina,  ca_dinb;
    wire [`DataBus] ca_dout;

    Data_Cache_Ram dcache_ram (
        .clk    (aclk       ),
        .enb    (ca_enb     ),
        .wea    (ca_wea     ),
        .web    (ca_web     ),
        .ada    (ca_ada     ),
        .adb    (ca_adb     ),
        .dina   (ca_dina    ),
        .dinb   (ca_dinb    ),
        .dout   (ca_dout    )
    );

    reg  [`D_ptag] ca_ptag  [`D_lnNum];
    reg            ca_valid [`D_lnNum];
    reg            ca_dirty [`D_lnNum];

    wire [`D_idx ] ad_idx   = bus_addr[`D_addr_idx ];
    wire [`D_ptag] ad_ptag  = bus_addr[`D_addr_ptag];
    wire [`D_ptag] ln_ptag  = ca_ptag [ad_idx];
    wire           ln_valid = ca_valid[ad_idx];
    wire           ln_dirty = ca_dirty[ad_idx];
    wire           ln_hit   = (ln_ptag ^ ad_ptag) == 0 && ln_valid;
    wire           ln_wb    = !ln_hit && ln_valid && ln_dirty;

    // Uncached Channel
    reg [`Word] uc_data;
    reg [`Word] uc_addr;
    reg         uc_valid;
    wire        uc_hit = (uc_addr ^ bus_addr) == 0 && uc_valid;
    reg         uc_wrdy;

    reg         rw_streq;

    assign bus_streq = rw_streq || ca_enb;
    

    always @(*) begin
        r_streq <= `false;
        w_streq <= `false;
        ca_ada  <= bus_addr[`D_addr_ramad];
        ca_dina <= bus_wdata;
        ca_wea  <= `WrDisable;
        
        if(bus_en) begin
            if(cop_en) begin
                case (cacheop)
                    `COP_DIWI: w_streq <= ln_dirty && ln_valid;
                    `COP_DHWI: w_streq <= ln_dirty && ln_hit;
                endcase
            end
            else begin
                if(bus_cached) begin
                    ca_wea   <= ln_hit ? bus_wen : `WrDisable;
                    rw_streq <= !ln_hit;
                end
                else begin
                    if(refs) rw_streq <= !uc_wrdy;
                    else     rw_streq <= !uc_hit;
                end
            end
        end
    end

    reg [`Word] lk_addr;
    reg [`Word] lk_data;
    reg [ 3: 0] lk_strb;
    reg [ 1: 0] lk_size;
    reg [ 3: 0] cnt;
    reg [ 2: 0] state;

    wire [`D_idx] lk_idx = lk_addr[`D_addr_idx];
    
    integer i;
    initial begin
        for(i = 0; i < `I_lineN; i = i + 1) begin
            ca_ptag [i] <= 0;
            ca_valid[i] <= `false;
            ca_dirty[i] <= `false;
        end
    end
    
    parameter S_IDLE                = 4'h0;
    parameter S_CACHED_R_PREPARE    = 4'h1;
    parameter S_CACHED_R_TRANSFER   = 4'h2;
    parameter S_CACHED_R_END        = 4'h3;
    parameter S_UNCACHED_R_PREPARE  = 4'h4;
    parameter S_UNCACHED_R_TRANSFER = 4'h5;
    parameter S_UNCACHED_R_WAITEND  = 4'h6;
    parameter S_CACHED_W_PREPARE    = 4'h7;
    parameter S_CACHED_W_TRANSFER   = 4'h8;
    parameter S_CACHED_W_END        = 4'h9;
    parameter S_UNCACHED_W_PREPARE  = 4'hA;
    parameter S_UNCACHED_W_TRANSFER = 4'hB;
    parameter S_UNCACHED_W_RESPONSE = 4'hC;
    parameter S_UNCACHED_W_WAITEND  = 4'hC;
    
    always @(posedge aclk, negedge aresetn) begin
        if(!aresetn) begin
            state     <= 0;
            cnt       <= 0;
            ca_enb   <= `false;

            lk_addr   <= `ZeroWord;
            lk_cached <= `false;
            lk_size   <= `ASize_Word;
            lk_data   <= `ZeroWord;
            lk_strb   <= `WrDisable;

            arid     <= 0;
            araddr   <= 0;
            arlen    <= 0;
            arsize   <= 0;
            arvalid  <= 0;
            awaddr   <= 0;
            awlen    <= 0;
            awsize   <= 0;
            awvalid  <= 0;
            wstrb    <= 0;
            wlast    <= 0;
            wvalid   <= 0;

            ca_web   <= `WrDisable;
            ca_adb   <= `ZeroWord;
            ca_dinb  <= `ZeroWord;

            uc_data  <= `ZeroWord;
            uc_addr  <= `ZeroWord;
            uc_valid <= `false;
            uc_wrdy    <= `false;
        end
        else begin
            arvalid  <= 0;
            awvalid  <= 0;
            wvalid   <= 0;

            ca_web   <= `WrDisable;
            ca_adb   <= `ZeroWord;
            ca_dinb  <= `ZeroWord;

            uc_valid <= `false;
            uc_wrdy  <= `false;

            case (state)
                S_IDLE: 
                if(bus_en) begin
                    if(cop_en) begin
                        case (cacheop)
                            `COP_DIWI: begin
                                if(ln_valid && ln_dirty) begin
                                    lk_addr   <= {ln_ptag, ad_idx, 6'b0};
                                    lk_cached <= `true;
                                    cnt       <= 0;
                                    state     <= S_CACHED_W_PREPARE;
                                    ca_enb   <= `true;
                                end
                                else if(ln_valid)
                                    ca_valid[ad_idx] <= `false;
                            end

                            `COP_DIST: begin
                                ca_ptag [ad_idx] <= cop_taglo[`DTag_Tag];
                                ca_valid[ad_idx] <= cop_taglo[`DTag_Vld];
                                ca_dirty[ad_idx] <= cop_taglo[`DTag_Drt];
                            end

                            `COP_DHI: begin
                                if(ln_hit) ca_valid[ad_idx] <= `false;
                            end

                            `COP_DHWI: begin
                                if(ln_hit && ln_dirty) begin
                                    lk_addr   <= {ln_ptag, ad_idx, 6'b0};
                                    lk_cached <= `true;
                                    cnt       <= 0;
                                    state     <= S_CACHED_W_PREPARE;
                                    ca_enb   <= `true;
                                end
                                else if(ln_valid)
                                    ca_valid[ad_idx] <= `false;
                            end
                        endcase
                    end
                    else begin
                        if(bus_cached) begin
                            if(wreq && ln_hit) ca_dirty[ad_idx] <= `true;
                            
                            if(ln_wb) begin
                                lk_addr   <= {ln_ptag, ad_idx, 6'b0};
                                lk_cached <= `true;
                                cnt       <= 0;
                                state     <= S_CACHED_W_PREPARE;
                                ca_enb   <= `true;
                            end
                            else if(!ln_hit) begin
                                lk_addr   <= {ad_ptag, ad_idx, 6'b0};
                                lk_cached <= `true;
                                cnt       <= 0;
                                state     <= S_CACHED_R_PREPARE;
                                ca_ptag [ad_idx] <= bus_addr[`I_addr_ptag];
                                ca_valid[ad_idx] <= `false;
                                ca_enb           <= `true;
                            end
                        end
                        else begin //if uncached
                            if(!refs && !uc_hit) begin
                                lk_addr   <= bus_addr;
                                lk_cached <= `false;
                                lk_size   <= bus_size;
                                state     <= S_UNCACHED_R_PREPARE;
                            end
                            else if(refs && !uc_wrdy) begin
                                lk_addr   <= bus_addr;
                                lk_data   <= bus_wdata;
                                lk_strb   <= bus_wen;
                                lk_cached <= `false;
                                lk_size   <= bus_size;
                                state     <= S_UNCACHED_W_PREPARE;
                            end
                        end
                    end
                end
                
                S_CACHED_R_PREPARE: 
                if(arvalid && arready) state <= S_CACHED_R_TRANSFER;
                else begin
                    arid   <= 4'b0101;
                    araddr <= lk_addr;
                    arlen  <= 4'hF;
                    arsize <= 3'b010;
                    arvalid <= `true;
                end
                
                S_UNCACHED_R_PREPARE: 
                if(arvalid && arready) state <= S_UNCACHED_R_TRANSFER;
                else begin
                    arid   <= 4'b0100;
                    araddr <= lk_addr;
                    arlen  <= 4'h0;
                    arsize <= {1'b0, lk_size};
                    arvalid <= `true;
                end

                S_CACHED_R_TRANSFER:
                if(rvalid) begin
                    ca_web  <= 4'hF;
                    ca_adb  <= {lk_idx, cnt};
                    ca_dinb <= rdata;
                    cnt     <= cnt + 1;
                    if(rlast) state <= S_CACHED_R_END;
                end
                
                S_UNCACHED_R_TRANSFER:
                if(rvalid) begin
                    uc_data <= rdata;
                    uc_addr <= lk_addr;
                    if(rlast) begin
                        uc_valid <= `true;
                        state <= S_UNCACHED_R_WAITEND;
                    end
                end

                S_CACHED_R_END: begin
                    ca_valid[lk_idx] <= `true;
                    ca_enb           <= `false;
                    state            <= S_IDLE;
                end
                
                S_UNCACHED_R_WAITEND: 
                if((bus_stall ^ streq) == 0) begin
                        state    <= S_IDLE;
                        uc_valid <= `false;
                    end
                end

                
                S_CACHED_W_PREPARE:
                if(awvalid && awready) state <= S_CACHED_W_TRANSFER;
                else begin
                    awaddr  <= lk_addr;
                    awlen   <= 4'hF;
                    awsize  <= 3'b010;
                    awvalid <= `true;
                end
                
                S_UNCACHED_W_PREPARE:
                if(awvalid && awready) state <= S_UNCACHED_W_TRANSFER;
                else begin
                    awaddr  <= lk_addr;
                    awlen   <= 4'h0;
                    awsize  <= {1'b0, lk_size};
                    awvalid <= `true;
                end

                S_CACHED_W_TRANSER:
                if(wvalid && wready) begin
                    if(cnt == 4'hF) state <= S_CACHED_W_END;
                    else cnt <= cnt + 1;
                end
                else begin
                    ca_adb <= {lk_idx, cnt};
                    wstrb  <= 4'hF;
                    wvalid <= `true;
                    wlast  <= cnt == 4'hF;
                end
                
                S_UNCACHED_W_TRANSER:
                if(wvalid && wready) state <= S_UNCACHED_W_RESPONSE;
                else begin
                    wstrb  <= lk_strb;
                    wvalid <= `true;
                    wlast  <= `true;
                end

                S_CACHED_W_END:
                if(bvalid) begin
                    state <= S_IDLE;
                    ca_dirty[lk_idx] <= `false;
                    ca_valid[lk_idx] <= `false;  // used in cache invalidate operation
                    ca_enb           <= `false;
                end
                
                S_UNCACHED_W_RESPONSE:
                if(bvalid) begin
                    state <= S_UNCACHED_W_WAITEND;
                    uc_wrdy  <= `true;
                end
                
                S_UNCACHED_W_WAITEND:
                if((bus_stall ^ streq) == 0) begin
                    state    <= S_IDLE;
                    uc_wrdy  <= `false;
                end

            endcase
        end
    end

    assign bus_rdata = bus_cached ? ca_dout : uc_data;
    assign wdata     = wlk_cached ? ca_dout : wlk_data;

endmodule