const std = @import("std");
const llvm = @cImport({
    @cInclude("llvm-c/Core.h");
    @cInclude("llvm-c/Analysis.h");
    @cInclude("llvm-c/BitReader.h");
    @cInclude("llvm-c/BitWriter.h");
    @cInclude("llvm-c/Comdat.h");
    @cInclude("llvm-c/DataTypes.h");
    @cInclude("llvm-c/DebugInfo.h");
    // @cInclude("llvm-c/Deprecated.h");
    @cInclude("llvm-c/Disassembler.h");
    @cInclude("llvm-c/DisassemblerTypes.h");
    @cInclude("llvm-c/Error.h");
    @cInclude("llvm-c/ErrorHandling.h");
    @cInclude("llvm-c/ExecutionEngine.h");
    @cInclude("llvm-c/ExternC.h");
    @cInclude("llvm-c/IRReader.h");
    @cInclude("llvm-c/LLJIT.h");
    @cInclude("llvm-c/LLJITUtils.h");
    @cInclude("llvm-c/Linker.h");
    @cInclude("llvm-c/Object.h");
    @cInclude("llvm-c/Orc.h");
    @cInclude("llvm-c/OrcEE.h");
    @cInclude("llvm-c/Remarks.h");
    @cInclude("llvm-c/Support.h");
    @cInclude("llvm-c/Target.h");
    @cInclude("llvm-c/TargetMachine.h");
    @cInclude("llvm-c/Transforms/PassBuilder.h");
    @cInclude("llvm-c/Types.h");
    @cInclude("llvm-c/blake3.h");
    @cInclude("llvm-c/lto.h");
});

fn allocator() std.mem.Allocator {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // return gpa.allocator();
    return std.heap.page_allocator;
}

pub const Context = struct {
    ref: llvm.LLVMContextRef,
    const Self = @This();
    pub fn init(ref: llvm.LLVMContextRef) Self {
        return Self{ .ref = ref };
    }

    pub fn deinit(self: Self) void {
        llvm.LLVMContextDispose(self.ref);
    }

    pub fn create() Self {
        return Self.init(llvm.LLVMContextCreate());
    }

    pub fn createModule(self: Self, name: []const u8) Module {
        return Module.init(llvm.LLVMModuleCreateWithNameInContext(@ptrCast(name), self.ref));
    }

    pub fn createBuilder(self: Self) Builder {
        return Builder.init(llvm.LLVMCreateBuilderInContext(self.ref));
    }

    pub fn appendBasicBlock(self: Self, function: Value, blockName: []const u8) BasicBlock {
        return BasicBlock.init(llvm.LLVMAppendBasicBlockInContext(self.ref, function.ref, @ptrCast(blockName)));
    }

    pub inline fn int8Type(self: Self) Type {
        return Type.init(llvm.LLVMInt8TypeInContext(self.ref));
    }

    pub inline fn int16Type(self: Self) Type {
        return Type.init(llvm.LLVMInt16TypeInContext(self.ref));
    }

    pub inline fn int32Type(self: Self) Type {
        return Type.init(llvm.LLVMInt32TypeInContext(self.ref));
    }

    pub inline fn intType(self: Self, size: comptime_int) Type {
        return Type.init(llvm.LLVMIntTypeInContext(self.ref, @intCast(size)));
    }

    pub inline fn voidType(self: Self) Type {
        return Type.init(llvm.LLVMVoidTypeInContext(self.ref));
    }

    pub inline fn ptrType(self: Self, addressSpace: usize) Type {
        return Type.init(llvm.LLVMPointerTypeInContext(self.ref, @intCast(addressSpace)));
    }
};

pub const Module = struct {
    ref: llvm.LLVMModuleRef,
    const Self = @This();
    pub fn init(ref: llvm.LLVMModuleRef) Self {
        return Self{ .ref = ref };
    }

    pub fn deinit(self: Self) void {
        llvm.LLVMDisposeModule(self.ref);
    }

    pub fn dump(self: Self) void {
        llvm.LLVMDumpModule(self.ref);
    }

    pub fn printToFile(self: Self, fileName: []const u8) bool {
        return llvm.LLVMPrintModuleToFile(
            self.ref,
            @ptrCast(fileName),
            undefined,
        ) == 1;
    }

    pub fn create(name: []const u8) Self {
        return Self.init(llvm.LLVMModuleCreateWithName(@ptrCast(name)));
    }

    pub fn addFunction(self: Self, fnName: []const u8, fnType: Type) Value {
        return Value.init(llvm.LLVMAddFunction(self.ref, @ptrCast(fnName), fnType.ref));
    }
};

pub const BasicBlock = struct {
    ref: llvm.LLVMBasicBlockRef,
    const Self = @This();
    pub fn init(ref: llvm.LLVMBasicBlockRef) Self {
        return Self{ .ref = ref };
    }
};

