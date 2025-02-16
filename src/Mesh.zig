const std = @import("std");
const glm = @import("glm.zig");
const Material = @import("Material.zig");
const Geometry = @import("Geometry.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Self = @This();

// TODO: Make an 'Object' struct that doesn't hold material and geometry
allocator: Allocator,
material: Material,
geometry: Geometry,

position: glm.vec3 = .{ 0, 0, 0 },
rotation: glm.vec3 = .{ 0, 0, 0 },
scale: glm.vec3 = .{ 1, 1, 1 },
modelMatrix: glm.mat4 = undefined,

children: ArrayList(*Self),
parent: ?*Self,
alive: bool,

pub fn init(alloc: Allocator, geo: Geometry, mat: Material) Self {
    var result = Self{
        .allocator = alloc,
        .geometry = geo,
        .material = mat,
        .children = ArrayList(*Self).init(alloc),
        .parent = null,
        .alive = true,
    };
    glm.glmc_mat4_identity(&result.modelMatrix);

    return result;
}

pub fn addChild(self: *Self, child: *Self) Allocator.Error!void {
    child.*.parent = self;
    try self.children.append(child);
}

var rotAxis = glm.vec3{ 1.0, 1.0, 1.0 };
pub fn updateModelMatrix(self: *Self) void {
    if (self.parent) |parent|
        glm.glmc_mat4_copy(&parent.modelMatrix, &self.modelMatrix)
    else
        glm.glmc_mat4_identity(&self.modelMatrix);

    glm.glmc_translate(&self.modelMatrix, &self.position);
    glm.glmc_rotate(&self.modelMatrix, self.rotation[0], &rotAxis);
    glm.glmc_scale(&self.modelMatrix, &self.scale);

    self.material.shader.setUniformMat4f("model", self.modelMatrix);
}

pub fn setViewMatrix(self: *Self, viewMatrix: glm.mat4) void {
    self.material.shader.setUniformMat4f("view", viewMatrix);
}

pub fn setProjectionMatrix(self: *Self, projMatrix: glm.mat4) void {
    self.material.shader.setUniformMat4f("projection", projMatrix);
}

pub fn bind(self: *Self) void {
    self.geometry.bind();
    self.material.bind();
}

pub fn unbind(self: *Self) void {
    self.geometry.unbind();
    self.material.unbind();
}

// TODO: Should parent own ? - maybe separete function ?
pub fn destroy(self: *Self) void {
    if (!self.alive) {
        std.log.err("Tried to double free a Mesh", .{});
        return;
    }

    self.geometry.destroy();
    self.material.destroy();
    self.alive = false;

    for (self.children.items) |child|
        child.destroy();
}
