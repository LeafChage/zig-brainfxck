const std = @import("std");
const wllvm = @import("./wrapped-llvm.zig");
const raw = @import("./import.zig");

pub const ArrayCastAllocator = @import("./allocator.zig").ArrayCastAllocator;

const function = @import("./function.zig");
pub const FunctionMeta = function.FunctionMeta;
pub const Function = function.Function;
pub const Type = @import("./type.zig").Type;
pub const Module = @import("./module.zig").Module;
pub const ExecuteEngine = @import("./execute-engine.zig").ExecuteEngine;
pub const Context = wllvm.Context;
pub const Value = wllvm.Value;
pub const CompareOperator = wllvm.CompareOperator;
pub const Builder = wllvm.Builder;
pub const BasicBlock = wllvm.BasicBlock;

pub fn initializeNativeTarget() bool {
    return raw.LLVMInitializeNativeTarget() == 1;
}
pub fn initializeNativeAsmPrinter() bool {
    return raw.LLVMInitializeNativeAsmPrinter() == 1;
}

pub fn initializeNativeAsmParser() bool {
    return raw.LLVMInitializeNativeAsmParser() == 1;
}

test "jit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    ArrayCastAllocator.init(arena.allocator());

    defer arena.deinit();

    const ctx = wllvm.Context.create();
    defer ctx.deinit();
    const module = ctx.createModule("hello");
    defer module.deinit();
    const builder = ctx.createBuilder();
    defer builder.deinit();

    const int8 = ctx.int8Type();
    const int8Ptr = int8.ptr();
    const int32 = ctx.int32Type();

    const putsFunction = module.addFunction(FunctionMeta.puts(ctx));
    const mainFunction = module.addFunction(FunctionMeta.main(ctx));

    const entry = ctx.appendBasicBlock(mainFunction, "entry");
    builder.positionAtEnd(entry);

    const putsFunctionArg = [_]wllvm.Value{builder.pointerCast(builder.globalString("Hello, World!", "hello"), int8Ptr, "0")};
    _ = builder.call2(putsFunction, &putsFunctionArg, 1, "i");
    _ = builder.ret(wllvm.Value.constInt(int32, 0, false));

    _ = initializeNativeTarget();
    _ = initializeNativeAsmPrinter();
    _ = initializeNativeAsmParser();

    const engine = try ExecuteEngine.createForModule(module);
    _ = engine.runMainFunction(mainFunction);
    // end

}
//
// test "hello world" {
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     ArrayCastAllocator.init(arena.allocator());
//
//     defer arena.deinit();
//
//     const ctx = wllvm.Context.create();
//     defer ctx.deinit();
//     const module = ctx.createModule("hello");
//     defer module.deinit();
//     const builder = ctx.createBuilder();
//     defer builder.deinit();
//
//     const int8 = ctx.int8Type();
//     const int8Ptr = int8.ptr(0);
//     const int32 = ctx.int32Type();
//
//     const putsFunction = module.addFunction(FunctionMeta.puts(ctx));
//     const mainFunction = module.addFunction(FunctionMeta.main(ctx));
//
//     const entry = ctx.appendBasicBlock(mainFunction, "entry");
//     builder.positionAtEnd(entry);
//
//     const putsFunctionArg = [_]wllvm.Value{builder.pointerCast(builder.globalString("Hello, World!", "hello"), int8Ptr, "0")};
//     _ = builder.call2(putsFunction, &putsFunctionArg, 1, "i");
//     _ = builder.ret(wllvm.Value.constInt(int32, 0, false));
//     // end
//
//     // module.dump();// dump module to STDOUT
//     _ = module.printToFile("hello.ll");
// }
