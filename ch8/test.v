`timescale 1ps/1ps

module test;
    reg [31:0]x,y;
    wire [63:0]s;
    mul m(.x(x),.y(y),.s(s));
    initial begin
        {x,y}=$random;
        
        forever begin
            #10 x=$random;y=$random;
        end
    end
    initial begin
        $dumpfile("mul.vcd");
        $dumpvars(0);
        #200 $finish();
    end
endmodule
