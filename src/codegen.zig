const std = @import("std");
const testing = std.testing;
const llvm = @import("llvm");
const Token = @import("./token.zig").Token;
const Function = @import("./w.zig").Function;

const Functions = std.StringHashMap(Function);
const Variables = std.StringHashMap(llvm.Value);

globalFunctions: Functions,
globalVariables: Variables,
ctx: llvm.Context,
module: llvm.Module,
builder: llvm.Builder,

const Self = @This();
pub fn init(alloc: std.mem.Allocator) Self {
    const ctx = llvm.Context.create();
    const module = ctx.createModule("main");
    const builder = ctx.createBuilder();
    var globalFunctions = Functions.init(alloc);
    var globalVariables = Variables.init(alloc);

    // define putchar function
    const putcharFunctionArgTypes = [_]llvm.Type{ctx.int32Type()};
    const putcharFunctionType = llvm.Type.function(ctx.int32Type(), &putcharFunctionArgTypes, 1, false);
    const putcharFunction = module.addFunction("putchar", putcharFunctionType);

    // define getchar function
    const getcharFunctionType = llvm.Type.function(ctx.int32Type(), &[_]llvm.Type{}, 0, false);
    const getcharFunction = module.addFunction("getchar", getcharFunctionType);

    globalFunctions.put("getchar", Function.init(putcharFunctionType, putcharFunction)) catch @panic("todo");
    globalFunctions.put("putchar", Function.init(getcharFunctionType, getcharFunction)) catch @panic("todo");

    // global list
    const ptr = builder.alloc(llvm.Type.array(ctx.int8Type(), 255), "buffer");
    const index = builder.alloc(ctx.int32Type(), "index");
    globalVariables.put("ptr", ptr) catch @panic("todo");
    globalVariables.put("index", index) catch @panic("todo");

    return Self{
        .globalFunctions = globalFunctions,
        .globalVariables = globalVariables,
        .ctx = ctx,
        .module = module,
        .builder = builder,
    };
}

pub fn deinit(self: *Self) void {
    defer self.ctx.deinit();
    defer self.module.deinit();
    defer self.builder.deinit();
    defer self.globalVariables.deinit();
    defer self.globalFunctions.deinit();
}

fn incrementPtr(self: Self) void {
    const ptr = self.globalVariables.get("index") orelse unreachable;
    const value = self.builder.load(self.ctx.int32Type(), ptr, "ptr");

    const one = llvm.Value.constInt(self.ctx.int32Type(), 1, false);

    _ = self.builder.store(self.builder.add(value, one, "_"), ptr);
}

fn decrementPtr(self: Self) void {
    const ptr = self.globalVariables.get("index") orelse unreachable;
    const value = self.builder.load(self.ctx.int32Type(), ptr, "ptr");

    const one = llvm.Value.constInt(self.ctx.int32Type(), 1, false);

    _ = self.builder.store(self.builder.sub(value, one, "_"), ptr);
}

fn increment(self: Self) void {
    const indexPtr = self.globalVariables.get("index") orelse unreachable;
    const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

    const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
    const valuePtr = self.builder.gep(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

    const one = llvm.Value.constInt(self.ctx.int8Type(), 1, false);

    const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
    _ = self.builder.store(self.builder.add(v, one, "_"), valuePtr);
}

fn decrement(self: Self) void {
    const indexPtr = self.globalVariables.get("index") orelse unreachable;
    const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

    const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
    const valuePtr = self.builder.gep(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

    const one = llvm.Value.constInt(self.ctx.int8Type(), 1, false);

    const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
    _ = self.builder.store(self.builder.sub(v, one, "_"), valuePtr);
}

fn input(self: Self) void {
    const fun = self.globalFunctions.get("getchar") orelse unreachable;
    const v = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{}, 0, "tmp");

    const indexPtr = self.globalVariables.get("index") orelse unreachable;
    const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

    const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
    const valuePtr = self.builder.gep(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

    _ = self.builder.store(v, valuePtr);
}

fn output(self: Self) void {
    const fun = self.globalFunctions.get("putchar") orelse unreachable;
    const indexPtr = self.globalVariables.get("index") orelse unreachable;
    const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

    const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
    const valuePtr = self.builder.gep(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

    const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
    const args = [_]llvm.Value{v};
    _ = self.builder.call2(fun.fnType, fun.fnValue, &args, 1, "tmp");
}

fn innerCodegen(self: Self, mainFun: llvm.Value, beforeBlock: llvm.BasicBlock, tokens: []Token, i: usize) usize {
    var index = i;
    while (index < tokens.len) : (index += 1) {
        switch (tokens[index]) {
            Token.IncP => self.incrementPtr(),
            Token.DecP => self.decrementPtr(),
            Token.Inc => self.increment(),
            Token.Dec => self.decrement(),
            Token.Output => self.output(),
            Token.Input => self.input(),
            Token.JumpTag => {
                const inner = self.ctx.appendBasicBlock(mainFun, "code");
                self.builder.positionAtEnd(inner);
                index = self.innerCodegen(mainFun, inner, tokens, index + 1);
            },
            Token.IfZeroJump => {
                const indexPtr = self.globalVariables.get("index") orelse unreachable;
                const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

                const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
                const valuePtr = self.builder.gep(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

                const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");

                const zero = llvm.Value.constInt(self.ctx.int8Type(), 0, false);
                const flag = self.builder.cmp(llvm.CompareOperator.EQ, v, zero, "flag");

                const afterBlock = self.ctx.appendBasicBlock(mainFun, "outer");
                _ = self.builder.condBr(flag, afterBlock, beforeBlock);
            },
            Token.Null => unreachable,
        }
    }
    return index;
}

pub fn codegen(self: Self, tokens: []Token) void {
    // define function for entrypoint
    const mainFunctionType = llvm.Type.function(self.ctx.int32Type(), &[_]llvm.Type{}, 0, false);
    const mainFunction = self.module.addFunction("main", mainFunctionType);

    // main function
    const code = self.ctx.appendBasicBlock(mainFunction, "code");
    self.builder.positionAtEnd(code);
    _ = self.innerCodegen(mainFunction, code, tokens, 0);
    _ = self.builder.ret(llvm.Value.constInt(self.ctx.int32Type(), 0, false));
    // end

    // module.dump(); // dump module to STDOUT
    _ = self.module.printToFile("./hello.ll");
}
