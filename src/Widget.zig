const std = @import("std");
const cherry = @import("cherry.zig");

data: *anyopaque,
render: *const fn (*anyopaque, cherry.PixelBuffer) void,
size: *const fn (*anyopaque) cherry.Rect,

const Widget = @This();

pub fn fromStruct(widget: anytype) Widget {
    if (@hasField(@TypeOf(widget), "widgetData"))
        return @field(widget, "widgetData");
    @compileError("Cannot find required field for widget `widgetData`");
}
