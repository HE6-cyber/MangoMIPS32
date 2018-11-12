/********************MangoMIPS32*******************
Filename:	WriteBack.v
Author:		RickyTino
Version:	Unreleased
**************************************************/
`include "Defines.v"

module WriteBack
(
    input  wire [`ALUOp  ] aluop,
    input  wire [`DataBus] alures,
    input  wire [`DataBus] opr2,
    input  wire [`AddrBus] m_vaddr,
    input  wire [`DataBus] m_rdata,
    output wire [`DataBus] wrdata,
    output wire            stallreq
);

    assign stallreq = `false;

    reg [`Word] memdata;
    wire        memtoreg;

    always @(*) begin
		case (aluop)
			`ALU_LB: begin
                memtoreg <= `true;
				case (m_vaddr[1:0])
					2'b00: memdata <= {{24{m_rdata[ 7]}}, m_rdata[ 7: 0]};
					2'b01: memdata <= {{24{m_rdata[15]}}, m_rdata[15: 8]};
					2'b10: memdata <= {{24{m_rdata[23]}}, m_rdata[23:16]};
					2'b11: memdata <= {{24{m_rdata[31]}}, m_rdata[31:24]};
				endcase
			end
			
			`ALU_LBU: begin
                memtoreg <= `true;
				case (m_vaddr[1:0])
					2'b00: memdata <= {24'b0, m_rdata[ 7: 0]};
					2'b01: memdata <= {24'b0, m_rdata[15: 8]};
					2'b10: memdata <= {24'b0, m_rdata[23:16]};
					2'b11: memdata <= {24'b0, m_rdata[31:24]};
				endcase
			end
			
			`ALU_LH: begin
                memtoreg <= `true;
				case (m_vaddr[1:0])
					2'b00:   memdata <= {{16{m_rdata[15]}}, m_rdata[15: 0]};
					2'b10:   memdata <= {{16{m_rdata[31]}}, m_rdata[31:16]};
					default: memdata <= `ZeroWord;
				endcase
			end
			
			`ALU_LHU: begin
                memtoreg <= `true;
				case (m_vaddr[1:0])
					2'b00:   memdata <= {16'b0, m_rdata[15: 0]};
					2'b10:   memdata <= {16'b0, m_rdata[31:16]};
					default: memdata <= `ZeroWord;
				endcase
			end
			
			`ALU_LW: begin
                memtoreg <= `true;
                memdata  <= m_rdata;
			end

			`ALU_LWL: begin
                memtoreg <= `true;
				case (m_vaddr[1:0])
					2'b00: memdata <= {m_rdata[ 7:0], opr2[23:0]};
					2'b01: memdata <= {m_rdata[15:0], opr2[15:0]};
					2'b10: memdata <= {m_rdata[23:0], opr2[ 7:0]};
					2'b11: memdata <=  m_rdata[31:0];
				endcase
			end
			
			`ALU_LWR: begin
                memtoreg <= `true;
				case (m_vaddr[1:0])
					2'b00: memdata <=               m_rdata[31: 0];
					2'b01: memdata <= {opr2[31:24], m_rdata[31: 8]};
					2'b10: memdata <= {opr2[31:16], m_rdata[31:16]};
					2'b11: memdata <= {opr2[31: 8], m_rdata[31:24]};
				endcase
			end
			
			default: begin
                memtoreg <= `false;
                memdata  <= `ZeroWord;
            end
		endcase
	end

    assign wrdata = memtoreg ? memdata : alures;

endmodule