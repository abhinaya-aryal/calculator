const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const evaluator = @import("evaluator.zig");

pub const Error = tokenizer.TokenizeError || parser.ParserError || evaluator.EvaluateError || std.mem.Allocator.Error || std.fmt.ParseFloatError;

pub fn calculate(allocator: std.mem.Allocator, input: []const u8) Error!f64 {
    var tok = tokenizer.Tokenizer.init(allocator, input);

    const tokens = try tok.tokenize();
    defer allocator.free(tokens);

    var p = parser.Parser.init(allocator, tokens);

    const expression = try p.parse();
    defer expression.destroy(allocator);

    var eval = evaluator.Evaluator{};
    return eval.evaluate(expression);
}

test "evaluate number" {
    const result = try calculate(std.testing.allocator, "42");
    try std.testing.expectEqual(@as(f64, 42), result);
}

test "evaluate unary minus" {
    const result = try calculate(std.testing.allocator, "-5");
    try std.testing.expectEqual(@as(f64, -5), result);
}

test "evaluate addition" {
    const result = try calculate(std.testing.allocator, "3 + 2");
    try std.testing.expectEqual(@as(f64, 5), result);
}

test "evaluate multiplication" {
    const result = try calculate(std.testing.allocator, "3 * 2");
    try std.testing.expectEqual(@as(f64, 6), result);
}

test "evaluate operator precedence" {
    const result = try calculate(std.testing.allocator, "2 + 3 * 4");
    try std.testing.expectEqual(@as(f64, 14), result);
}

test "evaluate grouping" {
    const result = try calculate(std.testing.allocator, "(2 + 3) * 4");
    try std.testing.expectEqual(@as(f64, 20), result);
}

test "evaluate mixed expression" {
    const result = try calculate(std.testing.allocator, "12/4+2*3");
    try std.testing.expectEqual(@as(f64, 9), result);
}

test "evaluate nested unary" {
    const result = try calculate(std.testing.allocator, "--5");
    try std.testing.expectEqual(@as(f64, 5), result);
}

test "evaluate modulo" {
    const result = try calculate(std.testing.allocator, "10 % 3");
    try std.testing.expectEqual(@as(f64, 1), result);
}

test "division by zero" {
    try std.testing.expectError(
        Error.DivisionByZero,
        calculate(std.testing.allocator, "10 / 0"),
    );
}
