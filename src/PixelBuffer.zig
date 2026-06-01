/// PixelBuffer is kind of like allocators it's the thing you passdown to every
/// function that renders anything
const std = @import("std");
const cherry = @import("cherry.zig");

buf: []u8,
size: cherry.Rect,

const PixelBuffer = @This();

pub fn new(alloc: std.mem.Allocator, size: cherry.Rect) !PixelBuffer {
    return .{
        .buf = try alloc.alloc(u8, 4 * size.w * size.h),
        .size = size,
    };
}

pub fn index(pos: cherry.Pos) usize {
    return pos.x * pos.y * 4;
}

pub fn subBuffer(self: *PixelBuffer, pos: cherry.Pos, size: cherry.Rect) PixelBuffer {
    const end = cherry.Pos{
        .x = pos.x + size.w,
        .y = pos.y + size.h,
    };
    return .{
        .size = rect,
        .buf = self.buf[index(pos)..(index(end) + 4)],
    };
}

pub const RectOptions = struct {
    pos: cherry.Pos,
    size: cherry.Rect,
    borderRadius: cherry.Style.Radius,
    borderSize: cherry.StyleRect,
    borderColor: cherry.Color,
    backgroundColor: cherry.Color,
};

pub fn rect(self: *PixelBuffer, opts: RectOptions) void {
    var cursor = cherry.Pos{ .x = 0, .y = 0 };
    for (0..opts.size.h*opts.size.w) |i| {
        defer {
            cursor = cherry.Pos{
                .x = @intCast(i % opts.size.w),
                .y = @intCast(i / opts.size.w),
            };
        }
        const cancelled = blk: {
            if (cursor.x < opts.borderRadius.topLeft and cursor.y < opts.borderRadius.topLeft) {
                const dx = opts.borderRadius.topLeft - cursor.x - 1;
                const dy = opts.borderRadius.topLeft - cursor.y - 1;
                break :blk dx*dx + dy*dy > opts.borderRadius.topLeft * opts.borderRadius.topLeft;
            }
            // top-right corner
            if (cursor.x >= opts.size.w - opts.borderRadius.topRight and cursor.y < opts.borderRadius.topRight) {
                const dx = cursor.x - (opts.size.w - opts.borderRadius.topRight);
                const dy = opts.borderRadius.topRight - cursor.y - 1;
                break :blk dx*dx + dy*dy > opts.borderRadius.topRight * opts.borderRadius.topRight;
            }
            // bottom-left corner
            if (cursor.x < opts.borderRadius.bottomLeft and cursor.y >= opts.size.h - opts.borderRadius.bottomLeft) {
                const dx = opts.borderRadius.bottomLeft - cursor.x - 1;
                const dy = cursor.y - (opts.size.h - opts.borderRadius.bottomLeft);
                break :blk dx*dx + dy*dy > opts.borderRadius.bottomLeft * opts.borderRadius.bottomLeft;
            }
            // bottom-right corner
            if (cursor.x >= opts.size.w - opts.borderRadius.bottomRight and cursor.y >= opts.size.h - opts.borderRadius.bottomRight) {
                const dx = cursor.x - (opts.size.w - opts.borderRadius.bottomRight);
                const dy = cursor.y - (opts.size.h - opts.borderRadius.bottomRight);
                break :blk dx*dx + dy*dy > opts.borderRadius.bottomRight * opts.borderRadius.bottomRight;
            }
        };
        const color = 
            if (cursor.y < opts.borderSize.top
                or cursor.y > (opts.size.h - opts.borderSize.bottom)
                or cursor.x < opts.borderSize.left
                or cursor.x > (opts.size.w - opts.borderSize.right))
                opts.borderColor
            else opts.backgroundColor;
        if (!cancelled) {
            const base = ((opts.pos.x * opts.pos.y) + i) * 4;
            self.buf[base] = color.r;
            self.buf[base+1] = color.g;
            self.buf[base+2] = color.b;
            self.buf[base+3] = color.a;
        }
    }
}

pub fn calcSize(size: cherry.Rect, padding: cherry.StyleRect, border: cherry.StyleRect) cherry.Rect {
    return .{
        .w = size.w + padding.right + padding.left + border.left + border.right,
        .h = size.w + padding.top + padding.bottom + border.bottom + border.top,
    };
}
