const std = @import("std");
const ArrayCastAllocator = @import("./allocator.zig").ArrayCastAllocator;
const Function = @import("./function.zig").Function;
const Module = @import("./module.zig").Module;
const Type = @import("./type.zig").Type;
const llvm = @import("./import.zig");

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

    pub fn appendBasicBlock(self: Self, function: Function, blockName: []const u8) BasicBlock {
        return BasicBlock.init(llvm.LLVMAppendBasicBlockInContext(self.ref, function.ptr.ref, @ptrCast(blockName)));
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

    pub fn call2(self: Self, fun: Function, args: []const Value, argsCount: usize, name: []const u8) Value {
        var values = std.ArrayList(llvm.LLVMValueRef).init(ArrayCastAllocator.singleton());
        defer values.deinit();
        for (args) |arg| {
            values.append(arg.ref) catch @panic("TODO: check alloc");
        }

        return Value.init(llvm.LLVMBuildCall2(
            self.ref,
            fun.meta.fnType.ref,
            fun.ptr.ref,
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
        var values = std.ArrayList(llvm.LLVMValueRef).init(ArrayCastAllocator.singleton());
        // defer values.deinit();
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
        var values = std.ArrayList(llvm.LLVMValueRef).init(ArrayCastAllocator.singleton());
        // defer values.deinit();
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

pub const Value = struct {
    ref: llvm.LLVMValueRef,
    const Self = @This();
    pub fn init(ref: llvm.LLVMValueRef) Self {
        return Self{ .ref = ref };
    }

    pub fn dump(self: Self) void {
        llvm.LLVMDumpValue(self.ref);
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
