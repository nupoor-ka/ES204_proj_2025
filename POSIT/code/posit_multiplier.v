`timescale 1ns / 1ps

module posit_multiplier(
    input  [31:0] a, b,
    output reg [31:0] product,
    output reg error,
    output reg zero
);

    // Sign of the product
    wire sign = a[31] ^ b[31];

    // Regime extraction outputs
    wire signed [5:0] ka, kb;
    wire signed [5:0] k;
    wire [4:0] len_reg_a, len_reg_b;

    // Extracting regime values from inputs
    k_extractor kext1(.inp(a), .k_val(ka), .len_regime(len_reg_a));
    k_extractor kext2(.inp(b), .k_val(kb), .len_regime(len_reg_b));
    
    wire ma_lena = 32-1-4-len_reg_a;
    wire ma_lenb = 32-1-4-len_reg_b;

    // Sum of regimes
    assign k = ka + kb;

    // Exponent and mantissa extraction
    wire [3:0] es1, es2;
    wire [26:0] man_val_1, man_val_2;

    mantissa_extractor man_ext1(.inp(a), .es(es1), .man_val(man_val_1), .len_regime(len_reg_a));
    mantissa_extractor man_ext2(.inp(b), .es(es2), .man_val(man_val_2), .len_regime(len_reg_b));

    // Mantissa multiplication
    wire carry_1;
    wire [53:0] man_final;

    // mantissa_multiplier multip_man(.man_1(man_val_1), .man_2(man_val_2), .carry(carry_1), .man_final(man_final));
    mantissa_mult_variable multip_man(
        .mantissa_a(man_val_1),
        .mantissa_b(man_val_2),
        .sizea(ma_lena),  // Number of valid LSBs in mantissa_a (1-32)
        .sizeb(ma_lenb),  // Number of valid LSBs in mantissa_b (1-32)
        .mantissa_out(man_final)
);

    // Exponent addition with carry from mantissa multiplication
    wire [4:0] es_tot = es1 + es2 + carry_1;
    wire [3:0] es_val = es_tot[3:0];
    wire carry = es_tot[4];

    // Final regime value including carry
    wire signed [5:0] k_final = k + carry;    

    integer i;

    always @(*) begin
        product = 32'b0;
        error = 0;
        zero = 0;

        // Handle zero inputs
        if ((a == 32'b0) || (b == 32'b0)) begin
            zero = 1;
            product = 32'b0;
        end
        // Handle regime overflow/underflow
        else if ((k_final > 25) || (k_final < -26)) begin
            error = 1;
            product = 32'bx;
        end
        else begin
            product[31] = sign;

            if (k_final >= 0) begin
                // Positive regime bits
                for (i = 0; i <= k_final; i = i + 1)
                    product[30 - i] = 1'b1;

                product[30 - k_final - 1] = 1'b0;

                // Exponent bits
                for (i = 0; i < 4; i = i + 1)
                    product[30 - k_final - 2 - i] = es_val[3 - i];

                // Mantissa bits
                for (i = 0; i <= 30 - k_final - 6; i = i + 1)
                    if(53-i-num_zeros>=0)
                    product[30-k_final-6-i] = man_final[53 - i];
            end
            else begin
                // Negative regime bits
                for (i = 0; i < (0-k_final); i = i + 1)
                    product[30 - i] = 1'b0;

                product[30 + k_final] = 1'b1;

                // Exponent bits
                for (i = 0; i < 4; i = i + 1)
                    product[30 + k_final - 1 - i] = es_val[3 - i];

                // Mantissa bits
                for (i = 0; i <= 30 + k_final - 5; i = i + 1)
                if(53-i-num_zeros>=0)
                    product[30 + k_final - 5-i] = man_final[53 - i];
            end
        end
    end

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

        if (inp[30] == 1'b1) begin  // positive regime val
            for (i = 29; i >= 0; i = i - 1) begin
                if (!found && inp[i] == 1'b0) begin
                    len_regime = 31 - i;
                    k_val = len_regime - 2;
                    found = 1;
                end
            end
        end else begin  // Negative regime avl
            for (i = 29; i >= 0; i = i - 1) begin
                if (!found && inp[i] == 1'b1) begin
                    len_regime = 31 - i;
                    k_val = -len_regime+1;
                    found = 1;
                end
            end
        end
    end
endmodule

module mantissa_extractor(
    input  [31:0] inp,
    output reg [3:0] es,
    output reg [26:0] man_val,
    input  [4:0] len_regime
);
    integer es_start;
    integer mantissa_start;
    integer i;
    reg [26:0] temp_mantissa;

    always @(*) begin
        es_start = 30 - len_regime;
        es = 4'b0;
        man_val = 27'b0;
        temp_mantissa = 27'b0;

        // Extract exponent
        if (es_start >= 3) begin
            es = inp[es_start -: 4];
        end else begin
            es = 4'b0;
        end

        mantissa_start = es_start - 4;

        if (mantissa_start < 0) begin
            man_val = 27'b0;
        end else begin
            // Extract (mantissa_start + 1) bits from inp[0 to mantissa_start]
            for (i = 0; i <= mantissa_start && i < 27; i = i + 1) begin
                temp_mantissa[26 - i] = inp[mantissa_start-i];
            end
        end
    end
endmodule

module mantissa_mult_variable (
    input  [31:0] mantissa_a,
    input  [31:0] mantissa_b,
    input  [5:0]  sizea,  // Number of valid LSBs in mantissa_a (1-32)
    input  [5:0]  sizeb,  // Number of valid LSBs in mantissa_b (1-32)
    output [53:0] mantissa_out
);
    wire [31:0] mask_a = (32'hFFFFFFFF >> (32 - sizea)); //posit doesn't allow variables inside slicing thing
wire [31:0] mask_b = (32'hFFFFFFFF >> (32 - sizeb));

wire [31:0] valid_a = mantissa_a & mask_a;
wire [31:0] valid_b = mantissa_b & mask_b;

wire [32:0] sig_a = {1'b1, valid_a};
wire [32:0] sig_b = {1'b1, valid_b};

wire [65:0] product = sig_a * sig_b;

wire        product_msb = product[65]; // 1 when product >= 2
wire [32:0] normalized = product_msb ? product[64:32] : product[63:31];

wire [31:0] result = ~normalized[31:0] + 1'b1;

assign mantissa_out = result;

endmodule
