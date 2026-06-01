/// A wacky solution to fonts but it works.
const std = @import("std");
const cherry = @import("../cherry.zig");
const PixelBuffer = @import("../PixelBuffer.zig");
const c = @cImport({
    @cInclude("harfbuzz/hb.h");
    @cInclude("harfbuzz/hb-ft.h");
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
});

ftLib: c.FT_Library,
face: c.FT_Face,
hbFont: *c.hb_font_t,
buf: *c.hb_buffer_t,

const TextRenderer = @This();

pub fn init(fontData: []const u8, fontSize: u32) !TextRenderer {
    var ftLib: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&ftLib) != 0) return error.FreetypeInit;
    errdefer _ = c.FT_Done_FreeType(ftLib);

    var face: c.FT_Face = undefined;
    if (c.FT_New_Memory_Face(ftLib, fontData.ptr, @as(c.FT_Long, @intCast(fontData.len)), @as(c.FT_Long, 0), &face) != 0)
        return error.FontLoad;
    errdefer _ = c.FT_Done_Face(face);

    if (c.FT_Set_Pixel_Sizes(face, 0, fontSize) != 0) return error.FontSize;

    const hbFont = c.hb_ft_font_create(face, null) orelse return error.HbFont;
    errdefer c.hb_font_destroy(hbFont);

    const buf = c.hb_buffer_create() orelse return error.HbBuffer;

    return .{ .ftLib = ftLib, .face = face, .hbFont = hbFont, .buf = buf };
}

pub fn render(self: *TextRenderer, pb: *PixelBuffer, text: []const u8, pos: cherry.Pos, color: cherry.Color) void {
    c.hb_buffer_clear_contents(self.buf);
    c.hb_buffer_add_utf8(self.buf, text.ptr, @intCast(text.len), 0, -1);
    c.hb_buffer_guess_segment_properties(self.buf);
    c.hb_shape(self.hbFont, self.buf, null, 0);

    var glyphCount: c_uint = undefined;
    const infos = c.hb_buffer_get_glyph_infos(self.buf, &glyphCount);
    const positions = c.hb_buffer_get_glyph_positions(self.buf, &glyphCount);

    const ascender = @as(i32, @intCast(self.face.*.size.*.metrics.ascender >> 6));
    const baseY = @as(i32, @intCast(pos.y)) + ascender;
    var penX: i32 = 0;

    for (0..glyphCount) |i| {
        const xAdv = @as(i32, @intCast(positions[i].x_advance >> 6));

        if (c.FT_Load_Glyph(self.face, @intCast(infos[i].codepoint), c.FT_LOAD_RENDER) != 0) {
            penX += xAdv;
            continue;
        }

        const slot = self.face.*.glyph.*;
        if (slot.bitmap.buffer) |bmp| {
            const gx = @as(i32, @intCast(pos.x)) + penX + slot.bitmap_left;
            const gy = baseY - slot.bitmap_top;
            const bw = @as(u32, @intCast(slot.bitmap.width));
            const bh = @as(u32, @intCast(slot.bitmap.rows));
            const stride = @as(u32, @intCast(slot.bitmap.pitch));

            for (0..bh) |row| {
                const py = gy + @as(i32, @intCast(row));
                if (py < 0 or py >= @as(i32, @intCast(pb.size.h))) continue;
                for (0..bw) |col| {
                    const px = gx + @as(i32, @intCast(col));
                    if (px < 0 or px >= @as(i32, @intCast(pb.size.w))) continue;
                    const a = bmp[row * stride + col];
                    if (a == 0) continue;
                    const idx = @as(usize, @intCast(py * @as(i32, @intCast(pb.size.w)) + px)) * 4;
                    if (a == 255) {
                        pb.buf[idx+0] = color.r;
                        pb.buf[idx+1] = color.g;
                        pb.buf[idx+2] = color.b;
                        pb.buf[idx+3] = @floor(color.a * 255);
                    } else {
                        const alpha = @as(f32, @floatFromInt(a)) / 255.0;
                        const inv = 1.0 - alpha;
                        pb.buf[idx+0] = @intFromFloat(@as(f32, @floatFromInt(pb.buf[idx+0])) * inv + @as(f32, @floatFromInt(color.r)) * alpha);
                        pb.buf[idx+1] = @intFromFloat(@as(f32, @floatFromInt(pb.buf[idx+1])) * inv + @as(f32, @floatFromInt(color.g)) * alpha);
                        pb.buf[idx+2] = @intFromFloat(@as(f32, @floatFromInt(pb.buf[idx+2])) * inv + @as(f32, @floatFromInt(color.b)) * alpha);
                        pb.buf[idx+3] = @floor(color.a * 255);
                    }
                }
            }
        }
        penX += xAdv;
    }
}

pub fn textSize(self: *TextRenderer, text: []const u8) cherry.Rect {
    c.hb_buffer_clear_contents(self.buf);
    c.hb_buffer_add_utf8(self.buf, text.ptr, @intCast(text.len), 0, -1);
    c.hb_buffer_guess_segment_properties(self.buf);
    c.hb_shape(self.hbFont, self.buf, null, 0);

    var glyphCount: c_uint = undefined;
    const positions = c.hb_buffer_get_glyph_positions(self.buf, &glyphCount);

    var w: u32 = 0;
    for (0..glyphCount) |i| {
        w = @intCast(@as(u64, w) + @as(u64, @intCast(positions[i].x_advance >> 6)));
    }

    const metrics = self.face.*.size.*.metrics;
    const h = @as(u32, @intCast((metrics.ascender - metrics.descender) >> 6));
    return .{ .w = w, .h = h };
}

pub fn deinit(self: *TextRenderer) void {
    c.hb_buffer_destroy(self.buf);
    c.hb_font_destroy(self.hbFont);
    c.FT_Done_Face(self.face);
    c.FT_Done_FreeType(self.ftLib);
}
