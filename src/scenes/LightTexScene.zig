const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const Texture = @import("../Texture.zig");
const Camera = @import("../Camera.zig");
const ImGui = @import("../imgui.zig");
const Geometry = @import("../Geometry.zig");
const Shader = @import("../Shader.zig");
const Material = @import("../Material.zig");
const Renderer = @import("../Renderer.zig");
const glm = @import("../glm.zig");
const cube = @import("../shapes.zig").cube;

allocator: std.mem.Allocator,
window: glfw.Window,
camera: Camera,
geometryCube: Geometry,
geometryLight: Geometry,
materialCube: Material,
materialLight: Material,
fov: f32 = 45,
cubePos: glm.vec3,
lightPos: glm.vec3,
lightColor: glm.vec3,
cubeColor: glm.vec3,
rotAngle: f32,

const Self = @This();

pub fn init(alloc: std.mem.Allocator, win: glfw.Window) Self {
    gl.Enable(gl.DEPTH_TEST);

    const winSize = win.getFramebufferSize();

    const geometryCube = cube.createGeometry(alloc, .{ .texture = true, .normals = true }) catch unreachable;
    const geometryLight = cube.createGeometry(alloc, .{}) catch unreachable;

    var vertexDefault = Shader.init("./res/shaders/defaultVert.glsl", .vertex) catch unreachable;
    errdefer vertexDefault.destroy();
    var fragmentDefault = Shader.init("./res/shaders/defaultFrag.glsl", .fragment) catch unreachable;
    errdefer fragmentDefault.destroy();

    var vertexLight = Shader.init("./res/shaders/lightTexVert.glsl", .vertex) catch unreachable;
    errdefer vertexLight.destroy();
    var fragmentLight = Shader.init("./res/shaders/lightTexSpotFrag.glsl", .fragment) catch unreachable;
    errdefer fragmentLight.destroy();

    const materialLight = Material.init(&vertexDefault, &fragmentDefault);
    var materialCube = Material.init(&vertexLight, &fragmentLight);

    const texture = Texture.init(alloc, "./res/textures/container.png") catch unreachable;
    errdefer texture.destroy();
    const textureSpec = Texture.init(alloc, "./res/textures/container_specular.png") catch unreachable;
    errdefer textureSpec.destroy();
    const textureEmis = Texture.init(alloc, "./res/textures/emmission.jpg") catch unreachable;
    errdefer textureSpec.destroy();

    materialCube.setTexture(texture, .color);
    materialCube.setTexture(textureSpec, .specular);
    materialCube.setTexture(textureEmis, .emission);

    materialCube.shader.setUniform1f("light.constant", 1.0);
    materialCube.shader.setUniform1f("light.linear", 0.09);
    materialCube.shader.setUniform1f("light.quadratic", 0.032);

    materialCube.shader.setUniform1f("light.cutOff", @cos(glm.glm_rad(12.5)));
    materialCube.shader.setUniform1f("light.cutOffOuter", @cos(glm.glm_rad(17.5)));

    var camera = Camera.init(45, .{ 0, 0, 7 });
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    return Self{
        .allocator = alloc,
        .window = win,
        .camera = camera,
        .geometryCube = geometryCube,
        .geometryLight = geometryLight,
        .materialCube = materialCube,
        .materialLight = materialLight,
        .cubePos = .{ 0, 0, 0 },
        .lightPos = .{ 1.2, 0.5, 1.0 },
        .lightColor = .{ 1.0, 1.0, 1.0 },
        .cubeColor = .{ 1.0, 0.5, 0.31 },
        .rotAngle = 0,
    };
}

