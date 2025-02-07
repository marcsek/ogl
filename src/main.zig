const std = @import("std");
const builtin = @import("builtin");
const print = std.debug.print;
const logFn = @import("utils.zig").myLogFn;
const App = @import("App.zig");

pub const std_options: std.Options = .{
    .logFn = logFn,
    .log_level = if (builtin.mode == .Debug) .debug else .info,
};

pub fn main() !void {
    const app = App.init(std.heap.page_allocator) catch |err| switch (err) {
        error.InitFailed => {
            print("Failed to initialize window.\n", .{});
            return;
        },
        else => {
            print("Error: {}.\n", .{err});
            return;
        },
    };
    defer app.destroy();

    app.loop();
}
