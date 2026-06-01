// This is actually SDL cuz I gave up on vulkan glfw
const std = @import("std");
const cherry = @import("cherry.zig");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,
texture: ?*c.SDL_Texture,
texture_w: u32,
texture_h: u32,
event_buf: [10]cherry.Event,
event_count: usize,
initialized: bool,
closed: bool,
alloc: std.mem.Allocator,
aa_scratch: []u8 = &[_]u8{},

const VulkanRenderer = @This();

pub fn init(alloc: std.mem.Allocator) !VulkanRenderer {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SDLInitFailed;
    return .{
        .alloc = alloc,
        .window = undefined,
        .renderer = undefined,
        .texture = null,
        .texture_w = 0,
        .texture_h = 0,
        .event_buf = undefined,
        .event_count = 0,
        .initialized = false,
        .closed = false,
    };
}

pub fn createWindow(self: *VulkanRenderer, win: *cherry.Window) !void {
    self.window = c.SDL_CreateWindow(
        win.title.ptr,
        @intCast(win.size.w),
        @intCast(win.size.h),
        0,
    ) orelse return error.WindowCreateFailed;

    self.renderer = c.SDL_CreateRenderer(self.window, null)
        orelse return error.RendererCreateFailed;

    self.initialized = true;
}

pub fn draw(self: *VulkanRenderer, pb: cherry.PixelBuffer) !void {
    // Ensure scratch buffer for AA
    const len = pb.buf.len;
    if (self.aa_scratch.len < len) {
        if (self.aa_scratch.len > 0) self.alloc.free(self.aa_scratch);
        self.aa_scratch = try self.alloc.alloc(u8, len);
    }
    @memcpy(self.aa_scratch[0..len], pb.buf);

    // recreate texture if size changed
    if (self.texture == null or self.texture_w != pb.size.w or self.texture_h != pb.size.h) {
        if (self.texture) |t| c.SDL_DestroyTexture(t);
        self.texture = c.SDL_CreateTexture(
            self.renderer,
            c.SDL_PIXELFORMAT_RGBA8888,
            c.SDL_TEXTUREACCESS_STREAMING,
            @intCast(pb.size.w),
            @intCast(pb.size.h),
        ) orelse return error.TextureCreateFailed;
        self.texture_w = pb.size.w;
        self.texture_h = pb.size.h;
    }

    var pixels: ?*anyopaque = null;
    var pitch: c_int = 0;
    if (!c.SDL_LockTexture(self.texture, null, &pixels, &pitch))
        return error.TextureLockFailed;

    const dst = @as([*]u8, @ptrCast(pixels.?))[0..len];
    antiAlias(dst, self.aa_scratch[0..len], pb.size.w, pb.size.h);

    c.SDL_UnlockTexture(self.texture);

    _ = c.SDL_RenderClear(self.renderer);
    _ = c.SDL_RenderTexture(self.renderer, self.texture, null, null);
    _ = c.SDL_RenderPresent(self.renderer);
}

