const std = @import("std");
const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});
const log = @import("utils.zig").scopes.resourceLog;
const Geometry = @import("Geometry.zig");
const Texture = @import("Texture.zig");
const Material = @import("Material.zig");
const Shader = @import("Shader.zig");
const Mesh = @import("Mesh.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const MyHashMap = std.StringHashMap(Texture);

pub const Error = error{FailedToImport} || Allocator.Error || Texture.Error;

const Self = @This();

allocator: Allocator,
textureCache: MyHashMap,

pub fn init(alloc: Allocator) Self {
    return Self{ .allocator = alloc, .textureCache = MyHashMap.init(alloc) };
}

pub fn loadFromFile(
    self: *Self,
    filePath: []const u8,
    vertexShader: Shader,
    fragmentShader: Shader,
) Error![]Mesh {
    var time = std.time.Timer.start() catch unreachable;

    const scene = assimp.aiImportFile(filePath.ptr, assimp.aiProcess_Triangulate | assimp.aiProcess_FlipUVs);
    defer assimp.aiReleaseImport(scene);

    if (scene == null or (scene.*.mFlags & assimp.AI_SCENE_FLAGS_INCOMPLETE == 1) or scene.*.mRootNode == null) {
        log.err("Failed to load model ({s})", .{assimp.aiGetErrorString()});
        return Error.FailedToImport;
    }

    var meshes = try ArrayList(Mesh).initCapacity(self.allocator, scene.*.mNumMeshes);

    try self.processNode(scene.*.mRootNode, scene, "./res/models/sword/textures", vertexShader, fragmentShader, &meshes);

    const totalTime: f64 = @as(f64, @floatFromInt(time.lap())) / 1_000_000_000.0;
    log.info("Model loaded in {d:.5} sec.", .{totalTime});

    return meshes.items;
}

pub fn destroy(self: *Self) void {
    self.textureCache.deinit();
}

fn processNode(
    self: *Self,
    node: *assimp.aiNode,
    scene: *const assimp.aiScene,
    directory: []const u8,
    vs: Shader,
    fs: Shader,
    result: *ArrayList(Mesh),
) Error!void {
    for (0..node.mNumMeshes) |i| {
        const mesh = scene.mMeshes[node.mMeshes[i]];

        var geometry = try self.createGeometry(mesh);
        errdefer geometry.destroy();

        var material = try self.createMaterial(scene, mesh.*.mMaterialIndex, directory, vs, fs);
        errdefer material.destroy();

        result.appendAssumeCapacity(Mesh.init(geometry, material));
    }

    for (0..node.mNumChildren) |i|
        try self.processNode(node.mChildren[i], scene, directory, vs, fs, result);
}

fn createGeometry(self: *Self, mesh: *const assimp.aiMesh) Error!Geometry {
    const positions, const normals, const textureCoords = try self.extractVertices(mesh);

    errdefer {
        self.allocator.free(positions);
        if (normals) |norm| self.allocator.free(norm);
        if (textureCoords) |texCoords| self.allocator.free(texCoords);
    }

    var vertexData = ArrayList(Geometry.BufferAttribute).init(self.allocator);
    errdefer vertexData.deinit();

    try vertexData.append(.{ .name = "position", .itemSize = 3, .data = positions });

    if (normals) |norm|
        try vertexData.append(.{ .name = "normal", .itemSize = 3, .data = norm });

    if (textureCoords) |texCoords|
        try vertexData.append(.{ .name = "texture", .itemSize = 2, .data = texCoords });

    var geometry = Geometry.init(self.allocator);
    try geometry.setVertexDataFromOwned(try vertexData.toOwnedSlice());
    errdefer geometry.destroy();

    const indices = try self.extractIndices(mesh);
    errdefer self.allocator.free(indices);

    geometry.setIndexFromOwned(indices);

    return geometry;
}

fn createMaterial(
    self: *Self,
    scene: *const assimp.aiScene,
    materialIdx: c_uint,
    directory: []const u8,
    vs: Shader,
    fs: Shader,
) Error!Material {
    var material = Material.init(vs, fs);
    const mat = scene.mMaterials[materialIdx];

    if (mat != null) {
        if (try self.loadMaterialTexture(mat, assimp.aiTextureType_DIFFUSE, directory)) |tex|
            material.setTexture(tex, .color);

        if (try self.loadMaterialTexture(mat, assimp.aiTextureType_SPECULAR, directory)) |tex|
            material.setTexture(tex, .specular);

        if (try self.loadMaterialTexture(mat, assimp.aiTextureType_EMISSIVE, directory)) |tex|
            material.setTexture(tex, .emission);
    }

    return material;
}

fn extractVertices(self: Self, mesh: *const assimp.aiMesh) Allocator.Error!struct { []f32, ?[]f32, ?[]f32 } {
    var positions = try self.allocator.alloc(f32, mesh.mNumVertices * 3);
    var normals: ?[]f32 = null;
    var textureCoords: ?[]f32 = null;

    errdefer {
        self.allocator.free(positions);
        if (normals) |norm| self.allocator.free(norm);
        if (textureCoords) |texCoords| self.allocator.free(texCoords);
    }

    if (mesh.mNormals != null)
        normals = try self.allocator.alloc(f32, mesh.mNumVertices * 3);
    if (mesh.mTextureCoords[0] != null)
        textureCoords = try self.allocator.alloc(f32, mesh.mNumVertices * 2);

    for (0..mesh.mNumVertices) |i| {
        positions[i * 3] = mesh.mVertices[i].x;
        positions[i * 3 + 1] = mesh.mVertices[i].y;
        positions[i * 3 + 2] = mesh.mVertices[i].z;

        if (normals) |norm| {
            norm[i * 3] = mesh.mNormals[i].x;
            norm[i * 3 + 1] = mesh.mNormals[i].y;
            norm[i * 3 + 2] = mesh.mNormals[i].z;
        }

        if (textureCoords) |texCoords| {
            texCoords[i * 2] = mesh.mTextureCoords[0][i].x;
            texCoords[i * 2 + 1] = mesh.mTextureCoords[0][i].y;
        }
    }

    return .{ positions, normals, textureCoords };
}

fn extractIndices(self: Self, mesh: *const assimp.aiMesh) Allocator.Error![]u32 {
    var indices = try self.allocator.alloc(u32, mesh.mNumFaces * 3);

    for (0..mesh.mNumFaces) |i|
        for (0..3) |j| {
            indices[i * 3 + j] = mesh.mFaces[i].mIndices[j];
        };

    return indices;
}

fn loadMaterialTexture(
    self: *Self,
    material: *assimp.aiMaterial,
    textureType: assimp.aiTextureType,
    directory: []const u8,
) Error!?Texture {
    const textureTypeCount = assimp.aiGetMaterialTextureCount(material, textureType);

    if (textureTypeCount == 0)
        return null;

    if (textureTypeCount > 1)
        log.warn("Only support loading one texture per mesh per texture type", .{});

    var modelLocation: assimp.aiString = undefined;
    const result = assimp.aiGetMaterialTexture(material, textureType, 0, &modelLocation, null, null, null, null, null, null);

    if (result != assimp.AI_SUCCESS)
        return Error.FailedToLoadTexture;

    const toConcat = &.{ directory, modelLocation.data[0..modelLocation.length] };
    const filePath = try std.mem.concat(self.allocator, u8, toConcat);
    errdefer self.allocator.free(filePath);

    if (self.textureCache.get(filePath)) |texture|
        return texture;

    var texture = try Texture.init(self.allocator, filePath);
    errdefer texture.destroy();

    try self.textureCache.put(filePath, texture);

    return texture;
}
