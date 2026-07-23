const std = @import("std");
const ast = @import("ast.zig");

pub const EvaluateError = error{
    InvalidExpression,
    InvalidOperator,
    DivisionByZero,
};

pub const Evaluator = struct {
    const Self = @This();

    pub fn evaluate(self: *Self, expr: *const ast.Expr) EvaluateError!f64 {
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
