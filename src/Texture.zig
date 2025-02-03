const std = @import("std");
const gl = @import("gl");
const stb = @cImport(@cInclude("stb_image.h"));

const Self = @This();

allocator: std.mem.Allocator,
rendererID: c_uint = undefined,
width: c_int = undefined,
height: c_int = undefined,
bpp: c_int = undefined,

pub fn init(alloc: std.mem.Allocator, filePath: []const u8) !Self {
    stb.stbi_set_flip_vertically_on_load(1);
    var result = Self{
        .allocator = alloc,
    };

    const buffer = stb.stbi_load(filePath.ptr, @ptrCast(&result.width), @ptrCast(&result.height), @ptrCast(&result.bpp), 4);
    if (buffer == null) {
        std.debug.print("Texture '{s}' not found.\n", .{filePath});
        return error.FileNotFound;
    }

    defer stb.stbi_image_free(buffer);

    gl.GenTextures(1, @ptrCast(&result.rendererID));
    gl.BindTexture(gl.TEXTURE_2D, result.rendererID);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, result.width, result.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, buffer);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    return result;
}

pub fn bind(tx: Self, slot: u32) void {
    gl.ActiveTexture(gl.TEXTURE0 + slot);
    gl.BindTexture(gl.TEXTURE_2D, tx.rendererID);
}

pub fn unbind(_: Self) void {
    gl.BindTexture(gl.TEXTURE_2D, 0);
}

pub fn destroy(tx: *Self) void {
    gl.DeleteTextures(1, @ptrCast(&tx.rendererID));
}
