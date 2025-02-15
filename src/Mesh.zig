const std = @import("std");
const Material = @import("Material.zig");
const Geometry = @import("Geometry.zig");

const Self = @This();

material: Material,
geometry: Geometry,
//TODO: hold rotation, position, ...

pub fn init(geo: Geometry, mat: Material) Self {
    return Self{ .geometry = geo, .material = mat };
}
