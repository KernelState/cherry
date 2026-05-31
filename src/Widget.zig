const std = @import("std");
const cherry = @import("cherry.zig");

id: cherry.Id,
parent: cherry.Id,

const Widget = @This();

pub fn init() void {}
