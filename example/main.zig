const std = @import("std");
const cherry = @import("cherry");

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    const renderer = try cherry.renderers.SDL3Renderer.create(alloc);

    var buf = try cherry.PixelBuffer.new(alloc, .{ .w = 800, .h = 600 });
    defer buf.deinit(alloc);

    var window = try cherry.Window.init(alloc, &buf, renderer, .{
        .title = "Cherry Example",
        .size = .{ .w = 800, .h = 600 },
        .position = null,
    });
    defer window.deinit(alloc);

    try window.createWindow();

    var events: std.ArrayList(cherry.Event) = .empty;
    defer events.deinit(alloc);

    var frame: u32 = 0;
    while (!window.shouldClose()) {
        events.clearRetainingCapacity();
        window.pollEvents(&events);

        for (events.items) |ev| {
            switch (ev) {
                .keyPressed => |key| {
                    if (key == .esc) {
                        window.closeWindow() catch {};
                    }
                },
                else => {},
            }
        }

        try window.drawBuffer();
        window.swapBuffers();

        frame += 1;
    }
}
