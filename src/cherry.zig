const std = @import("std");
pub const Db = @import("Db.zig");
pub const Widget = @import("Widget.zig");

pub const Pos = struct {
    x: u32,
    y: u32,
};

pub const Rect = struct {
    w: u32,
    h: u32,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Id = u64;
