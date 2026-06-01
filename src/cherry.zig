const std = @import("std");
const expect = std.testing.expect;
pub const Db = @import("Db.zig");
pub const Theme = @import("Theme.zig");
pub const PixelBuffer = @import("PixelBuffer.zig");
pub const VulkanRenderer = @import("VulkanRenderer.zig");

const log = std.log.scoped(.cherry);
pub var rand = std.Random.DefaultPrng.init(1);

pub const ColorSet = struct {
    background: ?Color,
    primary: Color,
    secondary: Color,
    normal: Color,
    text: Color,
    border: Color,
};

pub const Palette = struct {
    base: ColorSet,
    hover: ColorSet,
    press: ColorSet,
    menu: ColorSet,
    layer1: ?ColorSet,
    layer2: ?ColorSet,
    layer3: ?ColorSet,

    pub const Mode = std.meta.FieldEnum(Palette);

    pub fn colorset(self: *Palette, mode: Mode) ?ColorSet {
        return @field(self, @tagName(mode));
    }
};

pub const Style = struct {
    background: ?Color = null,
    text: Color,
    border: StyleRect = .all(0),
    borderColor: Color,
    padding: StyleRect = .all(2),
    margin: StyleRect = .all(0),
    borderRadius: Radius = .all(0),
    hoverTint: ?Color = null,
    pressTint: ?Color = null,

    pub const Radius = struct {
        topLeft: u32,
        topRight: u32,
        bottomLeft: u32,
        bottomRight: u32,

        pub fn all(n: u32) Radius {
            return .{
                .topLeft = n,
                .topRight = n,
                .bottomLeft = n,
                .bottomRight = n,
            };
        }
    };
};

pub const Pos = struct {
    x: u32,
    y: u32,
};

pub const StyleRect = struct {
    top: u32,
    right: u32,
    left: u32,
    bottom: u32,

    pub fn all(n: u32) StyleRect {
        return .{
            .top = n,
            .right = n,
            .left = n,
            .bottom = n,
        };
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: f32 = 1.0,

    pub fn fromHex(hex: []const u8) !Color {
        var h = hex;
        if (hex[0] == '#') h = hex[1..];
        const i = try std.fmt.parseInt(u32, h, 16);
        return .{
            .r = @as(u8, @truncate(i >> 16)),
            .g = @as(u8, @truncate(i >> 8)),
            .b = @as(u8, @truncate(i)),
            .a = 1.0,
        };
    }
};

pub const Rect = struct {
    w: u32,
    h: u32,
};

pub const Event = union(enum) {
    mouseMove: Pos,
    mouseClick: bool,
    mouseScroll: u32,
    keyPressed: Keycode,

    pub const Keycode = enum {
        esc,
        f1,
        f2,
        f3,
        f4,
        f5,
        f6,
        f7,
        f8,
        f9,
        f10,
        f11,
        f12,
        backstick,
        tilde,
        num1,
        num2,
        num3,
        num4,
        num5,
        num6,
        num7,
        num8,
        num9,
        num0,
        dash,
        equal,
        backspace,
        tab,
        q,
        w,
        e,
        r,
        t,
        y,
        u,
        i,
        o,
        p,
        sqLParen,
        sqRParen,
        backslash,
        a,
        s,
        d,
        f,
        g,
        h,
        j,
        k,
        l,
        colon,
        quote,
        capslock,
        lshift,
        rshift,
        z,
        x,
        c,
        v,
        b,
        n,
        m,
        comma,
        dot,
        slash,
        lctrl,
        win,
        space,
        lalt,
        function,
        appKey,
        rctrl,
        arrowUp,
        arrowDown,
        arrowLeft,
        arrowRight,
        insert,
        home,
        pageUp,
        pageDown,
        end,
        printScreen,
        screenLock,
        pause,
    };
};

pub const Window = struct {
    id: Id,
    title: []const u8,
    //icon: cherry.Image,
    db: *Db,
    size: Rect,
    position: ?Pos,
};

pub const Widget = struct {
    data: *anyopaque,
    renderFn: *const fn (*anyopaque, PixelBuffer) void,
    sizeFn: *const fn (*anyopaque) Rect,
    getSpaceFn: ?*const fn (*anyopaque, Widget, Rect) PixelBuffer,

    pub fn fromStruct(widget: anytype) Widget {
        if (@hasField(@TypeOf(widget), "widgetData"))
            return @field(widget, "widgetData");
        @compileError("Cannot find required field for widget `widgetData`");
    }

    pub fn render(self: *Widget, buf: PixelBuffer) void {
        self.renderFn(self.data, buf);
    }

    pub fn size(self: *Widget) Rect {
        return self.sizeFn(self.data);
    }

    pub fn getSpace(self: *Widget, w: Widget, r: Rect) PixelBuffer {
        if (self.getSpaceFn) |f|
            return f(self.data, w, r);
        std.debug.panic("Widget does not support `getSpace`");
    }
};

pub const Id = u64;

pub fn genId() Id {
    return rand.random().int(u64);
}

test "Hex" {
    const hex = try Color.fromHex("#12ffee");
    try expect(hex.r == 18);
    try expect(hex.g == 255);
    try expect(hex.b == 238);
}
