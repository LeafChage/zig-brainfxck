const std = @import("std");
const testing = std.testing;
const llvm = @import("llvm");
const Token = @import("./token.zig").Token;
const Function = @import("./llvm-util.zig").Function;

const ArraySize = 30000;

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

    var self = Self{
        .globalFunctions = Functions.init(alloc),
        .globalVariables = Variables.init(alloc),
        .ctx = ctx,
        .module = module,
        .builder = builder,
    };

    // define putchar function
    const putcharFunctionArgTypes = [_]llvm.Type{self.ctx.int32Type()};
    const putcharFunctionType = llvm.Type.function(self.ctx.int32Type(), &putcharFunctionArgTypes, 1, false);
    const putcharFunction = self.module.addFunction("putchar", putcharFunctionType);
    self.globalFunctions.put("putchar", Function.init(putcharFunctionType, putcharFunction)) catch @panic("todo");

    // define getchar function
    const getcharFunctionType = llvm.Type.function(self.ctx.int32Type(), &[_]llvm.Type{}, 0, false);
    const getcharFunction = self.module.addFunction("getchar", getcharFunctionType);
    self.globalFunctions.put("getchar", Function.init(getcharFunctionType, getcharFunction)) catch @panic("todo");

    // define printf
    const printfFunctionType = llvm.Type.function(self.ctx.int32Type(), &[_]llvm.Type{self.ctx.ptrType(8)}, 1, true);
    const printfFunction = self.module.addFunction("printf", printfFunctionType);
    self.globalFunctions.put("printf", Function.init(printfFunctionType, printfFunction)) catch @panic("todo");

    // define function
    self.globalFunctions.put("incPtr", self.defineFnIncrementPtr()) catch @panic("todo");
    self.globalFunctions.put("decPtr", self.defineFnDecrementPtr()) catch @panic("todo");
    self.globalFunctions.put("inc", self.defineFnIncrement()) catch @panic("todo");
    self.globalFunctions.put("dec", self.defineFnDecrement()) catch @panic("todo");
    self.globalFunctions.put("output", self.defineFnOutput()) catch @panic("todo");
    self.globalFunctions.put("input", self.defineFnInput()) catch @panic("todo");

    return self;
}

fn defineFnIncrementPtr(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        self.ctx.ptrType(32),
    }, 1, false);
    const function = self.module.addFunction("incPtr", functionType);

    const code = self.ctx.appendBasicBlock(function, "incPtr");
    self.builder.positionAtEnd(code);

    const index = function.getParam(0);
    const value = self.builder.load(self.ctx.int32Type(), index, "index");
    const one = llvm.Value.constInt(self.ctx.int32Type(), 1, false);
    _ = self.builder.store(self.builder.add(value, one, "_"), index);
    _ = self.builder.retVoid();

    return Function.init(functionType, function);
}

fn defineFnDecrementPtr(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        self.ctx.ptrType(32),
    }, 1, false);
    const function = self.module.addFunction("decPtr", functionType);

    const code = self.ctx.appendBasicBlock(function, "decPtr");
    self.builder.positionAtEnd(code);

    const index = function.getParam(0);
    const value = self.builder.load(self.ctx.int32Type(), index, "index");
    const one = llvm.Value.constInt(self.ctx.int32Type(), 1, false);
    _ = self.builder.store(self.builder.sub(value, one, "_"), index);
    _ = self.builder.retVoid();

    return Function.init(functionType, function);
}

fn defineFnIncrement(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        self.ctx.ptrType(8),
        self.ctx.ptrType(32),
    }, 2, false);
    const function = self.module.addFunction("inc", functionType);

    const code = self.ctx.appendBasicBlock(function, "inc");
    self.builder.positionAtEnd(code);

    const ptr = function.getParam(0);
    const index = function.getParam(1);

    const offset = self.builder.load(self.ctx.int32Type(), index, "index");
    const valuePtr = self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{offset}, 1, "valuePtr");

    const one = llvm.Value.constInt(self.ctx.int8Type(), 1, false);

    const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
    _ = self.builder.store(self.builder.add(v, one, "_"), valuePtr);
    _ = self.builder.retVoid();

    return Function.init(functionType, function);
}

fn defineFnDecrement(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        self.ctx.ptrType(8),
        self.ctx.ptrType(32),
    }, 2, false);
    const function = self.module.addFunction("dec", functionType);

    const code = self.ctx.appendBasicBlock(function, "dec");
    self.builder.positionAtEnd(code);

    const ptr = function.getParam(0);
    const index = function.getParam(1);

    const offset = self.builder.load(self.ctx.int32Type(), index, "index");
    const valuePtr = self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{offset}, 1, "valuePtr");
    const one = llvm.Value.constInt(self.ctx.int8Type(), 1, false);

    const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
    _ = self.builder.store(self.builder.sub(v, one, "_"), valuePtr);
    _ = self.builder.retVoid();

    return Function.init(functionType, function);
}

