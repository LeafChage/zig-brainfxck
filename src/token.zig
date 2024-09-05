const std = @import("std");
const testing = std.testing;

// ref: https://2π.com/10/brainfuck-using-llvm/
pub const Token = enum {
    IncP, // >
    DecP, // <
    Inc, // +
    Dec, // -
    Output, // .
    Input, // ,
    IfZeroJump, // [
    JumpTag, // ]
    Null,
};

pub fn lexer(src: []const u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();

    for (src) |c| {
        const token = switch (c) {
            '>' => Token.IncP,
            '<' => Token.DecP,
            '+' => Token.Inc,
            '-' => Token.Dec,
            '.' => Token.Output,
            ',' => Token.Input,
            '[' => Token.JumpTag,
            ']' => Token.IfZeroJump,
            else => {
                continue;
            },
        };
        try tokens.append(token);
    }
    return tokens;
}

test "lexer" {
    const src = "[->+< ]";
    const tokens = try lexer(src, testing.allocator);
    defer tokens.deinit();
    try testing.expectEqualSlices(Token, tokens.items, &[_]Token{
        Token.JumpTag,
        Token.Dec,
        Token.IncP,
        Token.Inc,
        Token.DecP,
        Token.IfZeroJump,
    });
}
