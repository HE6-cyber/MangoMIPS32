/********************MangoMIPS32*******************
Filename:	WriteBack.v
Author:		RickyTino
Version:	Unreleased
**************************************************/
`include "defines.v"

module WriteBack
(
    input  wire [`DataBus] alures,
    output reg  [`DataBus] wrdata
);

    always @(*) begin
        wrdata <= alures;
    end

endmodule