fn defineFnOutput(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        self.ctx.int32Type(),
    }, 1, false);
    const function = self.module.addFunction("output", functionType);

    const code = self.ctx.appendBasicBlock(function, "output");
    self.builder.positionAtEnd(code);

    const v = function.getParam(0);
    const fun = self.globalFunctions.get("putchar") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{v}, 1, "tmp");
    _ = self.builder.retVoid();

    return Function.init(functionType, function);
}

fn defineFnInput(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        self.ctx.ptrType(8),
        self.ctx.ptrType(32),
    }, 2, false);
    const function = self.module.addFunction("input", functionType);

    const code = self.ctx.appendBasicBlock(function, "input");
    self.builder.positionAtEnd(code);

    const ptr = function.getParam(0);
    const index = function.getParam(1);

    const offset = self.builder.load(self.ctx.int32Type(), index, "index");
    const valuePtr = self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{offset}, 1, "valuePtr");

    const fun = self.globalFunctions.get("getchar") orelse unreachable;
    const v = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{}, 0, "rtuGetchar");

    _ = self.builder.store(v, valuePtr);
    _ = self.builder.retVoid();

    return Function.init(functionType, function);
}

pub fn deinit(self: *Self) void {
    defer self.ctx.deinit();
    defer self.module.deinit();
    defer self.builder.deinit();
    defer self.globalVariables.deinit();
    defer self.globalFunctions.deinit();
}

fn incp(self: Self) void {
    const fun = self.globalFunctions.get("incPtr") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
        self.globalVariables.get("index") orelse unreachable,
    }, 1, "");
}

fn decp(self: Self) void {
    const fun = self.globalFunctions.get("decPtr") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
        self.globalVariables.get("index") orelse unreachable,
    }, 1, "");
}

fn inc(self: Self) void {
    const fun = self.globalFunctions.get("inc") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
        self.globalVariables.get("ptr") orelse unreachable,
        self.globalVariables.get("index") orelse unreachable,
    }, 2, "");
}

fn dec(self: Self) void {
    const fun = self.globalFunctions.get("dec") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
        self.globalVariables.get("ptr") orelse unreachable,
        self.globalVariables.get("index") orelse unreachable,
    }, 2, "");
}

fn output(self: Self) void {
    const indexPtr = self.globalVariables.get("index") orelse unreachable;
    const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");
    const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
    const valuePtr = self.builder.gepInbounds(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");
    const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
    const fun = self.globalFunctions.get("output") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{v}, 1, "");
}
fn input(self: Self) void {
    const fun = self.globalFunctions.get("input") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
        self.globalVariables.get("ptr") orelse unreachable,
        self.globalVariables.get("index") orelse unreachable,
    }, 2, "");
}

