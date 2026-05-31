const std = @import("std");
const cherry = @import("cherry.zig");

palette: cherry.Palette,
styles: std.StringHashMapUnmanaged(cherry.Style),
