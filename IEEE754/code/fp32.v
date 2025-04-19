module fp32(
    input [31:0] a, // first floating-point number
    input [31:0] b, // second floating-point number
    output reg [31:0] product // product
);

    // sign, exponent, and mantissa 
    wire sign1, sign2, sign;
    wire [7:0] es1, es2;
    wire [22:0] mantissa1, mantissa2;
    reg [47:0] mantissa_product;
    reg [7:0] exponent_result;
    
    wire a_zero, b_zero;
    wire a_inf, b_inf;
    wire a_nan, b_nan;
    
    assign sign1 = a[31];
    assign es1 = a[30:23];
    assign mantissa1 = a[22:0];

    assign sign2 = b[31];
    assign es2 = b[30:23];
    assign mantissa2 = b[22:0];

    assign sign = sign1 ^ sign2;

    // for corner cases
    assign a_zero = (es1 == 8'd0) && (mantissa1 == 23'd0);
    assign b_zero = (es2 == 8'd0) && (mantissa2 == 23'd0);
    
    assign a_inf = (es1 == 8'b11111111) && (mantissa1 == 0);
    assign b_inf = (es2 == 8'b11111111) && (mantissa2 == 0);

    assign a_nan = (es1 == 8'b11111111) && (mantissa1 != 0);
    assign b_nan = (es2 == 8'b11111111) && (mantissa2 != 0);

    wire [7:0] e_sum = es1 + es2 - 8'd127;

    always @(*) begin
        product = 32'd0;

        // NaNs
        if (a_nan || b_nan) begin
            product = {1'b0, 8'b11111111, 23'h400000}; // Quiet NaN
        end
        // Infinity * Zero => NaN
        else if ((a_inf && b_zero) || (b_inf && a_zero)) begin
            product = {1'b0, 8'b11111111, 23'h400000}; // Quiet NaN
        end
        // Infinity cases
        else if (a_inf || b_inf) begin
            product = {sign, 8'b11111111, 23'd0}; // Inf with correct sign
        end
        // Zero cases
        else if (a_zero || b_zero) begin
            product = {sign, 8'd0, 23'd0}; // Zero with correct sign
        end
        // for normal cases
        else begin
            mantissa_product = {1'b1, mantissa1} * {1'b1, mantissa2};
            if (mantissa_product[47]) begin
                exponent_result = e_sum + 1;
                product = {sign, exponent_result, mantissa_product[46:24]};
            end else begin
                exponent_result = e_sum;
                product = {sign, exponent_result, mantissa_product[45:23]};
            end
        end
    end
endmodule