fn antiAlias(dst: []u8, src: []u8, w: u32, h: u32) void {
    if (w == 0 or h == 0) return;

    const threshold: f32 = 25.0 / 255.0;
    const stride = w * 4;

    for (0..h) |y| {
        for (0..w) |x| {
            const i = y * stride + x * 4;
            const a = src[i + 3];
            if (a == 0) {
                dst[i] = 0;
                dst[i+1] = 0;
                dst[i+2] = 0;
                dst[i+3] = 0;
                continue;
            }

            const r: f32 = @floatFromInt(src[i]);
            const g: f32 = @floatFromInt(src[i+1]);
            const b: f32 = @floatFromInt(src[i+2]);

            var max_diff: f32 = 0;
            var sum_r: f32 = 0;
            var sum_g: f32 = 0;
            var sum_b: f32 = 0;
            var count: u32 = 0;

            // Right
            if (x + 1 < w) {
                const ni = i + 4;
                const nr: f32 = @floatFromInt(src[ni]);
                const ng: f32 = @floatFromInt(src[ni+1]);
                const nb: f32 = @floatFromInt(src[ni+2]);
                const diff = (@abs(r - nr) + @abs(g - ng) + @abs(b - nb)) / (3.0 * 255.0);
                if (diff > threshold) {
                    max_diff = @max(max_diff, diff);
                    sum_r += nr;
                    sum_g += ng;
                    sum_b += nb;
                    count += 1;
                }
            }
            // Left
            if (x > 0) {
                const ni = i - 4;
                const nr: f32 = @floatFromInt(src[ni]);
                const ng: f32 = @floatFromInt(src[ni+1]);
                const nb: f32 = @floatFromInt(src[ni+2]);
                const diff = (@abs(r - nr) + @abs(g - ng) + @abs(b - nb)) / (3.0 * 255.0);
                if (diff > threshold) {
                    max_diff = @max(max_diff, diff);
                    sum_r += nr;
                    sum_g += ng;
                    sum_b += nb;
                    count += 1;
                }
            }
            // Down
            if (y + 1 < h) {
                const ni = i + stride;
                const nr: f32 = @floatFromInt(src[ni]);
                const ng: f32 = @floatFromInt(src[ni+1]);
                const nb: f32 = @floatFromInt(src[ni+2]);
                const diff = (@abs(r - nr) + @abs(g - ng) + @abs(b - nb)) / (3.0 * 255.0);
                if (diff > threshold) {
                    max_diff = @max(max_diff, diff);
                    sum_r += nr;
                    sum_g += ng;
                    sum_b += nb;
                    count += 1;
                }
            }
            // Up
            if (y > 0) {
                const ni = i - stride;
                const nr: f32 = @floatFromInt(src[ni]);
                const ng: f32 = @floatFromInt(src[ni+1]);
                const nb: f32 = @floatFromInt(src[ni+2]);
                const diff = (@abs(r - nr) + @abs(g - ng) + @abs(b - nb)) / (3.0 * 255.0);
                if (diff > threshold) {
                    max_diff = @max(max_diff, diff);
                    sum_r += nr;
                    sum_g += ng;
                    sum_b += nb;
                    count += 1;
                }
            }

            if (count > 0) {
                const weight = @min(1.0, max_diff * 2.0) * 0.25;
                const avg_r = sum_r / @as(f32, @floatFromInt(count));
                const avg_g = sum_g / @as(f32, @floatFromInt(count));
                const avg_b = sum_b / @as(f32, @floatFromInt(count));
                dst[i]   = @intFromFloat(@round(r * (1.0 - weight) + avg_r * weight));
                dst[i+1] = @intFromFloat(@round(g * (1.0 - weight) + avg_g * weight));
                dst[i+2] = @intFromFloat(@round(b * (1.0 - weight) + avg_b * weight));
                dst[i+3] = a;
            } else {
                dst[i]   = src[i];
                dst[i+1] = src[i+1];
                dst[i+2] = src[i+2];
                dst[i+3] = a;
            }
        }
    }
}

pub fn pollEvents(self: *VulkanRenderer) []cherry.Event {
    self.event_count = 0;
    var e: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&e)) {
        switch (e.type) {
            c.SDL_EVENT_MOUSE_MOTION => self.pushEvent(.{ .mouseMove = .{
                .x = @intFromFloat(e.motion.x),
                .y = @intFromFloat(e.motion.y),
            }}),
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => self.pushEvent(.{ .mouseClick = true }),
            c.SDL_EVENT_MOUSE_BUTTON_UP   => self.pushEvent(.{ .mouseClick = false }),
            c.SDL_EVENT_MOUSE_WHEEL => self.pushEvent(.{ .mouseScroll = 
                @intFromFloat(@abs(e.wheel.y))
            }),
            c.SDL_EVENT_QUIT => self.closed = true,
            c.SDL_EVENT_KEY_DOWN => {
                const keycode = sdlKeyToKeycode(e.key.key) orelse continue;
                self.pushEvent(.{ .keyPressed = keycode });
            },
            else => {},
        }
        if (self.event_count >= 10) break;
    }
    return self.event_buf[0..self.event_count];
}

pub fn shouldClose(self: *VulkanRenderer) bool {
    if (self.closed) return true;
    var e: c.SDL_Event = undefined;
    if (c.SDL_PeepEvents(&e, 1, c.SDL_GETEVENT, c.SDL_EVENT_QUIT, c.SDL_EVENT_QUIT) > 0) {
        self.closed = true;
        return true;
    }
    return false;
}

