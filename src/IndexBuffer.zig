const gl = @import("gl");

const Self = @This();

rendererID: c_uint = undefined,
count: u32,

pub fn init(data: [*]const u32, inCount: u32) Self {
    var ib = Self{ .count = inCount };

    gl.GenBuffers(1, @ptrCast(&ib.rendererID));
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ib.rendererID);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, inCount * @sizeOf(u32), data, gl.STATIC_DRAW);

    return ib;
}

pub fn bind(ib: Self) void {
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ib.rendererID);
}

pub fn unbind(_: Self) void {
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
}

pub fn destroy(ib: *Self) void {
    gl.DeleteBuffers(1, @ptrCast(&ib.rendererID));
}
