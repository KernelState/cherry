const std = @import("std");
const cherry = @import("cherry");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    const io = init.io;

    const renderer = try cherry.renderers.SDL3Renderer.create(alloc);

    var buf = try cherry.PixelBuffer.new(alloc, .{ .w = 400, .h = 300 });
    defer buf.deinit(alloc);

    var window = try cherry.Window.init(alloc, &buf, renderer, .{
        .title = "Cherry Example",
        .size = .{ .w = 400, .h = 300 },
        .position = null,
    });
    defer window.deinit(alloc);
    window.appdata = &window;
    window.view = view;
    window.update = update;
    try window.run(alloc, io);
}

fn view(self_: *const anyopaque, buf: *cherry.PixelBuffer) !void {
    const self: *cherry.Window = @ptrCast(@constCast(@alignCast(self_)));
    buf.fill(try .fromHex("000000"));
    buf.rect(.{
        .pos = .{ .x = 100, .y = 110 },
        .size = .{ .w = 300, .h = 200 },
        .borderRadius = .all(20),
        .borderColor = try .fromHex("ffffff"),
        .backgroundColor = try .fromHex("#11111"),
        .borderSize = .all(20),
    });

    const wsize = self.getSize();
    std.debug.print("buffer size: {}x{}, window size: {}x{}\n", .{self.buf.size.w, self.buf.size.h, wsize.w, wsize.h,});
}

fn update(
    self_: *anyopaque,
    _: cherry.Window.Message,
    _: std.Io,
    alloc: std.mem.Allocator,
) !void {
    const self: *std.ArrayList([]const u8) = @ptrCast(@alignCast(self_));
    _ = self;
    _ = alloc;
}
