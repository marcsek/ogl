const std = @import("std");
const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});
const Geometry = @import("Geometry.zig");
const Texture = @import("Texture.zig");
const Material = @import("Material.zig");
const Shader = @import("Shader.zig");
const Mesh = @import("Mesh.zig");
const alloc = std.heap.c_allocator;
const ArrayList = std.ArrayList(f32);

var vertexShader: Shader = undefined;
var fragmentShader: Shader = undefined;

pub fn load() std.ArrayList(Mesh) {
    var time = std.time.Timer.start() catch unreachable;

    const scene = assimp.aiImportFile("res/models/backpack/backpack.obj", assimp.aiProcess_Triangulate | assimp.aiProcess_FlipUVs);
    //const scene = assimp.aiImportFile("res/models/suzzane.obj", assimp.aiProcess_Triangulate | assimp.aiProcess_FlipUVs);
    defer assimp.aiReleaseImport(scene);

    vertexShader = Shader.init("./res/shaders/lightTexVert.glsl", .vertex) catch unreachable;
    fragmentShader = Shader.init("./res/shaders/lightTexFrag.glsl", .fragment) catch unreachable;
    var meshes = std.ArrayList(Mesh).init(alloc);
    processNode(scene.*.mRootNode, scene, &meshes);
    std.log.debug("Huh {s} CO", .{scene.*.mName.data[0..scene.*.mName.length]});
    std.log.debug("{d}", .{scene.*.mMeshes[0].*.mNumVertices});
    std.log.debug("{d}", .{meshes.items.len});

    var nVert: usize = 0;
    var nInd: usize = 0;

    for (meshes.items) |g| {
        nVert += g.geometry.vertexData[0].data.len / 3;
        nInd += g.geometry.index.len / 3;
    }

    const total: f64 = @as(f64, @floatFromInt(time.lap())) / 1_000_000_000.0;
    std.log.debug("Loaded model '{s}' #v: {d} #i: {d} in {d:6.5} sec.", .{ scene.*.mName.data[0..scene.*.mName.length], nVert, nInd, total });

    return meshes;
}

fn processNode(node: *assimp.aiNode, scene: *const assimp.aiScene, res: *std.ArrayList(Mesh)) void {
    for (0..node.mNumMeshes) |i| {
        const mesh = scene.mMeshes[node.mMeshes[i]];
        const pos, const norm, const texCoords = extractVerts(mesh);
        const ind = extractInds(mesh);

        var geometry = Geometry.init(alloc);
        const data = [_]Geometry.BufferAttribute{
            .{
                .name = "position",
                .itemSize = 3,
                .data = pos.items,
            },
            .{
                .name = "normal",
                .itemSize = 3,
                .data = norm.items,
            },
            .{
                .name = "texture",
                .itemSize = 2,
                .data = texCoords.items,
            },
        };

        geometry.setVertexData(&data) catch unreachable;
        geometry.setIndex(ind.items) catch unreachable;

        var material = Material.init(&vertexShader, &fragmentShader);
        if (mesh.*.mMaterialIndex >= 0) {
            const aiMat = scene.mMaterials[mesh.*.mMaterialIndex];
            material.setTexture(loadMaterialTexture(aiMat, assimp.aiTextureType_DIFFUSE), .color);
            material.setTexture(loadMaterialTexture(aiMat, assimp.aiTextureType_SPECULAR), .specular);
        }

        const resMesh = Mesh.init(geometry, material);
        res.append(resMesh) catch unreachable;
    }

    for (0..node.mNumChildren) |i| {
        processNode(node.mChildren[i], scene, res);
    }
}

fn extractVerts(mesh: *assimp.aiMesh) struct { ArrayList, ArrayList, ArrayList } {
    var positions = ArrayList.initCapacity(alloc, mesh.mNumVertices * 3) catch unreachable;
    var normals = ArrayList.initCapacity(alloc, mesh.mNumVertices * 3) catch unreachable;
    const hasTextureCoords = mesh.mTextureCoords[0] != null;

    var texture: ArrayList = undefined;

    if (hasTextureCoords)
        texture = ArrayList.initCapacity(alloc, mesh.mNumVertices * 2) catch unreachable
    else
        texture = ArrayList.init(alloc);

    for (0..mesh.mNumVertices) |i| {
        positions.append(mesh.mVertices[i].x) catch unreachable;
        positions.append(mesh.mVertices[i].y) catch unreachable;
        positions.append(mesh.mVertices[i].z) catch unreachable;

        normals.append(mesh.mNormals[i].x) catch unreachable;
        normals.append(mesh.mNormals[i].y) catch unreachable;
        normals.append(mesh.mNormals[i].z) catch unreachable;

        if (hasTextureCoords) {
            texture.append(mesh.mTextureCoords[0][i].x) catch unreachable;
            texture.append(mesh.mTextureCoords[0][i].y) catch unreachable;
        }
    }

    return .{ positions, normals, texture };
}

fn extractInds(mesh: *assimp.aiMesh) std.ArrayList(u32) {
    var indices = std.ArrayList(u32).init(alloc);

    for (0..mesh.mNumFaces) |i| {
        for (0..mesh.mFaces[i].mNumIndices) |j| {
            indices.append(mesh.mFaces[i].mIndices[j]) catch unreachable;
        }
    }

    return indices;
}

var matCache = std.StringHashMap(Texture).init(alloc);

fn loadMaterialTexture(mat: *assimp.aiMaterial, texType: assimp.aiTextureType) Texture {
    //std.log.debug("{d} {d}", .{ texType, assimp.aiGetMaterialTextureCount(mat, texType) });

    if (assimp.aiGetMaterialTextureCount(mat, texType) > 1)
        std.log.warn("Only support loading one texture per mesh per texture type", .{});

    var location: assimp.aiString = undefined;
    _ = assimp.aiGetMaterialTexture(mat, texType, 0, &location, null, null, null, null, null, null);

    const toConcat = &.{ "res/models/backpack/", location.data[0..location.length] };
    const filePath = std.mem.concat(alloc, u8, toConcat) catch unreachable;

    if (matCache.contains(filePath))
        return matCache.get(filePath).?;

    const texture = Texture.init(alloc, filePath) catch unreachable;
    std.log.debug("Location: {s}", .{filePath});

    matCache.put(filePath, texture) catch unreachable;

    return texture;
}
