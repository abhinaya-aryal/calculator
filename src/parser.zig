const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const ast = @import("ast.zig");

pub const ParserError = error{
    InvalidToken,
    ExpectedExpression,
    ExpectedRightParen,
} || std.mem.Allocator.Error || std.fmt.ParseFloatError;

pub const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    tokens: []const tokenizer.Token,
    current: usize = 0,

    /// **Initializes** a Parser
    ///
    /// # Parameters
    /// - `allocator`: Memory allocator use for parsing
    /// - `tokens`: Slice of `Token` to parse
    ///
    pub fn init(allocator: std.mem.Allocator, tokens: []const tokenizer.Token) Self {
        return .{
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    /// **Parses** tokens provided through `init`
    pub fn parse(self: *Self) ParserError!*ast.Expr {
        return self.expression();
    }

    fn expression(self: *Self) ParserError!*ast.Expr {
        return self.term();
    }

    fn term(self: *Self) ParserError!*ast.Expr {
        var expr = try self.factor();

        while (self.match(&.{ .plus, .minus })) {
            const operator = self.previous();
            const right = try self.factor();

            const node = try self.allocator.create(ast.Expr);
            node.* = .{ .binary = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };

            expr = node;
        }

        return expr;
    }

    fn factor(self: *Self) ParserError!*ast.Expr {
        var expr = try self.unary();

        while (self.match(&.{ .star, .slash, .percent })) {
            const operator = self.previous();
            const right = try self.unary();

            const node = try self.allocator.create(ast.Expr);

            node.* = .{ .binary = .{ .left = expr, .operator = operator, .right = right } };

            expr = node;
        }

        return expr;
    }

    fn primary(self: *Self) ParserError!*ast.Expr {
        if (self.match(&.{.number})) {
            const token = self.previous();
            const value = try std.fmt.parseFloat(f64, token.lexeme);

            const node = try self.allocator.create(ast.Expr);
            node.* = .{
                .number = value,
            };

            return node;
        }

        if (self.match(&.{.l_paren})) {
            const expr = try self.expression();
            _ = try self.consume(.r_paren);

            const node = try self.allocator.create(ast.Expr);
            node.* = .{
                .grouping = expr,
            };

            return node;
        }
        return ParserError.ExpectedExpression;
    }

    fn unary(self: *Self) ParserError!*ast.Expr {
        if (self.match(&.{ .plus, .minus })) {
            const operator = self.previous();
            const operand = try self.unary();

            const node = try self.allocator.create(ast.Expr);

            node.* = .{ .unary = .{
                .operator = operator,
                .operand = operand,
            } };
            return node;
        }
        return try self.primary();
    }

    fn isAtEnd(self: *const Self) bool {
        return self.peek().?.kind == .eof;
    }

    fn peek(self: *const Self) ?tokenizer.Token {
        return self.tokens[self.current];
    }

    fn previous(self: *const Self) tokenizer.Token {
        return self.tokens[self.current - 1];
    }

    fn advance(self: *Self) ?tokenizer.Token {
        if (self.isAtEnd()) return null;

        const token = self.tokens[self.current];
        self.current += 1;
        return token;
    }

    fn check(self: *const Self, kind: tokenizer.TokenKind) bool {
        if (self.isAtEnd()) return false;

        return self.peek().?.kind == kind;
    }

    fn match(self: *Self, kinds: []const tokenizer.TokenKind) bool {
        for (kinds) |kind| {
            if (self.check(kind)) {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    fn consume(self: *Self, kind: tokenizer.TokenKind) !tokenizer.Token {
        if (self.check(kind)) {
            return self.advance().?;
        }
        return ParserError.ExpectedRightParen;
    }
};

test "parse single number" {
    const allocator = std.testing.allocator;

    var tok = tokenizer.Tokenizer.init(allocator, "42");

    const tokens = try tok.tokenize();
    defer allocator.free(tokens);

    var parser = Parser.init(allocator, tokens);

    const expr = try parser.parse();
    defer expr.destroy(allocator);

    switch (expr.*) {
        .number => |value| {
            try std.testing.expectEqual(@as(f64, 42), value);
        },
        else => try std.testing.expect(false),
    }
}

test "parse unary minus" {
    const allocator = std.testing.allocator;

    var tok = tokenizer.Tokenizer.init(allocator, "-5");

    const tokens = try tok.tokenize();
    defer allocator.free(tokens);

    var parser = Parser.init(allocator, tokens);

    const expr = try parser.parse();
    defer expr.destroy(allocator);

    switch (expr.*) {
        .unary => |u| {
            try std.testing.expectEqual(tokenizer.TokenKind.minus, u.operator.kind);

            switch (u.operand.*) {
                .number => |value| {
                    try std.testing.expectEqual(@as(f64, 5), value);
                },
                else => try std.testing.expect(false),
            }
        },
        else => try std.testing.expect(false),
    }
}

test "parse multiplication" {
    const allocator = std.testing.allocator;

    var tok = tokenizer.Tokenizer.init(allocator, "2 * 3");

    const tokens = try tok.tokenize();
    defer allocator.free(tokens);

    var parser = Parser.init(allocator, tokens);

    const expr = try parser.parse();
    defer expr.destroy(allocator);

    switch (expr.*) {
        .binary => |b| {
            try std.testing.expectEqual(tokenizer.TokenKind.star, b.operator.kind);

            switch (b.left.*) {
                .number => |v| try std.testing.expectEqual(@as(f64, 2), v),
                else => try std.testing.expect(false),
            }

            switch (b.right.*) {
                .number => |v| try std.testing.expectEqual(@as(f64, 3), v),
                else => try std.testing.expect(false),
            }
        },
        else => try std.testing.expect(false),
    }
}

test "parse grouping" {
    const allocator = std.testing.allocator;

    var tok = tokenizer.Tokenizer.init(
        allocator,
        "(2 + 3)",
    );

    const tokens = try tok.tokenize();
    defer allocator.free(tokens);

    var parser = Parser.init(allocator, tokens);

    const expr = try parser.parse();
    defer expr.destroy(allocator);

    switch (expr.*) {
        .grouping => |inner| {
            switch (inner.*) {
                .binary => |b| {
                    try std.testing.expectEqual(
                        tokenizer.TokenKind.plus,
                        b.operator.kind,
                    );

                    switch (b.left.*) {
                        .number => |v| try std.testing.expectEqual(@as(f64, 2), v),
                        else => try std.testing.expect(false),
                    }

                    switch (b.right.*) {
                        .number => |v| try std.testing.expectEqual(@as(f64, 3), v),
                        else => try std.testing.expect(false),
                    }
                },
                else => try std.testing.expect(false),
            }
        },
        else => try std.testing.expect(false),
    }
}
