const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const vb = @import("../VertexBuffer.zig");
const ib = @import("../IndexBuffer.zig");
const va = @import("../VertexArray.zig");
const vbl = @import("../VertexBufferLayout.zig");
const Texture = @import("../Texture.zig");
const Camera = @import("../Camera.zig");
const ImGui = @import("../imgui.zig");
const Geometry = @import("../Geometry.zig");
const Shader = @import("../Shader.zig");
const Material = @import("../Material.zig");
const Mesh = @import("../Mesh.zig");
const Renderer = @import("../Renderer.zig");
const glm = @import("../glm.zig");
const cube = @import("../shapes.zig").cube;

allocator: std.mem.Allocator,
window: glfw.Window,
camera: Camera,
meshCube: *Mesh,
meshLight: *Mesh,
fov: f32 = 45,
cubePos: glm.vec3,
lightPos: glm.vec3,
cubeColor: glm.vec3,
rotAngle: f32,

const Self = @This();

pub fn init(alloc: std.mem.Allocator, win: glfw.Window) Self {
    gl.Enable(gl.DEPTH_TEST);

    const winSize = win.getFramebufferSize();

    const geometryCube = cube.createGeometry(alloc, .{ .normals = true }) catch unreachable;
    const geometryLight = cube.createGeometry(alloc, .{}) catch unreachable;

    var vertexDefault = Shader.init("./res/shaders/defaultVert.glsl", .vertex) catch unreachable;
    defer vertexDefault.destroy();
    var fragmentDefault = Shader.init("./res/shaders/defaultFrag.glsl", .fragment) catch unreachable;
    defer fragmentDefault.destroy();

    var vertexLight = Shader.init("./res/shaders/lightVert.glsl", .vertex) catch unreachable;
    defer vertexLight.destroy();
    var fragmentLight = Shader.init("./res/shaders/lightFrag.glsl", .fragment) catch unreachable;
    defer fragmentLight.destroy();

    const materialLight = Material.init(vertexDefault, fragmentDefault);
    const materialCube = Material.init(vertexLight, fragmentLight);

    var meshCube = alloc.create(Mesh) catch unreachable;
    meshCube.* = Mesh.init(alloc, geometryCube, materialCube);
    var meshLight = alloc.create(Mesh) catch unreachable;
    meshLight.* = Mesh.init(alloc, geometryLight, materialLight);
    meshLight.scale = .{ 0.3, 0.3, 0.3 };
    meshCube.addChild(meshLight) catch unreachable;

    var camera = Camera.init(45, .{ 0, 0, 7 });
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    return Self{
        .allocator = alloc,
        .window = win,
        .meshCube = meshCube,
        .meshLight = meshLight,
        .camera = camera,
        .cubePos = .{ 0, 0, 0 },
        .lightPos = .{ 0, 0, 0 },
        .cubeColor = .{ 1.0, 0.5, 0.31 },
        .rotAngle = 0,
    };
}

