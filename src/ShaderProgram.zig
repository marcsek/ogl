const std = @import("std");
const gl = @import("gl");
const glm = @import("glm.zig");
const alloc = std.heap.c_allocator;
const log = std.log;
const Shader = @import("Shader.zig");

const MyHashMap = std.StringHashMap(c_int);

const Self = @This();

rendererID: c_uint = undefined,
uniformCache: MyHashMap,

pub fn init() Self {
    const program = gl.CreateProgram();

    return Self{ .rendererID = program, .uniformCache = MyHashMap.init(alloc) };
}

pub fn setUniform1i(shader: *Self, name: [:0]const u8, value: i32) void {
    gl.Uniform1i(shader.getUniformLocation(name), value);
}

pub fn setUniform1f(shader: *Self, name: [:0]const u8, value: f32) void {
    gl.Uniform1f(shader.getUniformLocation(name), value);
}

pub fn setUniform3f(shader: *Self, name: [:0]const u8, v0: f32, v1: f32, v2: f32) void {
    gl.Uniform3f(shader.getUniformLocation(name), v0, v1, v2);
}

pub fn setUniform4f(shader: *Self, name: [:0]const u8, v0: f32, v1: f32, v2: f32, v3: f32) void {
    gl.Uniform4f(shader.getUniformLocation(name), v0, v1, v2, v3);
}

pub fn setUniformMat4f(shader: *Self, name: [:0]const u8, matrix: glm.mat4) void {
    gl.UniformMatrix4fv(shader.getUniformLocation(name), 1, gl.FALSE, &matrix[0][0]);
}

pub fn attachShader(shader: Self, sh: Shader) void {
    gl.AttachShader(shader.rendererID, sh.rendererID);
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
        log.warn("Uniform '{s}' doesn't exist", .{name});

    shader.uniformCache.put(name, location) catch unreachable;

    return location;
}

pub fn createProgram(self: *Self) void {
    //defer gl.DeleteShader(vs);
    //defer gl.DeleteShader(fs);

    //gl.AttachShader(program, vs);
    //gl.AttachShader(program, fs);

    gl.LinkProgram(self.rendererID);
    gl.ValidateProgram(self.rendererID);
}
