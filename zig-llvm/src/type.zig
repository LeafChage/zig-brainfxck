const std = @import("std");
const ArrayCastAllocator = @import("./allocator.zig").ArrayCastAllocator;
const llvm = @import("./import.zig");

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
        var params = std.ArrayList(llvm.LLVMTypeRef).init(ArrayCastAllocator.singleton());
        // defer params.deinit();
        for (paramTypes) |param| {
            params.append(param.ref) catch @panic("TODO: check alloc");
        }

        return Self.init(llvm.LLVMFunctionType(returnType.ref, @ptrCast(params.items), @intCast(paramCount), if (isVarArg) 1 else 0));
    }

    pub fn ptr(self: Self) Self {
        return Self.init(llvm.LLVMPointerType(self.ref, @intCast(self.sizeOf())));
    }

    pub fn sizeOf(self: Self) usize {
        return @intCast(llvm.LLVMGetPointerAddressSpace(self.ref));
    }

    pub fn array(ty: Type, elementCount: usize) Type {
        return Self.init(llvm.LLVMArrayType(ty.ref, @intCast(elementCount)));
    }
};
