const std = @import("std");
const cherry = @import("cherry.zig");
const TextRenderer = @import("rendering/TextRenderer.zig");

buf: []u8,
tr: ?TextRenderer = null,
size: cherry.Rect,

const PixelBuffer = @This();

pub fn new(alloc: std.mem.Allocator, size: cherry.Rect) !PixelBuffer {
    return .{
        .buf = try alloc.alloc(u8, 4 * size.w * size.h),
        .size = size,
        .tr = null,
    };
}

pub fn newWithFont(alloc: std.mem.Allocator, size: cherry.Rect, comptime fontBytes: []const u8, fontSize: u32) !PixelBuffer {
    var pb = try new(alloc, size);
    pb.tr = try TextRenderer.init(fontBytes, fontSize);
    return pb;
}

pub fn index(self: *PixelBuffer, pos: cherry.Pos) usize {
    return ((pos.y * self.size.w) + pos.x) * 4;
}

pub fn subBuffer(self: *PixelBuffer, pos: cherry.Pos, sz: cherry.Rect) PixelBuffer {
    const end = cherry.Pos{
        .x = pos.x + sz.w,
        .y = pos.y + sz.h,
    };
    return .{
        .size = sz,
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

fn pickRadius(dx: f64, dy: f64, rt: f64, rr: f64, rb: f64, rl: f64) f64 {
    if (dy < 0.0) return if (dx < 0.0) rt else rr;
    return if (dx < 0.0) rb else rl;
}

fn sdRoundRect(px: f64, py: f64, cx: f64, cy: f64, hw: f64, hh: f64, rt: f64, rr: f64, rb: f64, rl: f64) f64 {
    const dx = px - cx;
    const dy = py - cy;
    const adx = @abs(dx);
    const ady = @abs(dy);
    const r = pickRadius(dx, dy, rt, rr, rb, rl);
    const ex = adx - (hw - r);
    const ey = ady - (hh - r);
    const mq = @min(@max(ex, ey), 0.0);
    const xe = @max(ex, 0.0);
    const ye = @max(ey, 0.0);
    return mq + @sqrt(xe * xe + ye * ye) - r;
}

pub fn rect(self: *PixelBuffer, opts: RectOptions) void {
    const w = opts.size.w;
    const h = opts.size.h;
    if (w == 0 or h == 0) return;

    const bx = opts.pos.x;
    const by = opts.pos.y;
    const stride = self.size.w;

    const max_r = @min(w, h) / 2;
    const r_tl = @min(opts.borderRadius.topLeft, max_r);
    const r_tr = @min(opts.borderRadius.topRight, max_r);
    const r_bl = @min(opts.borderRadius.bottomLeft, max_r);
    const r_br = @min(opts.borderRadius.bottomRight, max_r);

    const b_t = @min(opts.borderSize.top, h);
    const b_b = @min(opts.borderSize.bottom, h);
    const b_l = @min(opts.borderSize.left, w);
    const b_r = @min(opts.borderSize.right, w);

    const iw = w -| b_l -| b_r;
    const ih = h -| b_t -| b_b;
    const has_inner = iw > 0 and ih > 0;

    const ir_tl = if (has_inner and r_tl > 0) r_tl else 0;
    const ir_tr = if (has_inner and r_tr > 0) r_tr else 0;
    const ir_bl = if (has_inner and r_bl > 0) r_bl else 0;
    const ir_br = if (has_inner and r_br > 0) r_br else 0;

    const bc = opts.borderColor;
    const bg = opts.backgroundColor;
    const bcr = @as(f64, @floatFromInt(bc.r));
    const bcg = @as(f64, @floatFromInt(bc.g));
    const bcb = @as(f64, @floatFromInt(bc.b));
    const bgr = @as(f64, @floatFromInt(bg.r));
    const bgg = @as(f64, @floatFromInt(bg.g));
    const bgb = @as(f64, @floatFromInt(bg.b));

    const cx = @as(f64, @floatFromInt(w)) / 2.0;
    const cy = @as(f64, @floatFromInt(h)) / 2.0;
    const hw = cx;
    const hh = cy;

    const rtl = @as(f64, @floatFromInt(r_tl));
    const rtr = @as(f64, @floatFromInt(r_tr));
    const rbl = @as(f64, @floatFromInt(r_bl));
    const rbr = @as(f64, @floatFromInt(r_br));

    const icxf = if (has_inner) @as(f64, @floatFromInt(b_l)) + @as(f64, @floatFromInt(iw)) / 2.0 else 0.0;
    const icyf = if (has_inner) @as(f64, @floatFromInt(b_t)) + @as(f64, @floatFromInt(ih)) / 2.0 else 0.0;
    const ihwf = if (has_inner) @as(f64, @floatFromInt(iw)) / 2.0 else 0.0;
    const ihhf = if (has_inner) @as(f64, @floatFromInt(ih)) / 2.0 else 0.0;

    const irtl = @as(f64, @floatFromInt(ir_tl));
    const irtr = @as(f64, @floatFromInt(ir_tr));
    const irbl = @as(f64, @floatFromInt(ir_bl));
    const irbr = @as(f64, @floatFromInt(ir_br));

    var py: u32 = 0;
    while (py < h) : (py += 1) {
        var px: u32 = 0;
        while (px < w) : (px += 1) {
            const pxf = @as(f64, @floatFromInt(px)) + 0.5;
            const pyf = @as(f64, @floatFromInt(py)) + 0.5;

            const sdf_o = sdRoundRect(pxf, pyf, cx, cy, hw, hh, rtl, rtr, rbl, rbr);
            const cov_o = @min(1.0, @max(0.0, 0.5 - sdf_o));
            if (cov_o <= 0.0) continue;

            const cov_i = if (has_inner) blk: {
                const sdf_i = sdRoundRect(pxf, pyf, icxf, icyf, ihwf, ihhf, irtl, irtr, irbl, irbr);
                break :blk @min(1.0, @max(0.0, 0.5 - sdf_i));
            } else 0.0;

            const base = ((by + py) * stride + (bx + px)) * 4;
            const or_ = @as(f64, @floatFromInt(self.buf[base + 0]));
            const og_ = @as(f64, @floatFromInt(self.buf[base + 1]));
            const ob_ = @as(f64, @floatFromInt(self.buf[base + 2]));

            const bw = cov_o - cov_i;
            const bgw = cov_i;
            const ow = 1.0 - cov_o;

            self.buf[base + 0] = @as(u8, @intFromFloat(@round(bcr * bw + bgr * bgw + or_ * ow)));
            self.buf[base + 1] = @as(u8, @intFromFloat(@round(bcg * bw + bgg * bgw + og_ * ow)));
            self.buf[base + 2] = @as(u8, @intFromFloat(@round(bcb * bw + bgb * bgw + ob_ * ow)));
            self.buf[base + 3] = 0xFF;
        }
    }
}

pub fn text(self: *PixelBuffer, txt: []const u8, pos: cherry.Pos, color: cherry.Color) void {
    if (self.tr) |*tr| tr.render(self, txt, pos, color);
}

pub fn textSize(self: *PixelBuffer, txt: []const u8) cherry.Rect {
    if (self.tr) |*tr| return tr.textSize(txt);
    return .{ .w = 0, .h = 0 };
}

pub fn calcSize(size: cherry.Rect, padding: cherry.StyleRect, border: cherry.StyleRect) cherry.Rect {
    return .{
        .w = size.w + padding.right + padding.left + border.left + border.right,
        .h = size.h + padding.top + padding.bottom + border.bottom + border.top,
    };
}

pub fn resize(self: *PixelBuffer, alloc: std.mem.Allocator, newSize: cherry.Rect) !void {
    alloc.free(self.buf);
    self.buf = try alloc.alloc(u8, 4 * newSize.w * newSize.h);
    self.size = newSize;
}

pub fn fill(self: *PixelBuffer, color: cherry.Color) void {
    const a8: u8 = @intFromFloat(@floor(255.0 * color.a));
    @memset(self.buf, 0);
    var i: usize = 0;
    while (i < self.buf.len) : (i += 4) {
        self.buf[i + 0] = color.r;
        self.buf[i + 1] = color.g;
        self.buf[i + 2] = color.b;
        self.buf[i + 3] = a8;
    }
}

pub fn deinit(self: *PixelBuffer, alloc: std.mem.Allocator) void {
    if (self.tr) |*tr| tr.deinit();
    alloc.free(self.buf);
}
