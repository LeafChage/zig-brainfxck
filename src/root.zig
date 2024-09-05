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

pub fn codegen(tokens: []Token) void {
    // var nameJar = NameJar.init();
    const ctx = llvm.Context.create();
    defer ctx.deinit();
    const module = ctx.createModule("hello");
    defer module.deinit();
    const builder = ctx.createBuilder();
    defer builder.deinit();

    const int8 = ctx.int8Type();
    const int32 = ctx.int32Type();

    const oneInt8 = llvm.Value.constInt(int8, 1, false);
    const oneInt32 = llvm.Value.constInt(int32, 1, false);

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

    const arrayType = llvm.Type.array(int8, 255);
    const head = builder.alloc(arrayType, "buffer");
    const index = builder.alloc(int32, "index");

    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        switch (tokens[i]) {
            Token.IncP => {
                const t = builder.load(int32, index, "ti");
                _ = builder.store(builder.add(t, oneInt32, "p"), index);
            },
            Token.DecP => {
                const t = builder.load(int32, index, "ti");
                _ = builder.store(builder.sub(t, oneInt32, "p"), index);
            },
            Token.Inc => {
                const ti = builder.load(int32, index, "ti");
                const vp = builder.gep(int8, head, &[_]llvm.Value{ti}, 1, "ti");
                const v = builder.load(int8, vp, "ti");
                _ = builder.store(builder.add(v, oneInt8, "ti"), vp);
            },
            Token.Dec => {
                const ti = builder.load(int32, index, "ti");
                const vp = builder.gep(int8, head, &[_]llvm.Value{ti}, 1, "ti");
                const v = builder.load(int8, vp, "ti");
                _ = builder.store(builder.sub(v, oneInt8, "ti"), vp);
            },
            Token.Output => {
                const ti = builder.load(int32, index, "ti");
                const vp = builder.gep(int8, head, &[_]llvm.Value{ti}, 1, "ti");
                const v = builder.load(int8, vp, "ti");
                const args = [_]llvm.Value{v};
                _ = builder.call2(putcharFunctionType, putcharFunction, &args, 1, "tmp");
            },
            Token.Input => {
                const v = builder.call2(getcharFunctionType, getcharFunction, &[_]llvm.Value{}, 0, "tmp");
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
            '[' => Token.IfZeroJump,
            ']' => Token.JumpTag,
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
        Token.IfZeroJump,
        Token.Dec,
        Token.IncP,
        Token.Inc,
        Token.DecP,
        Token.JumpTag,
    });
}

export fn brainfxck() i32 {
    return 1;
}
