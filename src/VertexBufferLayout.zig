const std = @import("std");
const gl = @import("gl");

const Self = @This();

const MyArrayList = std.ArrayList(VertexBufferElement);

allocator: std.mem.Allocator,
elements: MyArrayList,
stride: u32,

pub const VertexBufferElement = struct {
    vType: c_uint,
    count: u32,
    normalized: gl.boolean,

    pub fn getSizeOfType(vType: c_uint) u32 {
        return switch (vType) {
            gl.FLOAT => 4,
            else => 0,
        };
    }
};

pub fn init(alloc: std.mem.Allocator) Self {
    return Self{
        .allocator = alloc,
        .elements = MyArrayList.init(alloc),
        .stride = 0,
    };
}

pub fn push(vbl: *Self, count: u32) !void {
    try vbl.elements.append(.{ .count = count, .normalized = gl.FALSE, .vType = gl.FLOAT });

    vbl.stride += count * VertexBufferElement.getSizeOfType(gl.FLOAT);
}

pub fn destroy(vbl: Self) void {
    vbl.elements.deinit();
}
