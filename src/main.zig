const std = @import("std");
const llvm = @import("llvm");
const lexer = @import("./token.zig");
const codegen = @import("./codegen.zig");

pub fn main() !void {
    const src = ">++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++....-.-.-.";
    const tokens = try lexer.lexer(src, std.heap.page_allocator);
    defer tokens.deinit();
    var g = codegen.init(std.heap.page_allocator);
    defer g.deinit();
    _ = g.codegen(tokens.items);
}
