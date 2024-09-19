const std = @import("std");
const llvm = @import("llvm");
const lexer = @import("./token.zig");
const codegen = @import("./codegen.zig");

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();

    const file_path = args.next() orelse @panic("you need path argument");

    var buffer: [1024 * 100]u8 = undefined;
    const data = try std.fs.cwd().readFile(file_path, &buffer);

    const tokens = try lexer.lexer(data, std.heap.page_allocator);
    defer tokens.deinit();
    var g = codegen.init(std.heap.page_allocator);
    defer g.deinit();
    _ = g.codegen(tokens.items);
}
