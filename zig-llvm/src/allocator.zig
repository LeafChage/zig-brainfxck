const std = @import("std");

pub const ArrayCastAllocator = struct {
    var _a: ?std.mem.Allocator = null;

    pub fn init(m: std.mem.Allocator) void {
        _a = m;
    }

    pub fn singleton() std.mem.Allocator {
        return _a orelse @panic("you should set allocator");
    }
};
