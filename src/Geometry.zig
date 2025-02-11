const std = @import("std");
const gl = @import("gl");
const VertexBuffer = @import("VertexBuffer.zig");
const IndexBuffer = @import("IndexBuffer.zig");
const VertexArray = @import("VertexArray.zig");
const BufferLayout = @import("VertexBufferLayout.zig");
const BufferElement = BufferLayout.VertexBufferElement;
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
vertexData: []BufferAttribute = undefined,
buffers: []VertexBuffer = undefined,
index: []u32 = undefined,
vertexArray: VertexArray = undefined,
indexBuffer: IndexBuffer = undefined,

pub fn init(alloc: Allocator) Self {
    return Self{ .allocator = alloc };
}

pub fn setVertexData(self: *Self, vertexDataIn: []const BufferAttribute) Allocator.Error!void {
    self.buffers = try self.allocator.alloc(VertexBuffer, vertexDataIn.len);
    errdefer self.allocator.free(self.buffers);

    self.vertexData = try self.allocator.dupe(BufferAttribute, vertexDataIn);
    errdefer self.allocator.free(self.vertexData);

    self.bindData();
}

pub fn bindData(self: *Self) void {
    var vertexArray = VertexArray.init();

    var bufferLayout = BufferLayout.init(self.allocator);
    defer bufferLayout.destroy();

    for (self.vertexData, 0..self.vertexData.len) |bufferAttrib, i| {
        const bufferSize: u32 = @intCast(bufferAttrib.data.len * @sizeOf(f32));
        const vertexBuffer = VertexBuffer.init(bufferAttrib.data.ptr, @intCast(bufferSize));

        vertexArray.addBuffer(@intCast(i), vertexBuffer, BufferElement.init(bufferAttrib.itemSize));
        self.buffers[i] = vertexBuffer;
    }

    self.vertexArray = vertexArray;
}

pub fn setIndex(self: *Self, indices: []const u32) Allocator.Error!void {
    const indexBuffer = IndexBuffer.init(indices.ptr, @intCast(indices.len));

    self.index = try self.allocator.dupe(u32, indices);
    self.indexBuffer = indexBuffer;
}

pub fn bind(self: *Self) void {
    self.vertexArray.bind();
}

pub fn unbind(self: *Self) void {
    self.vertexArray.unbind();
}

pub fn dispose(self: *Self) void {
    self.vertexArray.destroy();
    self.indexBuffer.destroy();
    for (self.buffers) |*buffer|
        buffer.destroy();
}

pub fn destroy(self: *Self) void {
    self.dispose();
    self.allocator.free(self.vertexData);
    self.allocator.free(self.index);
    self.allocator.free(self.buffers);
}

pub const BufferAttribute = struct {
    name: []const u8,
    data: []const f32,
    itemSize: u32,
};
