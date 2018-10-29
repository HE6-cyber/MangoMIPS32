/********************MangoMIPS32*******************
Filename:	MEM_WB.v
Author:		RickyTino
Version:	Unreleased 20181029
**************************************************/
`include "defines.v"

module MEM_WB
(
    input  wire            clk,
    input  wire            rst,

    input  wire [`AddrBus] mem_pc,
    input  wire [`ALUOp  ] mem_aluop, 
    input  wire [`DataBus] mem_alures,
    input  wire [`DataBus] mem_memdata,
    input  wire [`RegAddr] mem_wraddr,
    input  wire            mem_wreg,

    output reg  [`AddrBus] wb_pc,
    output reg  [`ALUOp  ] wb_aluop, 
    output reg  [`DataBus] wb_alures,
    output reg  [`DataBus] wb_memdata,
    output reg  [`RegAddr] wb_wraddr,
    output reg             wb_wreg
);

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            wb_pc      <= `ZeroWord;
            wb_aluop   <= `ALU_NOP;
            wb_alures  <= `ZeroWord;
            wb_memdata <= `ZeroWord;
            wb_wraddr  <= `ZeroReg;
            wb_wreg    <= `false;
        end
        else begin
            wb_pc      <= mem_pc;
            wb_aluop   <= mem_aluop;
            wb_alures  <= mem_alures;
            wb_memdata <= mem_memdata;
            wb_wraddr  <= mem_wraddr;
            wb_wreg    <= mem_wreg;
        end
    end

endmodule