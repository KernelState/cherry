const std = @import("std");
const cherry = @import("cherry.zig");

id: cherry.Id,
data: Options,
buf: *cherry.PixelBuffer,
renderer: Renderer,
db: *cherry.Db,
minimized: bool = false,
child: ?cherry.Widget = null,

const Window = @This();

/// All what this does is display a pixel buffer and help manage the Window
/// on the OS side.
pub const Renderer = struct {
    /// This pointer should be set by the renderer itself
    /// to preserve anonymity of the renderer and prevent renderer specific
    /// memory bugs.
    data: *anyopaque = undefined,
    initFn: *const fn (*anyopaque, std.mem.Allocator) anyerror!void,
    createWindowFn: *const fn (*anyopaque, *Options) anyerror!void,
    drawBufferFn: *const fn (*anyopaque, *cherry.PixelBuffer) anyerror!void,
    closeWindowFn: *const fn (*anyopaque) anyerror!void,
    shouldCloseFn: *const fn (*anyopaque) bool,
    isMinimizedFn: *const fn (*anyopaque) bool,
    deinitFn: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn init(self: *Renderer, alloc: std.mem.Allocator) !void {
        return self.initFn(self.data, alloc);
    }

    pub fn createWindow(self: *Renderer, w: *Window) !void {
        return self.createWindowFn(self.data, w);
    }

    pub fn drawBuffer(self: *Renderer, buf: *cherry.PixelBuffer) !void {
        return self.createWindowFn(self.data, buf);
    }

    pub fn closeWindow(self: *Renderer) !void {
        return self.closeWindowFn(self.data);
    }

    pub fn shouldClose(self: *Renderer) bool {
        return self.shouldCloseFn(self.data);
    }

    pub fn isMinimized(self: *Renderer) bool {
        return self.isMinimizedFn(self.data);
    }

    pub fn deinit(self: *Renderer, alloc: std.mem.Allocator) void {
        self.deinitFn(self.data, alloc);
    }
};

pub const Options = struct {
    title: []const u8,
    //icon: cherry.Image,
    size: cherry.Rect,
    position: ?cherry.Pos,
    transparent: bool = true,
};

pub fn init(alloc: std.mem.Allocator, buf: cherry.PixelBuffer, renderer: Renderer, opts: Options) !Window {
    var self = Window{
        .renderer = renderer,
        .buf = buf,
        .data = opts,
        .id = cherry.genId(),
    };
    self.renderer.init(alloc);
    if (self.data.transparent) 
        self.buf.fill(.transparent)
    else 
        self.buf.fill(.fromHex("000000"));
    return self;
}

pub fn createWindow(self: *Window) void {
    self.renderer.createWindow(self.data);
}

pub fn drawBuffer(self: *Window) void {
    self.renderer.drawBuffer(self.buf);
}

pub fn deinit(self: *Window, alloc: std.mem.Allocator) void {
    self.renderer.deinit(alloc);
}
