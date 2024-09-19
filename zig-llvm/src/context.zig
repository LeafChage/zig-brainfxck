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