pub fn deinit(self: *VulkanRenderer) void {
    if (self.texture) |t| c.SDL_DestroyTexture(t);
    if (self.initialized) {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
    }
    if (self.aa_scratch.len > 0) self.alloc.free(self.aa_scratch);
    c.SDL_Quit();
}

fn pushEvent(self: *VulkanRenderer, event: cherry.Event) void {
    if (self.event_count >= 10) return;
    self.event_buf[self.event_count] = event;
    self.event_count += 1;
}

fn sdlKeyToKeycode(key: c.SDL_Keycode) ?cherry.Event.Keycode {
    return switch (key) {
        c.SDLK_ESCAPE     => .esc,
        c.SDLK_F1         => .f1,
        c.SDLK_F2         => .f2,
        c.SDLK_F3         => .f3,
        c.SDLK_F4         => .f4,
        c.SDLK_F5         => .f5,
        c.SDLK_F6         => .f6,
        c.SDLK_F7         => .f7,
        c.SDLK_F8         => .f8,
        c.SDLK_F9         => .f9,
        c.SDLK_F10        => .f10,
        c.SDLK_F11        => .f11,
        c.SDLK_F12        => .f12,
        c.SDLK_GRAVE      => .backstick,
        c.SDLK_0          => .num0,
        c.SDLK_1          => .num1,
        c.SDLK_2          => .num2,
        c.SDLK_3          => .num3,
        c.SDLK_4          => .num4,
        c.SDLK_5          => .num5,
        c.SDLK_6          => .num6,
        c.SDLK_7          => .num7,
        c.SDLK_8          => .num8,
        c.SDLK_9          => .num9,
        c.SDLK_MINUS      => .dash,
        c.SDLK_EQUALS     => .equal,
        c.SDLK_BACKSPACE  => .backspace,
        c.SDLK_TAB        => .tab,
        c.SDLK_Q          => .q,
        c.SDLK_W          => .w,
        c.SDLK_E          => .e,
        c.SDLK_R          => .r,
        c.SDLK_T          => .t,
        c.SDLK_Y          => .y,
        c.SDLK_U          => .u,
        c.SDLK_I          => .i,
        c.SDLK_O          => .o,
        c.SDLK_P          => .p,
        c.SDLK_LEFTBRACKET  => .sqLParen,
        c.SDLK_RIGHTBRACKET => .sqRParen,
        c.SDLK_BACKSLASH  => .backslash,
        c.SDLK_A          => .a,
        c.SDLK_S          => .s,
        c.SDLK_D          => .d,
        c.SDLK_F          => .f,
        c.SDLK_G          => .g,
        c.SDLK_H          => .h,
        c.SDLK_J          => .j,
        c.SDLK_K          => .k,
        c.SDLK_L          => .l,
        c.SDLK_SEMICOLON  => .colon,
        c.SDLK_APOSTROPHE => .quote,
        c.SDLK_CAPSLOCK   => .capslock,
        c.SDLK_LSHIFT     => .lshift,
        c.SDLK_RSHIFT     => .rshift,
        c.SDLK_Z          => .z,
        c.SDLK_X          => .x,
        c.SDLK_C          => .c,
        c.SDLK_V          => .v,
        c.SDLK_B          => .b,
        c.SDLK_N          => .n,
        c.SDLK_M          => .m,
        c.SDLK_COMMA      => .comma,
        c.SDLK_PERIOD     => .dot,
        c.SDLK_SLASH      => .slash,
        c.SDLK_LCTRL      => .lctrl,
        c.SDLK_RCTRL      => .rctrl,
        c.SDLK_LGUI       => .win,
        c.SDLK_SPACE      => .space,
        c.SDLK_LALT       => .lalt,
        c.SDLK_UP         => .arrowUp,
        c.SDLK_DOWN       => .arrowDown,
        c.SDLK_LEFT       => .arrowLeft,
        c.SDLK_RIGHT      => .arrowRight,
        c.SDLK_INSERT     => .insert,
        c.SDLK_HOME       => .home,
        c.SDLK_PAGEUP     => .pageUp,
        c.SDLK_PAGEDOWN   => .pageDown,
        c.SDLK_END        => .end,
        c.SDLK_PRINTSCREEN => .printScreen,
        c.SDLK_SCROLLLOCK => .screenLock,
        c.SDLK_PAUSE      => .pause,
        else              => null,
    };
}
