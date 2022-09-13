`timescale 1ps/1ps
module adder1 (
    input a,
    input b,
    input cin,
    output s,
    output cout
);
    assign cout = a&b | a&cin | b&cin;
    assign s    = a ^ b ^ cin;
endmodule

module hadder (
    input a,
    input b,
    output s,
    output c
);
  assign s = a^b;
  assign c = a&b;  
endmodule

module booth_switch (
    input [63:0]  x,
    input [3:0]   s,
    output [63:0] p
);
    wire [64:0] x64;
    wire [64:0] xb;
    assign x64={x,1'b0};
    assign xb=  ~x64;
    genvar  i;
    generate
        for(i=1;i<65;i=i+1)begin:bs
            assign p[i-1]=(s[0]&xb[i])|(s[2]&xb[i-1])|(s[1]&x64[i])|(s[3]&x64[i-1]);
        end
    endgenerate
endmodule

module booth_kernel_32 (
    input [2:0]y,
    input [63:0]x,
    output [63:0]p,
    output c
);
    wire [3:0]s;//s[3:0]:S_{+2X},S_{-2X},S_{X},S_{-X}
    wire [2:0]yb;
    assign yb=~y;
    assign s[0]=y[2] &(y[1]^y[0]);
    assign s[1]=yb[2]&(y[1]^y[0]);
    assign s[2]=y[2] &yb[1]&yb[0];
    assign s[3]=yb[2]&y[1]&y[0];
    assign c=s[2]|s[0];
    booth_switch  bs(.x(x),.s(s),.p(p));
endmodule

module wallace_tree_16 (
    input [15:0]N,
    input [13:0]cin,
    output [13:0]cpass,
    output Sout,
    output Cout
);
    wire [13:0]s;
    // first layer
    adder1 a1(.a(N[0]),.b(N[1]),.cin(N[2]),   .s(s[0]),.cout(cpass[0]));
    adder1 a2(.a(N[3]),.b(N[4]),.cin(N[5]),   .s(s[1]),.cout(cpass[1]));
    adder1 a3(.a(N[6]),.b(N[7]),.cin(N[8]),   .s(s[2]),.cout(cpass[2]));
    adder1 a4(.a(N[9]),.b(N[10]),.cin(N[11]), .s(s[3]),.cout(cpass[3]));
    adder1 a5(.a(N[12]),.b(N[13]),.cin(N[14]),.s(s[4]),.cout(cpass[4]));
    //second layer
    adder1 a6(.a(s[0]),.b(s[1]),.cin(s[2]),      .s(s[5]),.cout(cpass[5]));
    adder1 a7(.a(s[3]),.b(s[4]),.cin(N[15]),     .s(s[6]),.cout(cpass[6]));
    adder1 a8(.a(cin[0]),.b(cin[1]),.cin(cin[2]),.s(s[7]),.cout(cpass[7]));
    //third layer
    adder1 a9(.a(s[5]),.b(s[6]),.cin(s[7]),.s(s[8]),.cout(cpass[8]));
    adder1 a10(.a(cin[3]),.b(cin[4]),.cin(cin[5]),.s(s[9]),.cout(cpass[9]));
    hadder ha(.a(cin[6]),.b(cin[7]),.s(s[10]),.c(cpass[10]));
    //fouth layer
    adder1 a11(.a(s[8]),.b(s[9]),.cin(s[10]),.s(s[11]),.cout(cpass[11]));
    adder1 a12(.a(cin[8]),.b(cin[9]),.cin(cin[10]),.s(s[12]),.cout(cpass[12]));
    //fifth layer
    adder1 a13(.a(s[11]),.b(s[12]),.cin(cin[11]),.s(s[13]),.cout(cpass[13]));
    //sixth layer
    adder1 a14(.a(s[13]),.b(cin[12]),.cin(cin[13]),.s(Sout),.cout(Cout));
endmodule

module wallace_switch_32 (
    input [64*16-1:0]p,
    input [15:0]c,
    output [16*64-1:0]pout,
    output [15:0]cout
);
    assign cout=c;
    genvar i,j;
    generate
        for(i=0;i<64;i=i+1) begin:ws1
            for(j=0;j<16;j=j+1) begin:ws2
                assign pout[i*16+j]=p[j*64+i];
            end
        end
    endgenerate
endmodule

module wallace_matrix (
    input [16*64-1:0]p,
    input [15:0]c,
    output[63:0]cout,
    output[63:0]s
);
    wire [13:0]cpass[63:0];
    wire [64:0]outemp;
    assign cout[0]=c[1];
    wallace_tree_16 w0(.N(p[15:0]),.cin(c[15:2]),.cpass(cpass[0]),.Sout(s[0]),.Cout(outemp[1]));
    genvar i;
    generate
        for(i=1;i<64;i=i+1)begin:wm
            wallace_tree_16 wt(
                .N(p[16*i+15:16*i]),
                .cin(cpass[i-1]),
                .cpass(cpass[i]),
                .Sout(s[i]),
                .Cout(outemp[i+1])
            );
        end
    endgenerate
    assign cout[63:1]=outemp[63:1];
endmodule

module mul (
    input [31:0]x,
    input [31:0]y,
    output[63:0]s
);
    wire [63:0]xin;
    wire [32:0]yin;
    wire [63:0]xpara[15:0];
    wire [2:0]ypara[15:0];
    wire [64*16-1:0]p;
    wire [15:0]c;
    wire [16*64-1:0]pout_ws;
    wire [15:0]cout_ws;
    wire [63:0]cout_wm;
    wire [63:0]s_wm;
    assign xin={{32{x[31]}},x};
    assign yin={y,1'b0};
    assign xpara[0]=xin;
    genvar i;
    generate
        for(i=0;i<16;i=i+1)begin:m
            assign ypara[i] = yin[2+2*i:0+2*i];
        end
        for(i=1;i<16;i=i+1)begin:m1
            assign xpara[i]=xpara[i-1]<<2;
        end
    endgenerate
    generate
        for(i=0;i<16;i=i+1)begin:m2
            booth_kernel_32 bk(
                .y(ypara[i]),
                .x(xpara[i]),
                .p(p[64*i+63:64*i]),
                .c(c[i])
            );
        end
    endgenerate
    wallace_switch_32 ws(.p(p),.c(c),.pout(pout_ws),.cout(cout_ws));
    wallace_matrix wm(.p(pout_ws),.c(cout_ws),.cout(cout_wm),.s(s_wm));
    assign s = s_wm + cout_wm + {63'b0,cout_ws[0]};
endmodule