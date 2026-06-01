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

pub fn index(self: *PixelBuffer, pos: cherry.Pos) usize {
    return (pos.y * self.size.w + pos.x) * 4;
}

pub fn subBuffer(self: *PixelBuffer, pos: cherry.Pos, size: cherry.Rect) PixelBuffer {
    const start = self.index(pos);
    const end = self.index(.{ .x = pos.x + size.w - 1, .y = pos.y + size.h - 1 }) + 4;
    return .{
        .size = size,
        .buf = self.buf[start..end],
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
    const draw_w = opts.size.w + opts.borderSize.left + opts.borderSize.right;
    const draw_h = opts.size.h + opts.borderSize.top + opts.borderSize.bottom;

    for (0..draw_w * draw_h) |i| {
        const cursor = cherry.Pos{
            .x = @intCast(i % draw_w),
            .y = @intCast(i / draw_w),
        };

        const cancelled = blk: {
            // top-left
            if (cursor.x < opts.borderRadius.topLeft and cursor.y < opts.borderRadius.topLeft) {
                const dx = opts.borderRadius.topLeft - cursor.x - 1;
                const dy = opts.borderRadius.topLeft - cursor.y - 1;
                break :blk dx*dx + dy*dy > opts.borderRadius.topLeft * opts.borderRadius.topLeft;
            }
            // top-right
            if (cursor.x >= draw_w - opts.borderRadius.topRight and cursor.y < opts.borderRadius.topRight) {
                const dx = cursor.x - (draw_w - opts.borderRadius.topRight);
                const dy = opts.borderRadius.topRight - cursor.y - 1;
                break :blk dx*dx + dy*dy > opts.borderRadius.topRight * opts.borderRadius.topRight;
            }
            // bottom-left
            if (cursor.x < opts.borderRadius.bottomLeft and cursor.y >= draw_h - opts.borderRadius.bottomLeft) {
                const dx = opts.borderRadius.bottomLeft - cursor.x - 1;
                const dy = cursor.y - (draw_h - opts.borderRadius.bottomLeft);
                break :blk dx*dx + dy*dy > opts.borderRadius.bottomLeft * opts.borderRadius.bottomLeft;
            }
            // bottom-right
            if (cursor.x >= draw_w - opts.borderRadius.bottomRight and cursor.y >= draw_h - opts.borderRadius.bottomRight) {
                const dx = cursor.x - (draw_w - opts.borderRadius.bottomRight);
                const dy = cursor.y - (draw_h - opts.borderRadius.bottomRight);
                break :blk dx*dx + dy*dy > opts.borderRadius.bottomRight * opts.borderRadius.bottomRight;
            }
            break :blk false;
        };

        if (cancelled) continue;

        const in_border =
            cursor.x < opts.borderSize.left or
            cursor.x >= draw_w - opts.borderSize.right or
            cursor.y < opts.borderSize.top or
            cursor.y >= draw_h - opts.borderSize.bottom;

        // inner radius cancel (fill area only)
        const inner_cancelled = if (!in_border) blk: {
            const ix = cursor.x - opts.borderSize.left;
            const iy = cursor.y - opts.borderSize.top;
            const iw = opts.size.w;
            const ih = opts.size.h;
            const ir = cherry.Style.Radius{
                .topLeft     = opts.borderRadius.topLeft     -| opts.borderSize.left,
                .topRight    = opts.borderRadius.topRight    -| opts.borderSize.right,
                .bottomLeft  = opts.borderRadius.bottomLeft  -| opts.borderSize.left,
                .bottomRight = opts.borderRadius.bottomRight -| opts.borderSize.right,
            };
            if (ix < ir.topLeft and iy < ir.topLeft) {
                const dx = ir.topLeft - ix - 1;
                const dy = ir.topLeft - iy - 1;
                break :blk dx*dx + dy*dy > ir.topLeft * ir.topLeft;
            }
            if (ix >= iw - ir.topRight and iy < ir.topRight) {
                const dx = ix - (iw - ir.topRight);
                const dy = ir.topRight - iy - 1;
                break :blk dx*dx + dy*dy > ir.topRight * ir.topRight;
            }
            if (ix < ir.bottomLeft and iy >= ih - ir.bottomLeft) {
                const dx = ir.bottomLeft - ix - 1;
                const dy = iy - (ih - ir.bottomLeft);
                break :blk dx*dx + dy*dy > ir.bottomLeft * ir.bottomLeft;
            }
            if (ix >= iw - ir.bottomRight and iy >= ih - ir.bottomRight) {
                const dx = ix - (iw - ir.bottomRight);
                const dy = iy - (ih - ir.bottomRight);
                break :blk dx*dx + dy*dy > ir.bottomRight * ir.bottomRight;
            }
            break :blk false;
        } else false;

        if (inner_cancelled) continue;

        const color = if (in_border) opts.borderColor else opts.backgroundColor;

        // pos offsets into the parent buffer, cursor is local to the draw region
        // draw region starts at (pos.x - borderSize.left, pos.y - borderSize.top)
        const abs = cherry.Pos{
            .x = opts.pos.x + cursor.x -| opts.borderSize.left,
            .y = opts.pos.y + cursor.y -| opts.borderSize.top,
        };
        const base = self.index(abs);
        self.buf[base]   = color.r;
        self.buf[base+1] = color.g;
        self.buf[base+2] = color.b;
        self.buf[base+3] = color.a;
    }
}

pub fn calcSize(size: cherry.Rect, padding: cherry.StyleRect, border: cherry.StyleRect) cherry.Rect {
    return .{
        .w = size.w + padding.right + padding.left + border.left + border.right,
        .h = size.h + padding.top + padding.bottom + border.bottom + border.top,
    };
}
