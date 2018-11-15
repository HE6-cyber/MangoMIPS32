/********************MangoMIPS32*******************
Filename:	HiLo_LLbit.v
Author:		RickyTino
Version:	Preview2-181115
**************************************************/
`include "Defines.v"

module HiLo_LLbit
(
    input  wire          clk,
    input  wire          rst,
	input  wire          hilo_wen,
	input  wire [`DWord] hilo_wdata,
    output wire [`DWord] hilo_rdata,

	input  wire          llb_wen,
	input  wire          llb_wdata,
	input  wire          mem_llb_wen,
	input  wire          mem_llbit,
	output wire          llb_rdata
);
	reg [`DWord] hilo;
	reg          llbit;

	always @(posedge clk, posedge rst) begin
		if(rst) begin
            hilo <= `ZeroDWord;
			llbit <= `Zero;
		end
		else begin
			if(hilo_wen) hilo <= hilo_wdata;
			if(llb_wen) llbit <= llb_wdata;
		end
	end

    assign hilo_rdata = hilo_wen ? hilo_wdata : hilo;
	assign llb_rdata  = mem_llb_wen ? mem_llbit : 
	                        llb_wen ? llb_wdata : llbit;
	
endmodule
