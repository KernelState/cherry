const std = @import("std");
const cherry = @import("../cherry.zig");
const Window = @import("../Window.zig");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

alloc: std.mem.Allocator,
window: ?*c.SDL_Window,
sdl_renderer: ?*c.SDL_Renderer,
texture: ?*c.SDL_Texture,
title: ?[]u8,
_should_close: bool,
_size: cherry.Rect,

const SDL3Renderer = @This();

pub fn create(allocator: std.mem.Allocator) !Window.Renderer {
    const self = try allocator.create(SDL3Renderer);
    self.* = SDL3Renderer{
        .alloc = allocator,
        .window = null,
        .sdl_renderer = null,
        .texture = null,
        .title = null,
        ._should_close = false,
        ._size = .{ .w = 0, .h = 0 },
    };
    return Window.Renderer{
        .data = self,
        .initFn = implInit,
        .createWindowFn = implCreateWindow,
        .drawBufferFn = implDrawBuffer,
        .swapBuffersFn = implSwapBuffers,
        .pollEventsFn = implPollEvents,
        .setSizeFn = implSetSize,
        .getSizeFn = implGetSize,
        .setTitleFn = implSetTitle,
        .closeWindowFn = implCloseWindow,
        .shouldCloseFn = implShouldClose,
        .isMinimizedFn = implIsMinimized,
        .deinitFn = implDeinit,
    };
}

fn cast(data: *anyopaque) *SDL3Renderer {
    return @ptrCast(@alignCast(data));
}

fn implInit(data: *anyopaque, alloc: std.mem.Allocator) !void {
    _ = alloc;
    _ = cast(data);
    if (!c.SDL_Init(c.SDL_INIT_VIDEO))
        return error.SDLInitFailed;
}

fn implCreateWindow(data: *anyopaque, opts: *Window.Options) !void {
    const self = cast(data);
    if (self.title) |old| self.alloc.free(old);
    const title_z = try self.alloc.alloc(u8, opts.title.len + 1);
    @memcpy(title_z[0..opts.title.len], opts.title);
    title_z[opts.title.len] = 0;
    self.title = title_z;

    const w = c.SDL_CreateWindow(
        @ptrCast(title_z.ptr),
        @intCast(opts.size.w),
        @intCast(opts.size.h),
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIDDEN,
    ) orelse return error.SDLCreateWindowFailed;

    const r = c.SDL_CreateRenderer(w, null) orelse return error.SDLCreateRendererFailed;

    const t = c.SDL_CreateTexture(
        r,
        c.SDL_PIXELFORMAT_RGBA8888,
        c.SDL_TEXTUREACCESS_STREAMING,
        @intCast(opts.size.w),
        @intCast(opts.size.h),
    ) orelse return error.SDLCreateTextureFailed;

    self.window = w;
    self.sdl_renderer = r;
    self.texture = t;
    self._size = opts.size;

    _ = c.SDL_ShowWindow(w);
}

fn implDrawBuffer(data: *anyopaque, buf: *cherry.PixelBuffer) !void {
    const self = cast(data);
    const tex = self.texture orelse return;
    const need_resize = buf.size.w != self._size.w or buf.size.h != self._size.h;
    if (need_resize) {
        c.SDL_DestroyTexture(tex);
        self.texture = c.SDL_CreateTexture(
            self.sdl_renderer orelse return,
            c.SDL_PIXELFORMAT_RGBA8888,
            c.SDL_TEXTUREACCESS_STREAMING,
            @intCast(buf.size.w),
            @intCast(buf.size.h),
        );
        self._size = buf.size;
    }
    const tex2 = self.texture orelse return;
    _ = c.SDL_UpdateTexture(tex2, null, buf.buf.ptr, @intCast(buf.size.w * 4));
}

fn implSwapBuffers(data: *anyopaque) void {
    const self = cast(data);
    const r = self.sdl_renderer orelse return;
    const t = self.texture orelse return;
    _ = c.SDL_SetRenderDrawColor(r, 0, 0, 0, 255);
    _ = c.SDL_RenderClear(r);
    _ = c.SDL_RenderTexture(r, t, null, null);
    _ = c.SDL_RenderPresent(r);
}