pub const Builder = struct {
    ref: llvm.LLVMBuilderRef,
    const Self = @This();
    pub fn init(ref: llvm.LLVMBuilderRef) Self {
        return Self{ .ref = ref };
    }

    pub fn deinit(self: Self) void {
        llvm.LLVMDisposeBuilder(self.ref);
    }

    pub fn globalString(self: Self, v: []const u8, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildGlobalString(self.ref, @ptrCast(v), @ptrCast(name)));
    }

    pub fn call2(self: Self, fnType: Type, function: Value, args: []const Value, argsCount: usize, name: []const u8) Value {
        var values = std.ArrayList(llvm.LLVMValueRef).init(allocator());
        defer values.deinit();
        for (args) |arg| {
            values.append(arg.ref) catch @panic("TODO: check alloc");
        }
        return Value.init(llvm.LLVMBuildCall2(
            self.ref,
            fnType.ref,
            function.ref,
            @ptrCast(values.items),
            @intCast(argsCount),
            @ptrCast(name),
        ));
    }

    pub fn ret(self: Self, returnValue: Value) Value {
        return Value.init(llvm.LLVMBuildRet(self.ref, returnValue.ref));
    }

    pub fn retVoid(self: Self) Value {
        return Value.init(llvm.LLVMBuildRetVoid(self.ref));
    }

    pub fn pointerCast(self: Self, v: Value, destType: Type, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildPointerCast(self.ref, v.ref, destType.ref, @ptrCast(name)));
    }

    // allocate in stack, so it's released in function scope.
    pub fn alloca(self: Self, ty: Type, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildAlloca(self.ref, ty.ref, @ptrCast(name)));
    }

    // allocate in stack, so it's released in function scope.
    pub fn arrayAlloca(self: Self, ty: Type, val: Value, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildArrayAlloca(self.ref, ty.ref, val.ref, @ptrCast(name)));
    }

    // allocate in memory, so you have to release yourself
    pub fn malloc(self: Self, ty: Type, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildMalloc(self.ref, ty.ref, @ptrCast(name)));
    }

    // allocate in memory, so you have to release yourself
    pub fn arrayMalloc(self: Self, ty: Type, size: Value, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildArrayMalloc(self.ref, ty.ref, size.ref, @ptrCast(name)));
    }

    pub fn free(self: Self, ptr: Value) Value {
        return Value.init(llvm.LLVMBuildFree(self.ref, ptr.ref));
    }

    pub fn add(self: Self, left: Value, right: Value, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildAdd(self.ref, left.ref, right.ref, @ptrCast(name)));
    }

    pub fn sub(self: Self, left: Value, right: Value, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildSub(self.ref, left.ref, right.ref, @ptrCast(name)));
    }

    pub fn cmp(self: Self, op: CompareOperator, left: Value, right: Value, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildICmp(self.ref, op.ref(), left.ref, right.ref, @ptrCast(name)));
    }

    pub fn store(self: Self, val: Value, ptr: Value) Value {
        return Value.init(llvm.LLVMBuildStore(self.ref, val.ref, ptr.ref));
    }

    pub fn load(self: Self, ty: Type, ptr: Value, name: []const u8) Value {
        return Value.init(llvm.LLVMBuildLoad2(self.ref, ty.ref, ptr.ref, @ptrCast(name)));
    }

    // if you get value ptr from array, you need to give element type to ty.
    pub fn gepInbounds(self: Self, ty: Type, ptr: Value, indexValues: []const Value, index: usize, name: []const u8) Value {
        var values = std.ArrayList(llvm.LLVMValueRef).init(allocator());
        defer values.deinit();
        for (indexValues) |v| {
            values.append(v.ref) catch @panic("TODO: check alloc");
        }

        return Value.init(llvm.LLVMBuildInBoundsGEP2(
            self.ref,
            ty.ref,
            ptr.ref,
            @ptrCast(values.items),
            @intCast(index),
            @ptrCast(name),
        ));
    }

    pub fn gep(self: Self, ty: Type, ptr: Value, indexValues: []const Value, index: usize, name: []const u8) Value {
        var values = std.ArrayList(llvm.LLVMValueRef).init(allocator());
        defer values.deinit();
        for (indexValues) |v| {
            values.append(v.ref) catch @panic("TODO: check alloc");
        }

        return Value.init(llvm.LLVMBuildGEP2(
            self.ref,
            ty.ref,
            ptr.ref,
            @ptrCast(values.items),
            @intCast(index),
            @ptrCast(name),
        ));
    }

    pub fn positionAtEnd(self: Self, block: BasicBlock) void {
        llvm.LLVMPositionBuilderAtEnd(self.ref, block.ref);
    }

    pub fn condBr(self: Self, flag: Value, thenBlock: BasicBlock, elseBlock: BasicBlock) Value {
        return Value.init(llvm.LLVMBuildCondBr(self.ref, flag.ref, thenBlock.ref, elseBlock.ref));
    }

    pub fn br(self: Self, dest: BasicBlock) Value {
        return Value.init(llvm.LLVMBuildBr(self.ref, dest.ref));
    }
};