pub fn draw(scene: *Self, dt: f32) void {
    Renderer.setClearColor(0.1, 0.1, 0.1, 1);

    var winSize = scene.window.getFramebufferSize();

    scene.camera.updateViewMatrix();

    var projection: glm.mat4 = undefined;

    const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));
    glm.glmc_perspective(glm.glm_rad(scene.fov), aspect, 0.1, 100, &projection);

    //var lightScale: glm.vec3 = .{ 0.3, 0.3, 0.3 };
    const lightR, const lightG, const lightB, _ = scene.meshLight.material.color;
    scene.meshLight.bind();
    //scene.geometryLight.bind();
    //scene.materialLight.bind();
    scene.meshLight.setViewMatrix(scene.camera.getViewMatrix());
    scene.meshLight.setProjectionMatrix(projection);
    //scene.materialLight.shader.setUniformMat4f("view", scene.camera.getViewMatrix());
    //scene.materialLight.shader.setUniformMat4f("projection", projection);
    //scene.lightPos[0] = @sin(scene.rotAngle / 4) * 2;
    //scene.lightPos[1] = @cos(scene.rotAngle / 4) * 2;
    //scene.lightPos[2] = @sin(scene.rotAngle / 2) * 1;
    scene.lightPos = .{ 1.2, 1.2, 1.2 };
    scene.meshLight.position = scene.lightPos;
    //scene.meshLight.rotation = .{ glm.glm_rad(scene.rotAngle) * 100, 0, 0 };
    scene.meshLight.updateModelMatrix();
    //glm.glmc_mat4_identity(&model);
    //glm.glmc_translate(&model, &scene.lightPos);
    //glm.glmc_scale(&model, &lightScale);
    //glm.glmc_rotate(&model, 0, &rotAxis);
    //scene.materialLight.shader.setUniformMat4f("model", model);
    scene.meshLight.material.shader.setUniform3f("lightColor", lightR, lightG, lightB);
    //scene.materialLight.shader.setUniform3f("lightColor", lightR, lightG, lightB);
    Renderer.draw(scene.meshLight.geometry.vertexArray, scene.meshLight.geometry.indexBuffer, scene.meshLight.material.shader);

    //scene.geometryCube.bind();
    //scene.materialCube.bind();
    scene.meshCube.bind();
    scene.meshCube.setViewMatrix(scene.camera.getViewMatrix());
    scene.meshCube.setProjectionMatrix(projection);
    //scene.materialCube.shader.setUniformMat4f("view", scene.camera.getViewMatrix());
    //scene.materialCube.shader.setUniformMat4f("projection", projection);
    scene.meshCube.position = scene.cubePos;
    scene.meshCube.rotation = .{ glm.glm_rad(scene.rotAngle) * 10, 0, 0 };
    //glm.glmc_mat4_identity(&model);
    //glm.glmc_translate(&model, &scene.cubePos);
    //glm.glmc_rotate(&model, glm.glm_rad(scene.rotAngle), &rotAxis);
    //scene.materialCube.shader.setUniformMat4f("model", model);
    scene.meshCube.updateModelMatrix();

    const objectR, const objectG, const objectB = scene.cubeColor;
    var lightPosView: glm.vec3 = undefined;
    var viewMatrix: glm.mat4 = scene.camera.getViewMatrix();
    glm.glmc_mat4_mulv3(&viewMatrix, &scene.lightPos, 1.0, &lightPosView);

    scene.meshCube.material.shader.setUniform3f("light.position", lightPosView[0], lightPosView[1], lightPosView[2]);
    scene.meshCube.material.shader.setUniform3f("light.ambient", lightR * 0.2, lightG * 0.2, lightB * 0.2);
    scene.meshCube.material.shader.setUniform3f("light.diffuse", lightR * 0.5, lightG * 0.5, lightB * 0.5);
    scene.meshCube.material.shader.setUniform3f("light.specular", lightR, lightG, lightB);

    scene.meshCube.material.shader.setUniform3f("material.ambient", objectR, objectG, objectB);
    scene.meshCube.material.shader.setUniform3f("material.diffuse", objectR, objectG, objectB);
    scene.meshCube.material.shader.setUniform3f("material.specular", 0.5, 0.5, 0.5);
    scene.meshCube.material.shader.setUniform1f("material.shininess", 32);
    Renderer.draw(scene.meshCube.geometry.vertexArray, scene.meshCube.geometry.indexBuffer, scene.meshCube.material.shader);

    scene.rotAngle += 3 * dt;

    if (ImGui.enabled) {
        _ = ImGui.c.igBegin("Scene controls", null, 0);
        _ = ImGui.c.igColorEdit3("Light color", &scene.meshLight.material.color, 0);
        _ = ImGui.c.igColorEdit3("Cube color", &scene.cubeColor, 0);
        _ = ImGui.c.igSliderFloat3("Light position", &scene.lightPos, -10, 10);
        _ = ImGui.c.igSliderFloat3("Cube position", &scene.cubePos, -10, 10);
        ImGui.c.igEnd();
    }

    winSize = scene.window.getFramebufferSize();
}

pub fn destroy(scene: *Self) void {
    scene.meshCube.destroy();
    //scene.meshLight.destroy();
    //scene.geometryCube.destroy();
    //scene.geometryLight.destroy();
    //scene.materialCube.destroy();
    //scene.materialLight.destroy();
}

pub fn onSceneReentry(scene: *Self) void {
    const winSize = scene.window.getSize();
    scene.camera.setPosition(.{ 0, 0, 7 });
    scene.camera.resetMousePosition(@floatFromInt(winSize.width), @floatFromInt(winSize.height));
}

pub fn handleInput(scene: *Self, window: glfw.Window, dt: f32) void {
    const cameraSpeed: f32 = 5 * dt;
    if (window.getKey(glfw.Key.w) == glfw.Action.press)
        scene.camera.moveInDirection(Camera.directions.up, cameraSpeed);

    if (window.getKey(glfw.Key.s) == glfw.Action.press)
        scene.camera.moveInDirection(Camera.directions.down, cameraSpeed);

    if (window.getKey(glfw.Key.a) == glfw.Action.press)
        scene.camera.moveInDirection(Camera.directions.left, cameraSpeed);

    if (window.getKey(glfw.Key.d) == glfw.Action.press)
        scene.camera.moveInDirection(Camera.directions.right, cameraSpeed);
}

pub fn handleMouse(scene: *Self, xPos: f32, yPos: f32) void {
    scene.camera.updateMousePosition(xPos, yPos);
}

pub fn handleScroll(scene: *Self, _: f32, yOffset: f32) void {
    scene.fov = std.math.clamp(scene.fov - yOffset * 2, 1, 90);
}

pub fn getSceneName(_: *Self) []const u8 {
    return "Lighting Scene";
}
