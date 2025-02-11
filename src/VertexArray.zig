const std = @import("std");
const gl = @import("gl");
const VertexBuffer = @import("VertexBuffer.zig");
const VertexBufferLayout = @import("VertexBufferLayout.zig");
const VertexBufferElement = VertexBufferLayout.VertexBufferElement;

const Self = @This();

rendererID: c_uint = undefined,

pub fn init() Self {
    var va = Self{};

    gl.GenVertexArrays(1, @ptrCast(&va.rendererID));
    gl.BindVertexArray(va.rendererID);

    return va;
}

pub fn addBuffers(va: Self, vb: VertexBuffer, vbl: VertexBufferLayout) void {
    va.bind();
    vb.bind();

    var offset: u32 = 0;
    for (vbl.elements.items, 0..vbl.elements.items.len) |element, i| {
        gl.EnableVertexAttribArray(@intCast(i));
        gl.VertexAttribPointer(@intCast(i), @intCast(element.count), element.vType, element.normalized, @intCast(vbl.stride), offset);
        offset += element.count * VertexBufferElement.getSizeOfType(gl.FLOAT);
    }
}

pub fn addBuffer(va: Self, index: u32, buffer: VertexBuffer, element: VertexBufferElement) void {
    va.bind();

    buffer.bind();
    const stride: u32 = element.count * VertexBufferElement.getSizeOfType(gl.FLOAT);
    gl.EnableVertexAttribArray(@intCast(index));
    gl.VertexAttribPointer(@intCast(index), @intCast(element.count), element.vType, element.normalized, @intCast(stride), 0);
}

pub fn bind(va: Self) void {
    gl.BindVertexArray(va.rendererID);
}

pub fn unbind(_: Self) void {
    gl.BindVertexArray(0);
}

pub fn destroy(va: *Self) void {
    gl.DeleteVertexArrays(1, @ptrCast(&va.rendererID));
}
