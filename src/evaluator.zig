const std = @import("std");
const parser = @import("parser.zig");
const Expr = @import("ast.zig").Expr;

pub const EvaluateError = error{
    InvalidExpression,
    InvalidOperator,
    DivisionByZero,
};

pub const Evaluator = struct {
    const Self = @This();

    pub fn evaluate(self: *Self, expr: *const Expr) EvaluateError!f64 {
        switch (expr.*) {
            .number => |value| {
                return value;
            },
            .grouping => |node| {
                return self.evaluate(node);
            },
            .unary => |node| {
                const operand_value = try self.evaluate(node.operand);

                return switch (node.operator.kind) {
                    .plus => operand_value,
                    .minus => -operand_value,
                    else => EvaluateError.InvalidOperator,
                };
            },
            .binary => |node| {
                const left = try self.evaluate(node.left);
                const right = try self.evaluate(node.right);

                switch (node.operator.kind) {
                    .plus => {
                        return left + right;
                    },
                    .minus => {
                        return left - right;
                    },
                    .star => {
                        return left * right;
                    },
                    .slash => {
                        if (right == 0) return EvaluateError.DivisionByZero;
                        return left / right;
                    },
                    .percent => {
                        return @mod(left, right);
                    },
                    else => {
                        return EvaluateError.InvalidOperator;
                    },
                }
            },
        }
    }
};

fn evaluateExpression(input: []const u8) !f64 {
    const allocator = std.testing.allocator;

    var tokenizer = @import("tokenizer.zig").Tokenizer.init(allocator, input);

    const tokens = try tokenizer.tokenize();
    defer allocator.free(tokens);

    var p_parser = @import("parser.zig").Parser.init(allocator, tokens);

    const expression = try p_parser.parse();
    defer expression.destroy(allocator);

    var evaluator = Evaluator{};
    return try evaluator.evaluate(expression);
}

test "evaluate number" {
    const result = try evaluateExpression("42");
    try std.testing.expectEqual(@as(f64, 42), result);
}

test "evaluate unary minus" {
    const result = try evaluateExpression("-5");
    try std.testing.expectEqual(@as(f64, -5), result);
}

test "evaluate addition" {
    const result = try evaluateExpression("3 + 2");
    try std.testing.expectEqual(@as(f64, 5), result);
}

test "evaluate multiplication" {
    const result = try evaluateExpression("3 * 2");
    try std.testing.expectEqual(@as(f64, 6), result);
}

test "evaluate operator precedence" {
    const result = try evaluateExpression("2 + 3 * 4");
    try std.testing.expectEqual(@as(f64, 14), result);
}

test "evaluate grouping" {
    const result = try evaluateExpression("(2 + 3) * 4");
    try std.testing.expectEqual(@as(f64, 20), result);
}

test "evaluate mixed expression" {
    const result = try evaluateExpression("12/4+2*3");
    try std.testing.expectEqual(@as(f64, 9), result);
}

test "evaluate nested unary" {
    const result = try evaluateExpression("--5");
    try std.testing.expectEqual(@as(f64, 5), result);
}

test "evaluate modulo" {
    const result = try evaluateExpression("10 % 3");
    try std.testing.expectEqual(@as(f64, 1), result);
}

test "division by zero" {
    try std.testing.expectError(
        EvaluateError.DivisionByZero,
        evaluateExpression("10 / 0"),
    );
}
