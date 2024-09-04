const std = @import("std");
const testing = std.testing;
const llvm = @import("llvm");

// ref: https://2π.com/10/brainfuck-using-llvm/
const Token = enum {
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

const NameJar = struct {
    i: u8,
    const Self = @This();
    fn init() Self {
        return Self{
            .i = 0,
        };
    }

    pub fn next(self: *Self) []const u8 {
        const name = std.fmt.digitToChar(self.i, .lower);
        self.i += 1;
        return &[_]u8{name};
    }
};

pub fn codegen(tokens: []Token) void {
    var nameJar = NameJar.init();
    const ctx = llvm.Context.create();
    defer ctx.deinit();
    const module = ctx.createModule("hello");
    defer module.deinit();
    const builder = ctx.createBuilder();
    defer builder.deinit();

    const int8 = ctx.int8Type();
    const int32 = ctx.int32Type();

    const one = llvm.Value.constInt(int8, 1, false);

    // define putchar function
    const putcharFunctionArgTypes = [_]llvm.Type{int32};
    const putcharFunctionType = llvm.Type.function(int32, &putcharFunctionArgTypes, 1, false);
    const putcharFunction = module.addFunction("putchar", putcharFunctionType);

    // define getchar function
    const getcharFunctionType = llvm.Type.function(int32, &[_]llvm.Type{}, 0, false);
    const getcharFunction = module.addFunction("getchar", getcharFunctionType);

    // define function for entrypoint
    const mainFunctionType = llvm.Type.function(int32, &[_]llvm.Type{}, 0, false);
    const mainFunction = module.addFunction("main", mainFunctionType);

    const code = ctx.appendBasicBlock(mainFunction, "code");
    builder.positionAtEnd(code);

    const head = builder.alloc(int8, "buffer");

    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        switch (tokens[i]) {
            Token.IncP => {
                const v = builder.add(head, one, nameJar.next());
                _ = builder.store(builder.add(v, one, nameJar.next()), head);
                // builder.store(builder.add(head, one), head);
            },
            Token.DecP => {
                unreachable;
                // builder.store(builder.sub(head, one), head);
            },
            Token.Inc => {
                const v = builder.load(int8, head, nameJar.next());
                _ = builder.store(builder.add(v, one, nameJar.next()), head);
            },
            Token.Dec => {
                const v = builder.load(int8, head, nameJar.next());
                _ = builder.store(builder.sub(v, one, nameJar.next()), head);
            },
            Token.Output => {
                const v = builder.load(int8, head, nameJar.next());
                const args = [_]llvm.Value{v};
                _ = builder.call2(putcharFunctionType, putcharFunction, &args, 1, nameJar.next());
            },
            Token.Input => {
                const v = builder.call2(getcharFunctionType, getcharFunction, &[_]llvm.Value{}, 0, nameJar.next());
                _ = builder.store(v, head);
            },
            Token.IfZeroJump => unreachable,
            Token.JumpTag => unreachable,
            Token.Null => unreachable,
        }
    }
    _ = builder.ret(llvm.Value.constInt(int32, 0, false));
    // end

    // module.dump(); // dump module to STDOUT
    _ = module.printToFile("./hello.ll");
}

pub fn lexer(src: []const u8, allocator: std.mem.Allocator) ![]Token {
    var tokens = try allocator.alloc(Token, src.len);
    errdefer allocator.free(tokens);

    var i: usize = 0;
    while (i < src.len) : (i += 1) {
        const token = try switch (src[i]) {
            '>' => Token.IncP,
            '<' => Token.DecP,
            '+' => Token.Inc,
            '-' => Token.Dec,
            '.' => Token.Output,
            ',' => Token.Input,
            '[' => Token.IfZeroJump,
            ']' => Token.JumpTag,
            else => error.Unexpected,
        };
        tokens[i] = token;
    }
    return tokens;
}

test "lexer" {
    const src = "[->+<]";
    const tokens = try lexer(src, testing.allocator);
    defer testing.allocator.free(tokens);
    try testing.expectEqualSlices(Token, tokens, &[_]Token{
        Token.IfZeroJump,
        Token.Dec,
        Token.IncP,
        Token.Inc,
        Token.DecP,
        Token.JumpTag,
    });
}

test "codegen" {
    const src = "++++++++++++++++++++++++.";
    const tokens = try lexer(src, std.testing.allocator);
    defer testing.allocator.free(tokens);
    _ = codegen(tokens);
}

export fn brainfxck() i32 {
    return 1;
}
