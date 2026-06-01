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
alloc: std.mem.Allocator,

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

    const dst = @as([*]u8, @ptrCast(pixels.?))[0..pb.buf.len];
    @memcpy(dst, pb.buf);

    c.SDL_UnlockTexture(self.texture);

    _ = c.SDL_RenderClear(self.renderer);
    _ = c.SDL_RenderTexture(self.renderer, self.texture, null, null);
    _ = c.SDL_RenderPresent(self.renderer);
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
    var e: c.SDL_Event = undefined;
    while (c.SDL_PeepEvents(&e, 1, c.SDL_GETEVENT, c.SDL_EVENT_QUIT, c.SDL_EVENT_QUIT) > 0)
        return true;
    // also check if window was closed
    _ = self;
    var peek: c.SDL_Event = undefined;
    if (c.SDL_PeepEvents(&peek, 1, c.SDL_PEEKEVENT, c.SDL_EVENT_QUIT, c.SDL_EVENT_QUIT) > 0)
        return true;
    return false;
}

pub fn deinit(self: *VulkanRenderer) void {
    if (self.texture) |t| c.SDL_DestroyTexture(t);
    if (self.initialized) {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
    }
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
        c.SDLK_q          => .q,
        c.SDLK_w          => .w,
        c.SDLK_e          => .e,
        c.SDLK_r          => .r,
        c.SDLK_t          => .t,
        c.SDLK_y          => .y,
        c.SDLK_u          => .u,
        c.SDLK_i          => .i,
        c.SDLK_o          => .o,
        c.SDLK_p          => .p,
        c.SDLK_LEFTBRACKET  => .sqLParen,
        c.SDLK_RIGHTBRACKET => .sqRParen,
        c.SDLK_BACKSLASH  => .backslash,
        c.SDLK_a          => .a,
        c.SDLK_s          => .s,
        c.SDLK_d          => .d,
        c.SDLK_f          => .f,
        c.SDLK_g          => .g,
        c.SDLK_h          => .h,
        c.SDLK_j          => .j,
        c.SDLK_k          => .k,
        c.SDLK_l          => .l,
        c.SDLK_SEMICOLON  => .colon,
        c.SDLK_APOSTROPHE => .quote,
        c.SDLK_CAPSLOCK   => .capslock,
        c.SDLK_LSHIFT     => .lshift,
        c.SDLK_RSHIFT     => .rshift,
        c.SDLK_z          => .z,
        c.SDLK_x          => .x,
        c.SDLK_c          => .c,
        c.SDLK_v          => .v,
        c.SDLK_b          => .b,
        c.SDLK_n          => .n,
        c.SDLK_m          => .m,
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
