const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const log = std.log;

pub const scopes = struct {
    pub const glfwLog = log.scoped(.GLFW);
    pub const openGlLog = log.scoped(.OpenGL);
    pub const resourceLog = log.scoped(.Resource);
};

// modified std.log.defaultLog function
pub fn myLogFn(comptime message_level: std.log.Level, comptime scope: @TypeOf(.enum_literal), comptime format: []const u8, args: anytype) void {
    const color = switch (message_level) {
        .warn => "\x1b[0;33m",
        .err => "\x1b[0;31m",
        else => "",
    };

    const ending = if (color.len != 1) "\x1b[0m" else "";

    const level_txt = "[" ++ comptime message_level.asText() ++ "] ";
    const prefix2 = if (scope == .default) "" else "(" ++ @tagName(scope) ++ ") ";
    const stderr = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        writer.print(color ++ level_txt ++ prefix2 ++ format ++ ending ++ "\n", args) catch return;
        bw.flush() catch return;
    }
}

pub fn glDebugOutput(source: c_uint, debugType: c_uint, id: c_uint, severity: c_uint, _: c_int, message: [*:0]const u8, _: ?*const anyopaque) callconv(gl.APIENTRY) void {
    if (id == 131169 or id == 131185 or id == 131218 or id == 131204) return;

    const sourceString = switch (source) {
        gl.DEBUG_SOURCE_API => "API",
        gl.DEBUG_SOURCE_WINDOW_SYSTEM => "Window System",
        gl.DEBUG_SOURCE_SHADER_COMPILER => "Shader Compiler",
        gl.DEBUG_SOURCE_THIRD_PARTY => "Third Party",
        gl.DEBUG_SOURCE_APPLICATION => "Application",
        gl.DEBUG_SOURCE_OTHER => "Other",
        else => "unknown",
    };

    const typeString, const logLevel: log.Level = switch (debugType) {
        gl.DEBUG_TYPE_ERROR => .{ "Error", log.Level.err },
        gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR => .{ "Deprecated Behaviour", log.Level.warn },
        gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR => .{ "Undefined Behaviour", log.Level.err },
        gl.DEBUG_TYPE_PORTABILITY => .{ "Portability", log.Level.info },
        gl.DEBUG_TYPE_PERFORMANCE => .{ "Performance", log.Level.warn },
        gl.DEBUG_TYPE_MARKER => .{ "Marker", log.Level.info },
        gl.DEBUG_TYPE_PUSH_GROUP => .{ "Push Group", log.Level.info },
        gl.DEBUG_TYPE_POP_GROUP => .{ "Pop Group", log.Level.info },
        gl.DEBUG_TYPE_OTHER => .{ "Other", log.Level.info },
        else => .{ "unknown", log.Level.warn },
    };

    const severityString = switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => "high",
        gl.DEBUG_SEVERITY_MEDIUM => "medium",
        gl.DEBUG_SEVERITY_LOW => "low",
        gl.DEBUG_SEVERITY_NOTIFICATION => "notification",
        else => "unknown",
    };

    const format: []const u8 = "({d}): {s} " ++ "Source: {s}, Type: {s}, Severity: {s}";
    const args = .{ id, message, sourceString, typeString, severityString };

    switch (logLevel) {
        .info => scopes.openGlLog.info(format, args),
        .warn => scopes.openGlLog.warn(format, args),
        .err => scopes.openGlLog.err(format, args),
        .debug => scopes.openGlLog.debug(format, args),
    }
}

pub fn glfwErrorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    scopes.glfwLog.err("{}: {s}", .{ error_code, description });
}

pub fn splitDirAndFile(filePath: []const u8) struct { []const u8, []const u8 } {
    const index = std.mem.lastIndexOf(u8, filePath, "/");

    if (index) |i|
        return .{ filePath[0 .. i + 1], filePath[i + 1 ..] };

    return .{ "", filePath };
}
