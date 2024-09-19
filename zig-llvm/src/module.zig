const wllvm = @import("./wrapped-llvm.zig");
const llvm = @import("./import.zig");
const _function = @import("./function.zig");
const Type = @import("./type.zig").Type;
const Function = _function.Function;
const FunctionMeta = _function.FunctionMeta;

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

    pub fn buildToFile(self: Self, fileName: []const u8) bool {
        return llvm.LLVMWriteBitcodeToFile(self.ref, @ptrCast(fileName)) == 1;
    }

    pub fn create(name: []const u8) Self {
        return Self.init(llvm.LLVMModuleCreateWithName(@ptrCast(name)));
    }

    pub fn addFunction(self: Self, fun: FunctionMeta) Function {
        const ptr = wllvm.Value.init(llvm.LLVMAddFunction(self.ref, @ptrCast(fun.name), fun.fnType.ref));
        return Function.init(fun, ptr);
    }

    pub fn linkModule(self: Self, m: Module) bool {
        return llvm.LLVMLinkModules2(self.ref, m.ref) == 1;
    }
};