fn innerBlockCodegen(self: Self, mainFun: llvm.Value, currentBlock: llvm.BasicBlock, afterBlock: llvm.BasicBlock, tokens: []Token, i: usize) usize {
    var index = i;
    while (index < tokens.len) : (index += 1) {
        // self.dump();
        switch (tokens[index]) {
            Token.IncP => self.incp(),
            Token.DecP => self.decp(),
            Token.Inc => self.inc(),
            Token.Dec => self.dec(),
            Token.Output => self.output(),
            Token.Input => self.input(),
            Token.JumpTag => {
                const loopBlock = self.ctx.appendBasicBlock(mainFun, "loop.inner");
                const fallthrough = self.ctx.appendBasicBlock(mainFun, "loop.fallthrough");

                const indexPtr = self.globalVariables.get("index") orelse unreachable;
                const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

                const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
                const valuePtr = self.builder.gepInbounds(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

                const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");

                const zero = llvm.Value.constInt(self.ctx.int8Type(), 0, false);
                const flag = self.builder.cmp(llvm.CompareOperator.EQ, v, zero, "flag");

                _ = self.builder.condBr(flag, fallthrough, loopBlock);

                self.builder.positionAtEnd(loopBlock);
                index = self.innerBlockCodegen(mainFun, loopBlock, fallthrough, tokens, index + 1);

                self.builder.positionAtEnd(fallthrough);
            },
            Token.IfZeroJump => {
                const indexPtr = self.globalVariables.get("index") orelse unreachable;
                const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

                const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
                const valuePtr = self.builder.gepInbounds(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

                const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");

                const zero = llvm.Value.constInt(self.ctx.int8Type(), 0, false);
                const flag = self.builder.cmp(llvm.CompareOperator.EQ, v, zero, "flag");

                _ = self.builder.condBr(flag, afterBlock, currentBlock);
                return index;
            },
            Token.Null => unreachable,
        }
    }
    return index;
}

fn innerCodegen(self: Self, mainFun: llvm.Value, tokens: []Token, i: usize) usize {
    var index = i;
    while (index < tokens.len) : (index += 1) {
        // self.dump();
        switch (tokens[index]) {
            Token.IncP => self.incp(),
            Token.DecP => self.decp(),
            Token.Inc => self.inc(),
            Token.Dec => self.dec(),
            Token.Output => self.output(),
            Token.Input => self.input(),
            Token.JumpTag => {
                const loopBlock = self.ctx.appendBasicBlock(mainFun, "loop.inner");
                const fallthrough = self.ctx.appendBasicBlock(mainFun, "loop.fallthrough");

                const indexPtr = self.globalVariables.get("index") orelse unreachable;
                const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");

                const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
                const valuePtr = self.builder.gepInbounds(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");

                const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");

                const zero = llvm.Value.constInt(self.ctx.int8Type(), 0, false);
                const flag = self.builder.cmp(llvm.CompareOperator.EQ, v, zero, "flag");

                _ = self.builder.condBr(flag, fallthrough, loopBlock);

                self.builder.positionAtEnd(loopBlock);
                index = self.innerBlockCodegen(mainFun, loopBlock, fallthrough, tokens, index + 1);

                self.builder.positionAtEnd(fallthrough);
            },
            Token.IfZeroJump => unreachable,
            Token.Null => unreachable,
        }
    }
    return index;
}

fn debugPrint(self: Self, fmt: []const u8, v: llvm.Value) void {
    const fun = self.globalFunctions.get("printf") orelse unreachable;
    _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
        self.builder.pointerCast(self.builder.globalString(fmt, "_"), self.ctx.ptrType(8), "_"),
        v,
    }, 2, "tmp");
}

fn dump(self: Self) void {
    const fun = self.globalFunctions.get("printf") orelse unreachable;

    const offsetPtr = self.globalVariables.get("index") orelse unreachable;
    const ptr = self.globalVariables.get("ptr") orelse unreachable;
    const fmt = "head: %ld, offset: %d, index: %ld [ %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x] \n";
    const offset = self.builder.load(self.ctx.int32Type(), offsetPtr, "offset");
    const args = [_]llvm.Value{
        self.builder.pointerCast(self.builder.globalString(fmt, "_"), self.ctx.ptrType(8), "_"),
        ptr,
        offset,
        self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{offset}, 1, "i"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 0, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 1, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 2, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 3, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 4, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 5, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 6, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 7, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 8, false)}, 1, "i"), "_"),
        self.builder.load(self.ctx.int8Type(), self.builder.gepInbounds(self.ctx.int8Type(), ptr, &[_]llvm.Value{llvm.Value.constInt(self.ctx.int32Type(), 8, false)}, 1, "i"), "_"),
    };
    _ = self.builder.call2(fun.fnType, fun.fnValue, &args, args.len, "tmp");
}

pub fn codegen(self: *Self, tokens: []Token) void {
    // define function for entrypoint
    const mainFunctionType = llvm.Type.function(self.ctx.int32Type(), &[_]llvm.Type{}, 0, false);
    const mainFunction = self.module.addFunction("main", mainFunctionType);

    // main function
    const code = self.ctx.appendBasicBlock(mainFunction, "code");
    self.builder.positionAtEnd(code);

    // global list
    const ptr = self.builder.arrayMalloc(
        llvm.Type.array(self.ctx.int8Type(), ArraySize),
        llvm.Value.constInt(self.ctx.int32Type(), ArraySize, false),
        "buffer",
    );
    const index = self.builder.alloca(self.ctx.int32Type(), "index");

    self.globalVariables.put("ptr", ptr) catch @panic("todo");
    self.globalVariables.put("index", index) catch @panic("todo");

    // zero padding
    _ = self.builder.store(llvm.Value.constInt(self.ctx.intType(8 * ArraySize), 0, false), ptr);
    _ = self.builder.store(llvm.Value.constInt(self.ctx.intType(32), 0, false), index);
    _ = self.innerCodegen(mainFunction, tokens, 0);

    _ = self.builder.free(ptr);
    _ = self.builder.ret(llvm.Value.constInt(self.ctx.int32Type(), 0, false));
    // end

    _ = self.module.printToFile("./a.ll");
}
