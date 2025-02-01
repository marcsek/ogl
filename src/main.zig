const std = @import("std");
const print = std.debug.print;
const App = @import("App.zig");

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
