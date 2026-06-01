const std = @import("std");
const cherry = @import("cherry.zig");

pub const Implementation = struct {
    data: *anyopaque,
    createWindow: *const fn (*anyopaque, *cherry.Window) anyerror!void,
    drawBuffer: *const fn (*anyopaque, cherry.PixelBuffer) anyerror!void,
    closeWindow: *const fn (*anyopaque, *cherry.Window) void,
};
