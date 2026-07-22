const std = @import("std");

pub const TokenizeError = error{
    InvalidCharacter,
};

pub const TokenKind = enum { number, plus, minus, star, slash, percent, l_paren, r_paren, eof };

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
};

pub const Tokenizer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    input: []const u8,
    index: usize = 0,

    /// **Initialize** a Tokenizer
    ///
    /// # Parameters
    /// - `allocator`: Memory allocator use for tokenizing
    /// - `input`: Expression to tokenize
    ///
    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return .{
            .allocator = allocator,
            .input = input,
        };
    }

    /// Tokenizes the *input string* into a slice of `Token`
    /// *Caller* owns returned memory and must *free* it using the same allocator.
    ///
    /// # Returns
    /// A slice of `Token` representing the lexical elements of the input.
    /// The slice ends with and `EOF` Token.
    ///
    /// # Errors
    /// Returns `Allocator.Error` if memory allocation fails.
    ///
    pub fn tokenize(self: *Self) ![]Token {
        var tokens = std.ArrayList(Token).empty;
        errdefer tokens.deinit(self.allocator);

        while (!self.isAtEnd()) {
            const character = self.peek().?;

            switch (character) {
                ' ', '\t', '\n' => {
                    _ = self.advance();
                },
                '+' => {
                    const start = self.index;
                    _ = self.advance();
                    try self.addToken(&tokens, .plus, start, self.index);
                },
                '-' => {
                    const start = self.index;
                    _ = self.advance();
                    try self.addToken(&tokens, .minus, start, self.index);
                },
                '*' => {
                    const start = self.index;
                    _ = self.advance();
                    try self.addToken(&tokens, .star, start, self.index);
                },
                '/' => {
                    const start = self.index;
                    _ = self.advance();
                    try self.addToken(&tokens, .slash, start, self.index);
                },
                '%' => {
                    const start = self.index;
                    _ = self.advance();
                    try self.addToken(&tokens, .percent, start, self.index);
                },
                '(' => {
                    const start = self.index;
                    _ = self.advance();
                    try self.addToken(&tokens, .l_paren, start, self.index);
                },
                ')' => {
                    const start = self.index;
                    _ = self.advance();
                    try self.addToken(&tokens, .r_paren, start, self.index);
                },

                '0'...'9' => {
                    const start = self.index;
                    while (self.peek()) |digit| {
                        if (!std.ascii.isDigit(digit)) {
                            break;
                        }
                        _ = self.advance();
                    }
                    try self.addToken(&tokens, .number, start, self.index);
                },
                else => return TokenizeError.InvalidCharacter,
            }
        }

        try tokens.append(self.allocator, Token{
            .kind = .eof,
            .lexeme = "",
        });

        return tokens.toOwnedSlice(self.allocator);
    }

    fn isAtEnd(self: *const Self) bool {
        return self.index >= self.input.len;
    }

    fn peek(self: *const Self) ?u8 {
        if (self.isAtEnd())
            return null;

        return self.input[self.index];
    }

    fn advance(self: *Self) ?u8 {
        if (self.isAtEnd())
            return null;

        const ch = self.input[self.index];
        self.index += 1;
        return ch;
    }

    fn addToken(self: *Self, tokens: *std.ArrayList(Token), kind: TokenKind, start: usize, end: usize) !void {
        try tokens.append(self.allocator, .{ .kind = kind, .lexeme = self.input[start..end] });
    }
};

test "tokenize simple expression" {
    const allocator = std.testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "12 + 34");

    const tokens = try tokenizer.tokenize();
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 4), tokens.len);

    try std.testing.expectEqual(TokenKind.number, tokens[0].kind);
    try std.testing.expectEqualStrings("12", tokens[0].lexeme);

    try std.testing.expectEqual(TokenKind.eof, tokens[3].kind);
    try std.testing.expectEqualStrings("", tokens[3].lexeme);
}

test "ignores whitespace" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(
        allocator,
        "   7    +     8   ",
    );

    const tokens = try tokenizer.tokenize();
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 4), tokens.len);

    try std.testing.expectEqualStrings("7", tokens[0].lexeme);
    try std.testing.expectEqualStrings("+", tokens[1].lexeme);
    try std.testing.expectEqualStrings("8", tokens[2].lexeme);
}

test "invalid character" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(
        allocator,
        "12 & 3",
    );

    try std.testing.expectError(
        TokenizeError.InvalidCharacter,
        tokenizer.tokenize(),
    );
}
