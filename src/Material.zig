const std = @import("std");
const gl = @import("gl");
const glm = @import("glm.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");

const Self = @This();

const TextureKind = enum {
    color,
    specular,
    emission,
};

map: ?Texture = null,
specularMap: ?Texture = null,
emissionMap: ?Texture = null,

color: glm.vec4 = .{ 1.0, 1.0, 1.0, 1.0 },

shader: ShaderProgram,

pub fn init(vertexShader: *Shader, fragmentShader: *Shader) Self {
    var program = ShaderProgram.init();

    program.attachShader(vertexShader.*);
    program.attachShader(fragmentShader.*);

    program.createProgram();

    // TODO: delete or keep for different program to use ?
    vertexShader.destroy();
    fragmentShader.destroy();

    return Self{
        .shader = program,
    };
}

pub inline fn setTexture(self: *Self, texture: Texture, kind: TextureKind) void {
    self.bind();

    switch (kind) {
        .color => {
            self.map = texture;
            self.shader.setUniform1i("material.diffuse", 0);
        },
        .specular => {
            self.specularMap = texture;
            self.shader.setUniform1i("material.specular", 1);
        },
        .emission => {
            self.emissionMap = texture;
            self.shader.setUniform1i("material.emission", 2);
        },
    }
}

pub fn bind(self: Self) void {
    self.shader.bind();

    if (self.map) |map|
        map.bind(0);

    if (self.specularMap) |specular|
        specular.bind(1);

    if (self.emissionMap) |emission|
        emission.bind(2);
}

pub fn unbind(self: Self) void {
    self.shader.unbind();

    if (self.map) |map|
        map.unbind(0);

    if (self.specularMap) |specular|
        specular.unbind(1);

    if (self.emissionMap) |emission|
        emission.unbind(2);
}

pub fn destroy(self: *Self) void {
    self.shader.destroy();

    if (self.map) |*map|
        map.destroy();

    if (self.specularMap) |*specular|
        specular.destroy();

    if (self.emissionMap) |*emission|
        emission.destroy();
}