pub fn draw(scene: *Self, dt: f32) void {
    Renderer.setClearColor(0.1, 0.1, 0.1, 1);
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.DST_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var winSize = scene.window.getFramebufferSize();

    scene.camera.updateViewMatrix();

    var model: glm.mat4 = undefined;
    var projection: glm.mat4 = undefined;

    var rotAxis: glm.vec3 = .{ 1, 1, 1 };

    const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));
    glm.glmc_perspective(glm.glm_rad(scene.fov), aspect, 0.1, 100, &projection);

    //scene.texture.bind(0);
    //scene.textureSpec.bind(1);

    var lightScale: glm.vec3 = .{ 0.3, 0.3, 0.3 };
    const lightR, const lightG, const lightB = scene.lightColor;
    scene.geometryLight.bind();
    scene.materialLight.bind();
    scene.materialLight.shader.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.materialLight.shader.setUniformMat4f("projection", projection);
    //scene.lightPos[0] = @sin(scene.rotAngle / 4) * 2;
    //scene.lightPos[1] = @cos(scene.rotAngle / 4) * 2;
    //scene.lightPos[2] = @sin(scene.rotAngle / 2) * 1;
    glm.glmc_mat4_identity(&model);
    glm.glmc_translate(&model, &scene.lightPos);
    glm.glmc_scale(&model, &lightScale);
    //glm.glmc_rotate(&model, 0, &rotAxis);
    scene.materialLight.shader.setUniformMat4f("model", model);
    scene.materialLight.shader.setUniform3f("lightColor", lightR, lightG, lightB);
    Renderer.draw(scene.geometryLight.vertexArray, scene.geometryLight.indexBuffer, scene.materialLight.shader);

    scene.geometryCube.bind();
    scene.materialCube.bind();
    scene.materialCube.shader.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.materialCube.shader.setUniformMat4f("projection", projection);
    glm.glmc_mat4_identity(&model);
    glm.glmc_translate(&model, &scene.cubePos);
    glm.glmc_rotate(&model, 0 * glm.glm_rad(scene.rotAngle), &rotAxis);
    scene.materialCube.shader.setUniformMat4f("model", model);

    scene.materialCube.shader.setUniform1f("material.shininess", 64);

    var lightPosView: glm.vec3 = undefined;
    var viewMatrix: glm.mat4 = scene.camera.getViewMatrix();
    glm.glmc_mat4_mulv3(&viewMatrix, &scene.camera.position, 1.0, &lightPosView);

    var lightDirView: glm.vec3 = undefined;
    glm.glmc_mat4_mulv3(&viewMatrix, &scene.camera.front, 0.0, &lightDirView);
    glm.glmc_vec3_normalize(&lightDirView);

    scene.materialCube.shader.setUniform3f("light.position", lightPosView[0], lightPosView[1], lightPosView[2]);
    scene.materialCube.shader.setUniform3f("light.direction", lightDirView[0], lightDirView[1], lightDirView[2]);
    scene.materialCube.shader.setUniform3f("light.ambient", lightR * 0.1, lightG * 0.1, lightB * 0.1);
    scene.materialCube.shader.setUniform3f("light.diffuse", lightR * 0.5, lightG * 0.5, lightB * 0.5);
    scene.materialCube.shader.setUniform3f("light.specular", lightR, lightG, lightB);
    Renderer.draw(scene.geometryCube.vertexArray, scene.geometryCube.indexBuffer, scene.materialCube.shader);

    scene.rotAngle += 3 * dt;

    if (ImGui.enabled) {
        _ = ImGui.c.igBegin("Scene controls", null, 0);
        _ = ImGui.c.igColorEdit3("Light color", &scene.lightColor, 0);
        _ = ImGui.c.igSliderFloat3("Light position", &scene.lightPos, -10, 10);
        ImGui.c.igEnd();
    }

    winSize = scene.window.getFramebufferSize();
    gl.Disable(gl.BLEND);
}

pub fn destroy(scene: *Self) void {
    scene.geometryCube.destroy();
    scene.geometryLight.destroy();
    scene.materialCube.destroy();
    scene.materialLight.destroy();
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
    return "Lighting Texture scene";
}
