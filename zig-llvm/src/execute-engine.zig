const llvm = @import("./import.zig");
const Module = @import("./module.zig").Module;
const Function = @import("./function.zig").Function;

pub const ExecuteEngine = struct {
    ref: llvm.LLVMExecutionEngineRef,
    const Self = @This();

    pub fn init(ref: llvm.LLVMExecutionEngineRef) Self {
        return Self{ .ref = ref };
    }

    pub fn createForModule(m: Module) !Self {
        var engine: llvm.LLVMExecutionEngineRef = undefined;

        // TODO: error handling
        // llvm.LLVMCreateExecutionEngineForModule
        // This function can be called with array to save errorMessage
        const result = llvm.LLVMCreateExecutionEngineForModule(&engine, m.ref, undefined);
        if (result == 1) {
            @panic("cannot make execution engine");
        }
        return ExecuteEngine.init(engine);
    }

    pub fn runMainFunction(self: Self, main: Function) isize {
        return @intCast(llvm.LLVMRunFunctionAsMain(self.ref, main.ptr.ref, 0, undefined, undefined));
    }
};
