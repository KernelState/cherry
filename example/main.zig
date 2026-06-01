const std = @import("std");
const cherry = @import("cherry");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    var buf = try cherry.PixelBuffer.new(alloc, .{ .w = 400, .h = 300 });
    defer buf.deinit(alloc);
    var db = cherry.Db.init(alloc);
    var window = cherry.Window{
        .title = "Test",
        .id = cherry.genId(),
        .db = &db,
        .size = .{ .w = 400, .h = 300 },
        .position = null,
    };
    var renderer = try cherry.VulkanRenderer.init(alloc);
    defer renderer.deinit();
    try renderer.createWindow(&window);
    buf.rect(.{
        .backgroundColor = try .fromHex("#00FFFF"),
        .borderColor = try .fromHex("#FFFFFF"),
        .pos = .{ .x = 20, .y = 50 },
        .size = .{ .w = 100, .h = 50 },
        .borderRadius = .all(20),
        .borderSize = .all(4),
    });
    try renderer.draw(buf);
    while (!renderer.shouldClose()) {
        for (renderer.pollEvents()) |ev| {
            switch (ev) {
                .keyPressed => |key| {
                    if (key == .esc) renderer.closed = true;
                },
                else => {},
            }
        }
    }
}
