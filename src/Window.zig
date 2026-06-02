const std = @import("std");
const cherry = @import("cherry.zig");

id: cherry.Id,
data: Options,
buf: *cherry.PixelBuffer,
renderer: Renderer,
db: ?*cherry.Db = null,
minimized: bool = false,
child: ?cherry.Widget = null,
appdata: ?*anyopaque,
update: ?*const fn (*anyopaque, Message, std.Io, std.mem.Allocator) anyerror!void = null,
view: ?*const fn (*const anyopaque, *cherry.PixelBuffer) void = null,

const Window = @This();

pub const Message = union(enum) {
    event: cherry.Event,
    msg: *anyopaque,
};

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
    swapBuffersFn: *const fn (*anyopaque) void,
    pollEventsFn: *const fn (*anyopaque, *std.ArrayList(cherry.Event)) void,
    setSizeFn: *const fn (*anyopaque, cherry.Rect) anyerror!void,
    getSizeFn: *const fn (*anyopaque) cherry.Rect,
    setTitleFn: *const fn (*anyopaque, []const u8) void,
    closeWindowFn: *const fn (*anyopaque) anyerror!void,
    shouldCloseFn: *const fn (*anyopaque) bool,
    isMinimizedFn: *const fn (*anyopaque) bool,
    deinitFn: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn init(self: *Renderer, alloc: std.mem.Allocator) !void {
        return self.initFn(self.data, alloc);
    }

    pub fn createWindow(self: *Renderer, w: *Options) !void {
        return self.createWindowFn(self.data, w);
    }

    pub fn drawBuffer(self: *Renderer, buf: *cherry.PixelBuffer) !void {
        return self.drawBufferFn(self.data, buf);
    }

    pub fn swapBuffers(self: *Renderer) void {
        return self.swapBuffersFn(self.data);
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

    pub fn pollEvents(self: *Renderer, a: *std.ArrayList(cherry.Event)) void {
        return self.pollEventsFn(self.data, a);
    }

    pub fn setSize(self: *Renderer, r: cherry.Rect) void {
        return self.setSizeFn(self.data, r);
    }

    pub fn getSize(self: *Renderer) cherry.Rect {
        return self.getSizeFn(self.data);
    }

    pub fn setTitle(self: *Renderer, title: []const u8) void {
        return self.setTitleFn(self.data, title);
    }

    pub fn deinit(self: *Renderer, alloc: std.mem.Allocator) void {
        self.deinitFn(self.data, alloc);
    }

    pub fn fromStruct(instance: anytype) Renderer {
        const T = @TypeOf(instance);
        if (@hasField(T, "renderer_impl"))
            return @field(instance, "renderer_impl");
        @compileError("Struct `" ++ @typeName(T) ++ "` does not have field `renderer_impl`");
    }
};

pub const Options = struct {
    title: []const u8,
    //icon: cherry.Image,
    size: cherry.Rect,
    position: ?cherry.Pos,
    transparent: bool = true,
};

pub fn init(alloc: std.mem.Allocator, buf: *cherry.PixelBuffer, renderer: Renderer, opts: Options) !Window {
    var self = Window{
        .renderer = renderer,
        .buf = buf,
        .data = opts,
        .id = cherry.genId(),
    };
    try self.renderer.init(alloc);
    self.buf.fill(if (self.data.transparent) .transparent else .black);
    return self;
}

pub fn createWindow(self: *Window) !void {
    try self.renderer.createWindow(&self.data);
}

pub fn drawBuffer(self: *Window) !void {
    try self.renderer.drawBuffer(self.buf);
}

pub fn swapBuffers(self: *Window) void {
    self.renderer.swapBuffers();
}

pub fn closeWindow(self: *Window) !void {
    try self.renderer.closeWindow();
}

pub fn shouldClose(self: *Window) bool {
    return self.renderer.shouldClose();
}

pub fn deinit(self: *Window, alloc: std.mem.Allocator) void {
    self.renderer.deinit(alloc);
}

pub fn setSize(self: *Window, r: cherry.Rect) !void {
    try self.renderer.setSize(r);
}

pub fn getSize(self: *Window) cherry.Rect {
    return self.renderer.getSize();
}

pub fn setTitle(self: *Window, title: []const u8) void {
    self.renderer.setTitle(title);
}

pub fn pollEvents(self: *Window, a: *std.ArrayList(cherry.Event)) void {
    self.renderer.pollEvents(a);
}

pub fn run(self: *Window, alloc: std.mem.Allocator, io: std.Io) !void {
    var buf = try cherry.PixelBuffer.new(alloc, .{ .w = 800, .h = 600 });
    defer buf.deinit(alloc);

    try self.createWindow();

    var events: std.ArrayList(cherry.Event) = .empty;
    defer events.deinit(alloc);

    while (!self.shouldClose()) {
        events.clearRetainingCapacity();
        self.pollEvents(&events);

        for (events.items) |ev| {
            try self.update.?(self.appdata, .{ .event = ev }, io, alloc);
        }

        self.view.?(self.appdata, self.buf);
        try self.drawBuffer();
        self.swapBuffers();
    }

    self.closeWindow();
}
