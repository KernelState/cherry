const std = @import("std");
const cherry = @import("cherry");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    var buf = try cherry.PixelBuffer.new(alloc, .{ .w = 400, .h = 300 });
    defer buf.deinit(alloc);
    std.debug.print("no renderer :(", .{});
}
