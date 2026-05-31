const std = @import("std");
const cherry = @import("cherry.zig");

id: cherry.Id,
db: *cherry.Db,
style: cherry.Style,
animating: bool = false,

const Widget = @This();

pub fn init() void {}
