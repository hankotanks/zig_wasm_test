const std = @import("std");
const zjb = @import("zjb");

const alloc = std.heap.page_allocator;

fn logNum(val: anytype) void {
    // allocate buffer
    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();
    // format the number
    buf.writer().print("{d}", .{val}) catch {};
    const console = zjb.global("console");
    // write formatted string to console
    const handle = zjb.string(buf.items);
    defer handle.release();
    console.call("log", .{handle}, void);
}

fn getContext() zjb.Handle {
    const document = zjb.global("document");
    const sel = zjb.constString("body > canvas");
    const canvas = document.call("querySelector", .{sel}, zjb.Handle);
    defer canvas.release();
    const dim = zjb.constString("2d");
    return canvas.call("getContext", .{dim}, zjb.Handle);
}

export fn click(x: f32, y: f32) void {
    // get context
    const ctx = getContext();
    defer ctx.release();
    // log coordinates
    logNum(x);
    logNum(y);
    // draw a rectangle at cursor position
    ctx.call("fillRect", .{ x, y, 5, 5 }, void);
}

export fn clear(width: f32, height: f32) void {
    // get context
    const ctx = getContext();
    defer ctx.release();
    // clear the canvas
    ctx.call("clearRect", .{ 0, 0, width, height }, void);
}

comptime {
    zjb.exportFn("click", click);
    zjb.exportFn("clear", clear);
}
