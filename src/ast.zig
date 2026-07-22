const std = @import("std");
const Tokenizer = @import("tokenizer.zig");
const Token = Tokenizer.Token;
const TokenKind = Tokenizer.TokenKind;

pub const ParserError = error{
    InvalidToken,
    ExpectedExpression,
    ExpectedRightParen,
};

pub const Expr = union(enum) {
    const Self = @This();

    number: f64,

    binary: BinaryExpr,

    grouping: *Expr,

    unary: UnaryExpr,

    pub fn destroy(
        self: *Self,
        allocator: std.mem.Allocator,
    ) void {
        switch (self.*) {
            .number => {},

            .grouping => |inner| {
                inner.destroy(allocator);
            },

            .unary => |u| {
                u.operand.destroy(allocator);
            },

            .binary => |b| {
                b.left.destroy(allocator);
                b.right.destroy(allocator);
            },
        }

        allocator.destroy(self);
    }
};

const BinaryExpr = struct {
    left: *Expr,
    operator: Token,
    right: *Expr,
};

const UnaryExpr = struct {
    operator: Token,
    operand: *Expr,
};
