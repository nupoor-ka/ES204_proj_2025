`timescale 1ns / 1ps

module posit_multiplier(
    input [31:0] a, b,
    output reg [31:0] product,
    output reg error,
    output reg zero
);

    wire sign = a[31] ^ b[31];

    // Extracting regime values
    wire signed [5:0] ka, kb, k;
    wire [4:0] len_reg_a, len_reg_b;
    k_extractor kext1(a, ka, len_reg_a);
    k_extractor kext2(b, kb, len_reg_b);
    assign k = ka + kb;

    // Extracting mantissas
    wire [3:0] es1, es2;
    wire [26:0] man_val_1, man_val_2;
    mantissa_extractor man_ext1(a, es1, man_val_1, len_reg_a);
    mantissa_extractor man_ext2(b, es2, man_val_2, len_reg_b);

    // Multiplying mantissas
    wire carry_1;
    wire [55:0] man_final;
    mantissa_multiplier multip_man(man_val_1, man_val_2, carry_1, man_final);

    wire [4:0] es_tot = es1 + es2 + carry_1;
    wire [3:0] es_val = es_tot[3:0];
    wire carry = es_tot[4];

    wire signed [5:0] k_final = k + carry;

    integer i;

    always @(*) begin
        product = 32'b0;
        error = 0;
        zero = 0;

        if ((a == 32'b0) || (b == 32'b0)) begin
            zero = 1;
            product = 32'b0;
        end
        else if ((k_final > 25) || (k_final < -26)) begin
            error = 1;
            product = 32'bx;
        end
        else begin
            product[31] = sign;

            if (k_final >= 0) begin
                for (i = 0; i <= k_final; i = i + 1)
                    product[30 - i] = 1;
                product[30 - k_final - 1] = 0;

                for (i = 0; i < 4; i = i + 1)
                    product[30 - k_final - 2 - i] = es_val[3 - i];

                for (i = 0; i < 30 - k_final - 6; i = i + 1)
                    product[i] = man_final[53 - i];
            end
            else begin
                for (i = 0; i < -k_final; i = i + 1)
                    product[30 - i] = 0;
                product[30 + k_final] = 1;

                for (i = 0; i < 4; i = i + 1)
                    product[30 + k_final - 1 - i] = es_val[3 - i];

                for (i = 0; i < 30 + k_final - 5; i = i + 1)
                    product[i] = man_final[53 - i];
            end
        end
    end
 
endmodule

module mantissa_multiplier(
    input [26:0] man_1, man_2,
    output wire carry,
    output wire [55:0] man_final
);
    wire [27:0] m1 = {1'b1, man_1};
    wire [27:0] m2 = {1'b1, man_2};
    wire [55:0] man_temp = m1 * m2;

    assign carry = ~man_temp[55];  // If MSB is 0, we normalize
    assign man_final = carry ? (man_temp << 1) : man_temp;
endmodule

module mantissa_extractor(
    input [31:0] inp,
    output [3:0] es,
    output [26:0] man_val,
    input [4:0] len_regime
);
    wire [4:0] es_start = 30 - len_regime;
    assign es = inp[es_start -: 4];
    assign man_val = inp[es_start - 4 -: 27];
endmodule

module k_extractor(
    input [31:0] inp,
    output reg signed [5:0] k_val,
    output reg [4:0] len_regime
);
    integer i;
    reg found;

    always @(*) begin
        len_regime = 0;
        k_val = 0;
        found = 0;

        if (inp[30] == 1'b1) begin  // Positive regime
            for (i = 29; i >= 0; i = i - 1) begin
                if (!found && inp[i] == 1'b0) begin
                    len_regime = 30 - i;
                    k_val = len_regime - 1;
                    found = 1;
                end
            end
        end else begin  // Negative regime
            for (i = 29; i >= 0; i = i - 1) begin
                if (!found && inp[i] == 1'b1) begin
                    len_regime = 30 - i;
                    k_val = -len_regime;
                    found = 1;
                end
            end
        end
    end
endmodule
