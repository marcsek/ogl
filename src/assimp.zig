const std = @import("std");
const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

pub fn load() void {
    const daco = assimp.aiImportFile("res/models/suzzane.obj", assimp.aiProcess_Triangulate | assimp.aiProcess_FlipUVs);
    std.log.debug("Huh {s} CO", .{daco.*.mName.data[0..daco.*.mName.length]});
    std.log.debug("{d}", .{daco.*.mMeshes[0].*.mNumVertices});
    defer assimp.aiReleaseImport(daco);
}
