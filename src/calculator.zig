const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const ast = @import("ast.zig");

pub const Error = tokenizer.TokenizeError || parser.ParserError || EvaluateError || std.mem.Allocator.Error || std.fmt.ParseFloatError;

const EvaluateError = error{
    InvalidExpression,
    InvalidOperator,
    DivisionByZero,
};

pub const Calculator = struct {
    const Self = @This();
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn calculate(self: *Self, input: []const u8) Error!f64 {
        var tok = tokenizer.Tokenizer.init(self.allocator, input);

        const tokens = try tok.tokenize();
        defer self.allocator.free(tokens);

        var p = parser.Parser.init(self.allocator, tokens);

        const expression = try p.parse();
        defer expression.destroy(self.allocator);

        return self.evaluate(expression);
    }

    fn evaluate(self: *Self, expr: *const ast.Expr) EvaluateError!f64 {
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

test "evaluate number" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("42");
    try std.testing.expectEqual(@as(f64, 42), result);
}

test "evaluate unary minus" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("-5");
    try std.testing.expectEqual(@as(f64, -5), result);
}

test "evaluate addition" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("3 + 2");
    try std.testing.expectEqual(@as(f64, 5), result);
}

test "evaluate multiplication" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("3 * 2");
    try std.testing.expectEqual(@as(f64, 6), result);
}

test "evaluate operator precedence" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("2 + 3 * 4");
    try std.testing.expectEqual(@as(f64, 14), result);
}

test "evaluate grouping" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("(2 + 3) * 4");
    try std.testing.expectEqual(@as(f64, 20), result);
}

test "evaluate mixed expression" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("12/4+2*3");
    try std.testing.expectEqual(@as(f64, 9), result);
}

test "evaluate nested unary" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("--5");
    try std.testing.expectEqual(@as(f64, 5), result);
}

test "evaluate modulo" {
    var calculator = Calculator.init(std.testing.allocator);
    const result = try calculator.calculate("10 % 3");
    try std.testing.expectEqual(@as(f64, 1), result);
}

test "division by zero" {
    var calculator = Calculator.init(std.testing.allocator);
    try std.testing.expectError(
        Error.DivisionByZero,
        calculator.calculate("10 / 0"),
    );
}
