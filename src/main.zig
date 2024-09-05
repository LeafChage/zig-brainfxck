const std = @import("std");
const llvm = @import("llvm");
const brainfxck = @import("root.zig");

pub fn main() !void {
    // const context = llvm.Context.create();
    // defer context.deinit();
    // const module = llvm.Module.createWithNameInContext("hello", context);
    // defer module.deinit();
    // const builder = llvm.Builder.createInContext(context);
    // defer builder.deinit();
    //
    // const int32Type = context.int32Type();
    //
    // const putsFunctionArgTypes = [_]llvm.Type{int32Type};
    // const putsFunctionType = llvm.Type.functionType(int32Type, &putsFunctionArgTypes, 1, false);
    // const putsFunction = module.addFunction("putchar", putsFunctionType);
    // // end
    //
    // // main function
    // const mainFunctionType = llvm.Type.functionType(int32Type, &[_]llvm.Type{}, 0, false);
    // const mainFunction = module.addFunction("main", mainFunctionType);
    //
    // const entry = context.appendBasicBlockInContext(mainFunction, "entry");
    // builder.positionBuilderAtEnd(entry);
    //
    // const putsFunctionArgs = [_]llvm.Value{llvm.Value.constInt(int32Type, 'H', false)};
    //
    // _ = builder.call2(putsFunctionType, putsFunction, &putsFunctionArgs, putsFunctionArgs.len, "1");
    // _ = builder.ret(llvm.Value.constInt(int32Type, 0, false));
    // // end
    //
    // // module.dump(); // dump module to STDOUT
    // _ = module.printToFile("hello.ll", undefined);
    const src =
        \\ ++++++++++
        \\ ++++++++++
        \\ ++++++++++
        \\ ++++++++++
        \\ ++++++++++
        \\ ++++++++++
        \\ +++++.
        \\ +.
        \\ +.
        \\ +.
        \\ +.
    ;
    const tokens = try brainfxck.lexer(src, std.heap.page_allocator);
    defer tokens.deinit();
    _ = brainfxck.codegen(tokens.items);
}
