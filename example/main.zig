const std = @import("std");
const cherry = @import("cherry");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    const io = init.io;

    const renderer = try cherry.renderers.SDL3Renderer.create(alloc);

    var buf = try cherry.PixelBuffer.new(alloc, .{ .w = 800, .h = 600 });
    defer buf.deinit(alloc);

    var window = try cherry.Window.init(alloc, &buf, renderer, .{
        .title = "Cherry Example",
        .size = .{ .w = 800, .h = 600 },
        .position = null,
    });
    defer window.deinit(alloc);
    window.run(alloc, io);
}
