const llvm = @import("llvm");

pub const Function = struct {
    fnType: llvm.Type,
    fnValue: llvm.Value,

    const Self = @This();
    pub fn init(fnType: llvm.Type, fnValue: llvm.Value) Self {
        return Self{
            .fnType = fnType,
            .fnValue = fnValue,
        };
    }
};
