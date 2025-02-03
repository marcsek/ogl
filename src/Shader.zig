const std = @import("std");
const gl = @import("gl");
const alloc = std.heap.c_allocator;
const glm = @import("glm.zig").unaligned;

const MyHashMap = std.StringHashMap(c_int);

const Self = @This();

rendererID: c_uint = undefined,
uniformCache: MyHashMap,

pub fn init(vertexPath: []const u8, fragmentPath: []const u8) !Self {
    const vertexSource = try loadFile(alloc, vertexPath);
    defer alloc.free(vertexSource);
    const fragmentSource = try loadFile(alloc, fragmentPath);
    defer alloc.free(fragmentSource);

    const shader = try createShader(vertexSource, fragmentSource);

    return Self{ .rendererID = shader, .uniformCache = MyHashMap.init(alloc) };
}

pub fn setUniform1i(shader: *Self, name: [:0]const u8, value: i32) void {
    gl.Uniform1i(shader.getUniformLocation(name), value);
}

pub fn setUniform4f(shader: *Self, name: [:0]const u8, v0: f32, v1: f32, v2: f32, v3: f32) void {
    gl.Uniform4f(shader.getUniformLocation(name), v0, v1, v2, v3);
}

pub fn setUniformMat4f(shader: *Self, name: [:0]const u8, matrix: glm.mat4) void {
    gl.UniformMatrix4fv(shader.getUniformLocation(name), 1, gl.FALSE, &matrix[0][0]);
}

pub fn bind(shader: Self) void {
    gl.UseProgram(shader.rendererID);
}

pub fn unbind(_: Self) void {
    gl.UseProgram(0);
}

pub fn destroy(shader: *Self) void {
    gl.DeleteProgram(shader.rendererID);
    shader.uniformCache.deinit();
}

fn getUniformLocation(shader: *Self, name: [:0]const u8) c_int {
    if (shader.uniformCache.get(name)) |value| {
        return value;
    }

    const location = gl.GetUniformLocation(shader.rendererID, name.ptr);

    if (location == -1)
        std.debug.print("Uniform '{s}' doesn't exist.\n", .{name});

    shader.uniformCache.put(name, location) catch unreachable;

    return location;
}

fn createShader(vertexShader: [:0]const u8, fragmentShader: [:0]const u8) !c_uint {
    const program = gl.CreateProgram();
    const vs = try compileShader(gl.VERTEX_SHADER, vertexShader);
    const fs = try compileShader(gl.FRAGMENT_SHADER, fragmentShader);
    defer gl.DeleteShader(vs);
    defer gl.DeleteShader(fs);

    gl.AttachShader(program, vs);
    gl.AttachShader(program, fs);

    gl.LinkProgram(program);
    gl.ValidateProgram(program);

    return program;
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

        std.debug.print("Failed to compile shader: {s}\n", .{message});

        return error.FailedShaderCompilation;
    }

    return id;
}

fn loadFile(allocator: std.mem.Allocator, filepath: []const u8) ![:0]u8 {
    const file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return error.FailedToOpenFile;
    };
    defer file.close();

    const contents = file.reader().readAllAlloc(allocator, std.math.maxInt(usize)) catch |err| {
        std.log.err("Failed to read file: {s}", .{@errorName(err)});
        return error.FailedToReadFile;
    };

    const null_term_contents = allocator.dupeZ(u8, contents[0..]);
    defer allocator.free(contents);

    return null_term_contents;
}
