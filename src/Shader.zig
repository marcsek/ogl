const std = @import("std");
const gl = @import("gl");
const glm = @import("glm.zig");
const alloc = std.heap.c_allocator;
const log = std.log;

const Self = @This();

rendererID: c_uint,

pub const ShaderKind = enum {
    vertex,
    fragment,
};

pub fn init(shaderPath: []const u8, kind: ShaderKind) !Self {
    const source = try loadFile(alloc, shaderPath);
    defer alloc.free(source);

    const shader = try compileShader(getGlShaderEnumFromKind(kind), source);

    return Self{ .rendererID = shader };
}

pub fn destroy(shader: *Self) void {
    gl.DeleteShader(shader.rendererID);
}

fn compileShader(shaderType: c_uint, source: [:0]const u8) !c_uint {
    const id = gl.CreateShader(shaderType);
    gl.ShaderSource(id, 1, @ptrCast(&source), null);
    gl.CompileShader(id);
    errdefer gl.DeleteShader(id);

    var result: c_int = undefined;
    gl.GetShaderiv(id, gl.COMPILE_STATUS, &result);

    if (result == gl.FALSE) {
        var length: c_int = undefined;
        gl.GetShaderiv(id, gl.INFO_LOG_LENGTH, &length);

        const allocator = std.heap.page_allocator;
        const message = try allocator.alloc(u8, @intCast(length));
        defer allocator.free(message);

        gl.GetShaderInfoLog(id, length, &length, message.ptr);

        log.err("Failed to compile shader: {s}\n", .{message});

        return error.FailedShaderCompilation;
    }

    return id;
}

fn loadFile(allocator: std.mem.Allocator, filepath: []const u8) ![:0]u8 {
    const file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        log.err("Failed to open file: {s}", .{@errorName(err)});
        return error.FailedToOpenFile;
    };
    defer file.close();

    const contents = file.reader().readAllAlloc(allocator, std.math.maxInt(usize)) catch |err| {
        log.err("Failed to read file: {s}", .{@errorName(err)});
        return error.FailedToReadFile;
    };

    const null_term_contents = allocator.dupeZ(u8, contents[0..]);
    defer allocator.free(contents);

    return null_term_contents;
}

inline fn getGlShaderEnumFromKind(kind: ShaderKind) c_uint {
    return switch (kind) {
        .vertex => gl.VERTEX_SHADER,
        .fragment => gl.FRAGMENT_SHADER,
    };
}