fn implPollEvents(data: *anyopaque, out: *std.ArrayList(cherry.Event)) void {
    const self = cast(data);
    var sdl_ev: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&sdl_ev)) {
        switch (sdl_ev.type) {
            c.SDL_EVENT_QUIT => self._should_close = true,
            c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => self._should_close = true,
            c.SDL_EVENT_WINDOW_RESIZED => {
                self._size = .{
                    .w = @intCast(sdl_ev.window.data1),
                    .h = @intCast(sdl_ev.window.data2),
                };
                if (self.texture) |tex| c.SDL_DestroyTexture(tex);
                self.texture = c.SDL_CreateTexture(
                    self.sdl_renderer orelse return,
                    c.SDL_PIXELFORMAT_RGBA8888,
                    c.SDL_TEXTUREACCESS_STREAMING,
                    @intCast(self._size.w),
                    @intCast(self._size.h),
                );
                out.append(self.alloc, .{ .windowResized = self._size }) catch {};
            },
            c.SDL_EVENT_KEY_DOWN => {
                if (mapKeycode(sdl_ev.key.key)) |kc|
                    out.append(self.alloc, .{ .keyPressed = kc }) catch {};
            },
            c.SDL_EVENT_MOUSE_MOTION => {
                out.append(self.alloc, .{ .mouseMove = .{
                    .x = @intFromFloat(@max(0, sdl_ev.motion.x)),
                    .y = @intFromFloat(@max(0, sdl_ev.motion.y)),
                } }) catch {};
            },
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                out.append(self.alloc, .{ .mouseClick = true }) catch {};
            },
            c.SDL_EVENT_MOUSE_BUTTON_UP => {
                out.append(self.alloc, .{ .mouseClick = false }) catch {};
            },
            c.SDL_EVENT_MOUSE_WHEEL => {
                out.append(self.alloc, .{ .mouseScroll = @intCast(@abs(sdl_ev.wheel.integer_y)) }) catch {};
            },
            c.SDL_EVENT_WINDOW_MINIMIZED => {},
            c.SDL_EVENT_WINDOW_RESTORED => {},
            else => {},
        }
    }
}

fn implSetSize(data: *anyopaque, size: cherry.Rect) !void {
    const self = cast(data);
    if (self.window) |w| {
        if (!c.SDL_SetWindowSize(w, @intCast(size.w), @intCast(size.h)))
            return error.SDLSetWindowSizeFailed;
    }
}

fn implGetSize(data: *anyopaque) cherry.Rect {
    const self = cast(data);
    if (self.window) |w| {
        var ww: c_int = undefined;
        var wh: c_int = undefined;
        _ = c.SDL_GetWindowSize(w, &ww, &wh);
        return .{ .w = @intCast(ww), .h = @intCast(wh) };
    }
    return self._size;
}

fn implSetTitle(data: *anyopaque, title: []const u8) void {
    const self = cast(data);
    if (self.title) |old| self.alloc.free(old);
    self.title = null;
    if (self.window) |w| {
        const title_z = self.alloc.alloc(u8, title.len + 1) catch return;
        @memcpy(title_z[0..title.len], title);
        title_z[title.len] = 0;
        self.title = title_z;
        _ = c.SDL_SetWindowTitle(w, @ptrCast(title_z.ptr));
    }
}

fn implCloseWindow(data: *anyopaque) !void {
    const self = cast(data);
    self._should_close = true;
}

fn implShouldClose(data: *anyopaque) bool {
    return cast(data)._should_close;
}

fn implIsMinimized(data: *anyopaque) bool {
    const self = cast(data);
    if (self.window) |w|
        return c.SDL_GetWindowFlags(w) & c.SDL_WINDOW_MINIMIZED != 0;
    return false;
}

fn implDeinit(data: *anyopaque, alloc: std.mem.Allocator) void {
    const self = cast(data);
    if (self.texture) |t| c.SDL_DestroyTexture(t);
    if (self.sdl_renderer) |r| c.SDL_DestroyRenderer(r);
    if (self.window) |w| c.SDL_DestroyWindow(w);
    if (self.title) |t| alloc.free(t);
    c.SDL_Quit();
    alloc.destroy(self);
}