pub const Type = struct {
    ref: llvm.LLVMTypeRef,
    const Self = @This();
    pub fn init(ref: llvm.LLVMTypeRef) Self {
        return Self{ .ref = ref };
    }

    pub fn dump(self: Self) void {
        llvm.LLVMDumpType(self.ref);
    }

    pub fn function(returnType: Type, paramTypes: []const Type, paramCount: usize, isVarArg: bool) Self {
        var params = std.ArrayList(llvm.LLVMTypeRef).init(allocator());
        defer params.deinit();
        for (paramTypes) |param| {
            params.append(param.ref) catch @panic("TODO: check alloc");
        }

        return Self.init(llvm.LLVMFunctionType(returnType.ref, @ptrCast(params.items), @intCast(paramCount), if (isVarArg) 1 else 0));
    }

    pub fn ptr(self: Self, addressSpace: usize) Self {
        return Self.init(llvm.LLVMPointerType(self.ref, @intCast(addressSpace)));
    }

    pub fn sizeOf(self: Self) usize {
        return @intCast(llvm.LLVMGetPointerAddressSpace(self.ref));
    }

    pub fn array(ty: Type, elementCount: usize) Type {
        return Self.init(llvm.LLVMArrayType(ty.ref, @intCast(elementCount)));
    }
};

pub const Value = struct {
    ref: llvm.LLVMValueRef,
    const Self = @This();
    pub fn init(ref: llvm.LLVMValueRef) Self {
        return Self{ .ref = ref };
    }

    pub fn dump(self: Self) void {
        llvm.LLVMDumpValue(self.ref);
    }

    pub fn getParam(self: Self, index: usize) Self {
        // TODO: check this is function or not
        return Self.init(llvm.LLVMGetParam(self.ref, @intCast(index)));
    }

    pub fn getLastBlock(self: Self) BasicBlock {
        // TODO: check this is function or not
        return BasicBlock.init(llvm.LLVMGetLastBasicBlock(self.ref));
    }

    pub fn constInt(ty: Type, n: isize, signExtent: bool) Self {
        return Self.init(llvm.LLVMConstInt(ty.ref, @intCast(n), if (signExtent) 1 else 0));
    }

    pub fn constAdd(left: Value, right: Value) Self {
        return Self.init(llvm.LLVMConstAdd(left.ref, right.ref));
    }
};

pub const CompareOperator = enum(isize) {
    EQ = llvm.LLVMIntEQ,
    NE = llvm.LLVMIntNE,
    UGT = llvm.LLVMIntUGT,
    UGE = llvm.LLVMIntUGE,
    ULT = llvm.LLVMIntULT,
    ULE = llvm.LLVMIntULE,
    SGT = llvm.LLVMIntSGT,
    SGE = llvm.LLVMIntSGE,
    SLT = llvm.LLVMIntSLT,
    SLE = llvm.LLVMIntSLE,

    const Self = @This();
    pub fn ref(self: Self) llvm.LLVMIntPredicate {
        return @intCast(@intFromEnum(self));
    }
};

test "hello world" {
    const ctx = Context.create();
    defer ctx.deinit();
    const module = ctx.createModule("hello");
    defer module.deinit();
    const builder = ctx.createBuilder();
    defer builder.deinit();

    const int8 = ctx.int8Type();
    const int8Ptr = int8.ptr(0);
    const int32 = ctx.int32Type();

    // puts function
    const putsFunctionArgsType = [_]Type{int8};
    const putsFunctionType = Type.function(int32, &putsFunctionArgsType, 1, false);
    const putsFunction = module.addFunction("puts", putsFunctionType);
    // end

    // main function
    const mainFunctionType = Type.function(int32, &[_]Type{}, 0, false);
    const mainFunction = module.addFunction("main", mainFunctionType);

    const entry = ctx.appendBasicBlock(mainFunction, "entry");
    builder.positionAtEnd(entry);

    const putsFunctionArg = [_]Value{builder.pointerCast(builder.globalString("Hello, World!", "hello"), int8Ptr, "0")};
    _ = builder.call2(putsFunctionType, putsFunction, &putsFunctionArg, 1, "i");
    _ = builder.ret(Value.constInt(int32, 0, false));
    // end

    // module.dump();// dump module to STDOUT
    _ = module.printToFile("hello.ll");
}
