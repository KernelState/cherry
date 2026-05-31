const std = @import("std");
const cherry = @import("cherry.zig");

pub const WindowConfig = struct {
    size: cherry.Pos,
    position: ?cherry.Pos,
};

pub const Window = struct {
    title: []const u8,
    //icon: cherry.Image,
    config: WindowConfig,
    db: *cherry.Db,
    id: cherry.Id,
};

pub const Implementation = struct {
    createWindow: *const fn (WindowConfig) Window,
    drawSquare: *const fn (cherry.Rect) void,
    drawCircle: *const fn (u32) void,
    clearBackground: *const fn (cherry.Color) void,
};