fn mapKeycode(sdl_key: c.SDL_Keycode) ?cherry.Event.Keycode {
    return switch (sdl_key) {
        c.SDLK_ESCAPE => .esc,
        c.SDLK_F1 => .f1,
        c.SDLK_F2 => .f2,
        c.SDLK_F3 => .f3,
        c.SDLK_F4 => .f4,
        c.SDLK_F5 => .f5,
        c.SDLK_F6 => .f6,
        c.SDLK_F7 => .f7,
        c.SDLK_F8 => .f8,
        c.SDLK_F9 => .f9,
        c.SDLK_F10 => .f10,
        c.SDLK_F11 => .f11,
        c.SDLK_F12 => .f12,
        c.SDLK_BACKSPACE => .backspace,
        c.SDLK_TAB => .tab,
        c.SDLK_PAUSE => .pause,
        c.SDLK_INSERT => .insert,
        c.SDLK_HOME => .home,
        c.SDLK_PAGEUP => .pageUp,
        c.SDLK_PAGEDOWN => .pageDown,
        c.SDLK_END => .end,
        c.SDLK_PRINTSCREEN => .printScreen,
        c.SDLK_SCROLLLOCK => .screenLock,
        c.SDLK_CAPSLOCK => .capslock,
        c.SDLK_LSHIFT => .lshift,
        c.SDLK_RSHIFT => .rshift,
        c.SDLK_LCTRL => .lctrl,
        c.SDLK_RCTRL => .rctrl,
        c.SDLK_LALT => .lalt,
        c.SDLK_LGUI => .win,
        c.SDLK_RGUI => .function,
        c.SDLK_APPLICATION => .appKey,
        c.SDLK_SPACE => .space,
        c.SDLK_LEFT => .arrowLeft,
        c.SDLK_RIGHT => .arrowRight,
        c.SDLK_UP => .arrowUp,
        c.SDLK_DOWN => .arrowDown,
        c.SDLK_A => .a,
        c.SDLK_B => .b,
        c.SDLK_C => .c,
        c.SDLK_D => .d,
        c.SDLK_E => .e,
        c.SDLK_F => .f,
        c.SDLK_G => .g,
        c.SDLK_H => .h,
        c.SDLK_I => .i,
        c.SDLK_J => .j,
        c.SDLK_K => .k,
        c.SDLK_L => .l,
        c.SDLK_M => .m,
        c.SDLK_N => .n,
        c.SDLK_O => .o,
        c.SDLK_P => .p,
        c.SDLK_Q => .q,
        c.SDLK_R => .r,
        c.SDLK_S => .s,
        c.SDLK_T => .t,
        c.SDLK_U => .u,
        c.SDLK_V => .v,
        c.SDLK_W => .w,
        c.SDLK_X => .x,
        c.SDLK_Y => .y,
        c.SDLK_Z => .z,
        c.SDLK_0 => .num0,
        c.SDLK_1 => .num1,
        c.SDLK_2 => .num2,
        c.SDLK_3 => .num3,
        c.SDLK_4 => .num4,
        c.SDLK_5 => .num5,
        c.SDLK_6 => .num6,
        c.SDLK_7 => .num7,
        c.SDLK_8 => .num8,
        c.SDLK_9 => .num9,
        c.SDLK_COMMA => .comma,
        c.SDLK_PERIOD => .dot,
        c.SDLK_GRAVE => .backstick,
        c.SDLK_SLASH => .slash,
        c.SDLK_SEMICOLON => .colon,
        c.SDLK_APOSTROPHE => .quote,
        c.SDLK_LEFTBRACKET => .sqLParen,
        c.SDLK_RIGHTBRACKET => .sqRParen,
        c.SDLK_BACKSLASH => .backslash,
        c.SDLK_MINUS => .dash,
        c.SDLK_EQUALS => .equal,
        else => null,
    };
}
