const std = @import("std");
const testing = std.testing;
const llvm = @import("llvm");
const Token = @import("./token.zig").Token;
const Function = @import("./llvm-util.zig").Function;

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

    // define function
    const incrementPtr = self.defineFnIncrementPtr();
    self.globalFunctions.put("incPtr", incrementPtr) catch @panic("todo");

    const decrementPtr = self.defineFnDecrementPtr();
    self.globalFunctions.put("decPtr", decrementPtr) catch @panic("todo");

    const increment = self.defineFnIncrement();
    self.globalFunctions.put("inc", increment) catch @panic("todo");

    const decrement = self.defineFnDecrement();
    self.globalFunctions.put("dec", decrement) catch @panic("todo");

    const output = self.defineFnOutput();
    self.globalFunctions.put("output", output) catch @panic("todo");

    const input = self.defineFnInput();
    self.globalFunctions.put("input", input) catch @panic("todo");

    return self;
}

fn defineFnIncrementPtr(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        self.ctx.int32Type().ptr(32),
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
        self.ctx.int32Type().ptr(32),
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
        llvm.Type.array(self.ctx.int8Type(), 255).ptr(8),
        self.ctx.int32Type().ptr(8),
    }, 2, false);
    const function = self.module.addFunction("inc", functionType);

    const code = self.ctx.appendBasicBlock(function, "inc");
    self.builder.positionAtEnd(code);

    const ptr = function.getParam(0);
    const index = function.getParam(1);

    const offset = self.builder.load(self.ctx.int32Type(), index, "index");
    const valuePtr = self.builder.gep(self.ctx.int8Type(), ptr, &[_]llvm.Value{offset}, 1, "valuePtr");

    const one = llvm.Value.constInt(self.ctx.int8Type(), 1, false);

    const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
    _ = self.builder.store(self.builder.add(v, one, "_"), valuePtr);
    _ = self.builder.retVoid();

    return Function.init(functionType, function);
}

fn defineFnDecrement(self: *Self) Function {
    const functionType = llvm.Type.function(self.ctx.voidType(), &[_]llvm.Type{
        llvm.Type.array(self.ctx.int8Type(), 255).ptr(8),
        self.ctx.int32Type().ptr(8),
    }, 2, false);
    const function = self.module.addFunction("dec", functionType);

    const code = self.ctx.appendBasicBlock(function, "dec");
    self.builder.positionAtEnd(code);

    const ptr = function.getParam(0);
    const index = function.getParam(1);

    const offset = self.builder.load(self.ctx.int32Type(), index, "index");
    const valuePtr = self.builder.gep(self.ctx.int8Type(), ptr, &[_]llvm.Value{offset}, 1, "valuePtr");

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
        llvm.Type.array(self.ctx.int8Type(), 255).ptr(8),
        self.ctx.int32Type().ptr(8),
    }, 2, false);
    const function = self.module.addFunction("input", functionType);

    const code = self.ctx.appendBasicBlock(function, "input");
    self.builder.positionAtEnd(code);

    const ptr = function.getParam(0);
    const index = function.getParam(1);

    const offset = self.builder.load(self.ctx.int32Type(), index, "index");
    const valuePtr = self.builder.gep(self.ctx.int8Type(), ptr, &[_]llvm.Value{offset}, 1, "valuePtr");

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

fn innerCodegen(self: Self, mainFun: llvm.Value, beforeBlock: llvm.BasicBlock, tokens: []Token, i: usize) usize {
    var index = i;
    while (index < tokens.len) : (index += 1) {
        switch (tokens[index]) {
            Token.IncP => {
                const fun = self.globalFunctions.get("incPtr") orelse unreachable;
                _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
                    self.globalVariables.get("index") orelse unreachable,
                }, 1, "");
            },
            Token.DecP => {
                const fun = self.globalFunctions.get("decPtr") orelse unreachable;
                _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
                    self.globalVariables.get("index") orelse unreachable,
                }, 1, "");
            },
            Token.Inc => {
                const fun = self.globalFunctions.get("inc") orelse unreachable;
                _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
                    self.globalVariables.get("ptr") orelse unreachable,
                    self.globalVariables.get("index") orelse unreachable,
                }, 2, "");
            },
            Token.Dec => {
                const fun = self.globalFunctions.get("dec") orelse unreachable;
                _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
                    self.globalVariables.get("ptr") orelse unreachable,
                    self.globalVariables.get("index") orelse unreachable,
                }, 2, "");
            },
            Token.Output => {
                const indexPtr = self.globalVariables.get("index") orelse unreachable;
                const indexValue = self.builder.load(self.ctx.int32Type(), indexPtr, "indexPtr");
                const arrayPtr = self.globalVariables.get("ptr") orelse unreachable;
                const valuePtr = self.builder.gep(self.ctx.int8Type(), arrayPtr, &[_]llvm.Value{indexValue}, 1, "valuePtr");
                const v = self.builder.load(self.ctx.int8Type(), valuePtr, "value");
                const fun = self.globalFunctions.get("output") orelse unreachable;
                _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{v}, 1, "");
            },
            Token.Input => {
                const fun = self.globalFunctions.get("input") orelse unreachable;
                _ = self.builder.call2(fun.fnType, fun.fnValue, &[_]llvm.Value{
                    self.globalVariables.get("ptr") orelse unreachable,
                    self.globalVariables.get("index") orelse unreachable,
                }, 2, "");
            },
            Token.JumpTag => {
                const inner = self.ctx.appendBasicBlock(mainFun, "code");
                _ = self.builder.br(inner);
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

                self.builder.positionAtEnd(afterBlock);
            },
            Token.Null => unreachable,
        }
    }
    return index;
}

pub fn codegen(self: *Self, tokens: []Token) void {
    // define function for entrypoint
    const mainFunctionType = llvm.Type.function(self.ctx.int32Type(), &[_]llvm.Type{}, 0, false);
    const mainFunction = self.module.addFunction("main", mainFunctionType);

    // main function
    const code = self.ctx.appendBasicBlock(mainFunction, "code");
    self.builder.positionAtEnd(code);

    // global list
    const ptr = self.builder.alloc(llvm.Type.array(self.ctx.int8Type(), 255), "buffer");
    const index = self.builder.alloc(self.ctx.int32Type(), "index");
    self.globalVariables.put("ptr", ptr) catch @panic("todo");
    self.globalVariables.put("index", index) catch @panic("todo");

    // zero padding
    _ = self.builder.store(llvm.Value.constInt(self.ctx.intType(8 * 255), 0, false), ptr);

    _ = self.innerCodegen(mainFunction, code, tokens, 0);
    _ = self.builder.ret(llvm.Value.constInt(self.ctx.int32Type(), 0, false));
    // end

    // self.module.dump(); // dump module to STDOUT
    _ = self.module.printToFile("./hello.ll");
}
