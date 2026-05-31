const std = @import("std");
const cherry = @import("cherry.zig");

arena: std.heap.ArenaAllocator,
nodes: std.HashMapUnmanaged(cherry.Id, *anyopaque) = .empty,

pub const Node = union(enum) {
    mem: *anyopaque,
    widget: *cherry.Widget,
    string: []const u8,
};

const Db = @This();

pub fn init(alloc: std.mem.Allocator) Db {
    return .{ .arena = .init(alloc) };
}

pub fn put(self: *Db, id: cherry.Id, val: Node) !void {
    try self.nodes.put(self.arena.allocator(), id, val);
}

pub fn get(self: *Db, id: cherry.Id) *Node {
    return self.nodes.get(id).?;
}

pub fn deinit(self: *Db) void {
    self.arena.deinit();
}
