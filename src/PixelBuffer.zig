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

pub fn index(self: *PixelBuffer, pos: cherry.Pos) usize {
    return ((pos.y * self.size.w) + pos.x) * 4;
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

fn innerRadius(outer: u32, borderA: u32, borderB: u32) u32 {
    const inset = @max(borderA, borderB);
    return if (inset >= outer) 0 else outer - inset;
}

fn cornerAA(distSq: u32, outerR: u32) ?f32 {
    const rSq = outerR * outerR;
    if (distSq <= rSq) {
        if (rSq - distSq >= outerR) return 1.0;
    } else if (distSq - rSq > outerR) return null;
    const rf = @as(f32, @floatFromInt(outerR));
    const dist = @sqrt(@as(f32, @floatFromInt(distSq)));
    if (dist > rf + 0.5) return null;
    return if (dist > rf - 0.5) (rf + 0.5 - dist) else 1.0;
}

pub fn rect(self: *PixelBuffer, opts: RectOptions) void {
    var cursor = cherry.Pos{ .x = 0, .y = 0 };
    for (0..opts.size.h*opts.size.w) |i| {
        defer {
            cursor = cherry.Pos{
                .x = @intCast(i % opts.size.w),
                .y = @intCast(i / opts.size.w),
            };
        }
        const color: ?cherry.Color = color: {
            // top-left
            if (cursor.x < opts.borderRadius.topLeft and cursor.y < opts.borderRadius.topLeft) {
                const dx = opts.borderRadius.topLeft - cursor.x - 1;
                const dy = opts.borderRadius.topLeft - cursor.y - 1;
                const distSq = dx*dx + dy*dy;
                const outerR = opts.borderRadius.topLeft;
                const cov = cornerAA(distSq, outerR) orelse break :color null;
                if (cursor.x < opts.borderSize.left or cursor.y < opts.borderSize.top) {
                    if (cov < 1.0) { var c = opts.borderColor; c.a *= cov; break :color c; }
                    break :color opts.borderColor;
                }
                const innerR = innerRadius(outerR, opts.borderSize.top, opts.borderSize.left);
                const color = if (distSq <= innerR * innerR) opts.backgroundColor else opts.borderColor;
                if (cov < 1.0) { var c = color; c.a *= cov; break :color c; }
                break :color color;
            }
            // top-right
            if (cursor.x >= opts.size.w - opts.borderRadius.topRight and cursor.y < opts.borderRadius.topRight) {
                const dx = cursor.x - (opts.size.w - opts.borderRadius.topRight);
                const dy = opts.borderRadius.topRight - cursor.y - 1;
                const distSq = dx*dx + dy*dy;
                const outerR = opts.borderRadius.topRight;
                const cov = cornerAA(distSq, outerR) orelse break :color null;
                if (cursor.x >= opts.size.w - opts.borderSize.right or cursor.y < opts.borderSize.top) {
                    if (cov < 1.0) { var c = opts.borderColor; c.a *= cov; break :color c; }
                    break :color opts.borderColor;
                }
                const innerR = innerRadius(outerR, opts.borderSize.top, opts.borderSize.right);
                const color = if (distSq <= innerR * innerR) opts.backgroundColor else opts.borderColor;
                if (cov < 1.0) { var c = color; c.a *= cov; break :color c; }
                break :color color;
            }
            // bottom-left
            if (cursor.x < opts.borderRadius.bottomLeft and cursor.y >= opts.size.h - opts.borderRadius.bottomLeft) {
                const dx = opts.borderRadius.bottomLeft - cursor.x - 1;
                const dy = cursor.y - (opts.size.h - opts.borderRadius.bottomLeft);
                const distSq = dx*dx + dy*dy;
                const outerR = opts.borderRadius.bottomLeft;
                const cov = cornerAA(distSq, outerR) orelse break :color null;
                if (cursor.x < opts.borderSize.left or cursor.y >= opts.size.h - opts.borderSize.bottom) {
                    if (cov < 1.0) { var c = opts.borderColor; c.a *= cov; break :color c; }
                    break :color opts.borderColor;
                }
                const innerR = innerRadius(outerR, opts.borderSize.bottom, opts.borderSize.left);
                const color = if (distSq <= innerR * innerR) opts.backgroundColor else opts.borderColor;
                if (cov < 1.0) { var c = color; c.a *= cov; break :color c; }
                break :color color;
            }
            // bottom-right
            if (cursor.x >= opts.size.w - opts.borderRadius.bottomRight and cursor.y >= opts.size.h - opts.borderRadius.bottomRight) {
                const dx = cursor.x - (opts.size.w - opts.borderRadius.bottomRight);
                const dy = cursor.y - (opts.size.h - opts.borderRadius.bottomRight);
                const distSq = dx*dx + dy*dy;
                const outerR = opts.borderRadius.bottomRight;
                const cov = cornerAA(distSq, outerR) orelse break :color null;
                if (cursor.x >= opts.size.w - opts.borderSize.right or cursor.y >= opts.size.h - opts.borderSize.bottom) {
                    if (cov < 1.0) { var c = opts.borderColor; c.a *= cov; break :color c; }
                    break :color opts.borderColor;
                }
                const innerR = innerRadius(outerR, opts.borderSize.bottom, opts.borderSize.right);
                const color = if (distSq <= innerR * innerR) opts.backgroundColor else opts.borderColor;
                if (cov < 1.0) { var c = color; c.a *= cov; break :color c; }
                break :color color;
            }

            // Not in any corner — simple rect border check
            if (cursor.y < opts.borderSize.top
                or cursor.y >= opts.size.h - opts.borderSize.bottom
                or cursor.x < opts.borderSize.left
                or cursor.x >= opts.size.w - opts.borderSize.right)
                break :color opts.borderColor;
            break :color opts.backgroundColor;
        };
        if (color) |c| {
            const base = ((((opts.pos.y + cursor.y) * self.size.w) + opts.pos.x + cursor.x)) * 4;
            self.buf[base] = c.r;
            self.buf[base+1] = c.g;
            self.buf[base+2] = c.b;
            self.buf[base+3] = @intFromFloat(@round(255 * c.a));
        }
    }
}

pub fn textSize(self: *PixelBuffer, text: []const u8) cherry.Rect {
    _ = self;
    _ = text;
}

pub fn renderText(self: *PixelBuffer, text: []const u8, pos: cherry.Pos) void {
    _ = pos;
    _ = self;
    _ = text;
}

pub fn calcSize(size: cherry.Rect, padding: cherry.StyleRect, border: cherry.StyleRect) cherry.Rect {
    return .{
        .w = size.w + padding.right + padding.left + border.left + border.right,
        .h = size.w + padding.top + padding.bottom + border.bottom + border.top,
    };
}

pub fn fill(self: *PixelBuffer, color: cherry.Color) void {
    for (@floor(self.buf.len/4)) |px| {
        const base = px*4;
        self.buf[base] = color.r;
        self.buf[base+1] = color.g;
        self.buf[base+2] = color.b;
        self.buf[base+3] = color.a;
    }
}

pub fn deinit(self: *PixelBuffer, alloc: std.mem.Allocator) void {
    alloc.free(self.buf);
}
