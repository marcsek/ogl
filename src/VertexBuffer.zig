const gl = @import("gl");

const Self = @This();

rendererID: c_uint = undefined,

pub fn init(data: *const anyopaque, size: u32) Self {
    var vb = Self{};

    gl.GenBuffers(1, @ptrCast(&vb.rendererID));
    gl.BindBuffer(gl.ARRAY_BUFFER, vb.rendererID);
    gl.BufferData(gl.ARRAY_BUFFER, size, data, gl.STATIC_DRAW);

    return vb;
}

pub fn bind(vb: Self) void {
    gl.BindBuffer(gl.ARRAY_BUFFER, vb.rendererID);
}

pub fn unbind(_: Self) void {
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
}

pub fn destroy(vb: *Self) void {
    gl.DeleteBuffers(1, @ptrCast(&vb.rendererID));
}
