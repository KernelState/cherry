const std = @import("std");
const cherry = @import("cherry.zig");

arena: std.heap.ArenaAllocator,
currentTheme: u8,
themes: std.ArrayList(cherry.Theme) = .empty,
widgets: std.ArrayList(cherry.Widget) = .empty,
data: std.StringHashMapUnmanaged([]const u8) = .empty,

pub const Node = union(enum) {
    mem: *anyopaque,
    widget: *cherry.Widget,
    string: []const u8,
};

const Db = @This();

pub fn init(alloc: std.mem.Allocator) Db {
    return .{ .arena = .init(alloc) };
}

pub fn put(self: *Db, id: []const u8, val: Node) !void {
    try self.data.put(self.arena.allocator(), id, val);
}

pub fn get(self: *Db, id: []const u8) *Node {
    return self.data.get(id).?;
}

pub fn addWidget(self: *Db, w: cherry.Widget) !void {
    try self.widgets.append(self.arena.allocator(), w);
}

pub fn addTheme(self: *Db, theme: cherry.Theme) !void {
    try self.themes.append(self.arena.allocator(), theme);
}

pub fn themeSet(self: *Db, theme: cherry.Theme) void {
    try self.addTheme(theme);
    self.currentTheme = self.themes.items.len-1;
}

pub fn getBase(self: *Db, mode: cherry.Palette.Mode) cherry.Style {
    std.debug.assert(self.themes.items.len > @as(usize, @intCast(self.currentTheme)));
    const set: cherry.ColorSet = self.themes.items[@intCast(self.currentTheme)];
    return .{
        .background = set.background,
        .borderColor = set.border,
        .text = set.text,
    };
} 

pub fn deinit(self: *Db) void {
    self.arena.deinit();
}
