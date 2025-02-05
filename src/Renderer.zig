const std = @import("std");
const gl = @import("gl");
const IndexBuffer = @import("IndexBuffer.zig");
const VertexArray = @import("VertexArray.zig");
const Shader = @import("Shader.zig");

pub fn draw(va: VertexArray, ib: IndexBuffer, sh: Shader) void {
    va.bind();
    ib.bind();
    sh.bind();

    //gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
    gl.DrawArrays(gl.TRIANGLES, 0, 36);
}

pub fn clear() void {
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

pub fn setClearColor(v0: f32, v1: f32, v2: f32, v3: f32) void {
    gl.ClearColor(v0, v1, v2, v3);
}
