const llvm = @import("./import.zig");
const Type = @import("./type.zig").Type;
const wllvm = @import("./wrapped-llvm.zig");

pub const FunctionMeta = struct {
    name: []const u8,
    fnType: Type,

    const Self = @This();
    pub fn init(name: []const u8, fnType: Type) Self {
        return Self{
            .name = name,
            .fnType = fnType,
        };
    }

    // define Entry point
    pub fn main(ctx: wllvm.Context) Self {
        const argTypes = [_]Type{};
        const fnType = Type.function(ctx.int32Type(), &argTypes, argTypes.len, false);
        return Self.init("main", fnType);
    }

    //
    // C functions
    //
    pub fn puts(ctx: wllvm.Context) Self {
        const argTypes = [_]Type{ctx.int8Type()};
        const fnType = Type.function(ctx.int32Type(), &argTypes, argTypes.len, false);
        return Self.init("puts", fnType);
    }

    pub fn putchar(ctx: wllvm.Context) Self {
        const argTypes = [_]Type{ctx.int32Type()};
        const fnType = Type.function(ctx.int32Type(), &argTypes, argTypes.len, false);
        return Self.init("putchar", fnType);
    }

    pub fn getchar(ctx: wllvm.Context) Self {
        const argTypes = [0]Type{};
        const fnType = Type.function(ctx.int32Type(), &argTypes, argTypes.len, false);
        return Self.init("getchar", fnType);
    }

    pub fn printf(ctx: wllvm.Context) Self {
        const argTypes = [_]Type{ctx.ptrType(8)};
        const fnType = Type.function(ctx.int32Type(), &argTypes, argTypes.len, true);
        return Self.init("printf", fnType);
    }

    // const putcharFunction = self.module.addFunction("putchar", putcharFunctionType);
    // const printfFunction = self.module.addFunction("printf", printfFunctionType);
};

pub const Function = struct {
    meta: FunctionMeta,
    ptr: wllvm.Value,

    const Self = @This();
    pub fn init(meta: FunctionMeta, ptr: wllvm.Value) Self {
        return Self{
            .meta = meta,
            .ptr = ptr,
        };
    }

    pub fn getParam(self: Self, index: usize) wllvm.Value {
        return wllvm.Value.init(llvm.LLVMGetParam(self.ptr.ref, @intCast(index)));
    }
};
