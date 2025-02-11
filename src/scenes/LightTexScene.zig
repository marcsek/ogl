const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const Shader = @import("../Shader.zig");
const Texture = @import("../Texture.zig");
const Camera = @import("../Camera.zig");
const ImGui = @import("../imgui.zig");
const Renderer = @import("../Renderer.zig");
const glm = @import("../glm.zig");
const cube = @import("../shapes.zig").cube;
const Geometry = @import("../Geometry.zig");

allocator: std.mem.Allocator,
window: glfw.Window,
camera: Camera,
shaderDefault: Shader,
shaderLight: Shader,
geometryCube: Geometry,
geometryLight: Geometry,
fov: f32 = 45,
cubePos: glm.vec3,
lightPos: glm.vec3,
lightColor: glm.vec3,
cubeColor: glm.vec3,
rotAngle: f32,
texture: Texture,
textureSpec: Texture,

const Self = @This();

pub fn init(alloc: std.mem.Allocator, win: glfw.Window) Self {
    gl.Enable(gl.DEPTH_TEST);

    const winSize = win.getFramebufferSize();

    const geometryCube = cube.createGeometry(alloc, .{ .texture = true, .normals = true }) catch unreachable;
    const geometryLight = cube.createGeometry(alloc, .{}) catch unreachable;

    var shaderDefault = Shader.init("./res/shaders/defaultVert.glsl", "./res/shaders/defaultFrag.glsl") catch unreachable;
    errdefer shaderDefault.destroy();

    var shaderLight = Shader.init("./res/shaders/lightTexVert.glsl", "./res/shaders/lightTexSpotFrag.glsl") catch unreachable;
    errdefer shaderLight.destroy();

    shaderLight.bind();
    const texture = Texture.init(alloc, "./res/textures/container.png") catch unreachable;
    errdefer texture.destroy();
    const textureSpec = Texture.init(alloc, "./res/textures/container_specular.png") catch unreachable;
    errdefer textureSpec.destroy();
    const textureEmis = Texture.init(alloc, "./res/textures/emmission.jpg") catch unreachable;
    errdefer textureSpec.destroy();
    texture.bind(0);
    textureSpec.bind(1);
    textureEmis.bind(2);

    shaderLight.setUniform1i("material.diffuse", 0);
    shaderLight.setUniform1i("material.specular", 1);
    shaderLight.setUniform1i("material.emission", 2);

    shaderLight.setUniform1f("light.constant", 1.0);
    shaderLight.setUniform1f("light.linear", 0.09);
    shaderLight.setUniform1f("light.quadratic", 0.032);

    shaderLight.setUniform1f("light.cutOff", @cos(glm.glm_rad(12.5)));
    shaderLight.setUniform1f("light.cutOffOuter", @cos(glm.glm_rad(17.5)));

    var camera = Camera.init(45, .{ 0, 0, 7 });
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    return Self{
        .allocator = alloc,
        .window = win,
        .shaderDefault = shaderDefault,
        .shaderLight = shaderLight,
        .camera = camera,
        .geometryCube = geometryCube,
        .geometryLight = geometryLight,
        .cubePos = .{ 0, 0, 0 },
        .lightPos = .{ 1.2, 0.5, 1.0 },
        .lightColor = .{ 1.0, 1.0, 1.0 },
        .cubeColor = .{ 1.0, 0.5, 0.31 },
        .rotAngle = 0,
        .texture = texture,
        .textureSpec = textureSpec,
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

    scene.texture.bind(0);
    scene.textureSpec.bind(1);

    var lightScale: glm.vec3 = .{ 0.3, 0.3, 0.3 };
    const lightR, const lightG, const lightB = scene.lightColor;
    scene.geometryLight.bind();
    scene.shaderDefault.bind();
    scene.shaderDefault.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.shaderDefault.setUniformMat4f("projection", projection);
    //scene.lightPos[0] = @sin(scene.rotAngle / 4) * 2;
    //scene.lightPos[1] = @cos(scene.rotAngle / 4) * 2;
    //scene.lightPos[2] = @sin(scene.rotAngle / 2) * 1;
    glm.glmc_mat4_identity(&model);
    glm.glmc_translate(&model, &scene.lightPos);
    glm.glmc_scale(&model, &lightScale);
    //glm.glmc_rotate(&model, 0, &rotAxis);
    scene.shaderDefault.setUniformMat4f("model", model);
    scene.shaderDefault.setUniform3f("lightColor", lightR, lightG, lightB);
    Renderer.draw(scene.geometryLight.vertexArray, scene.geometryLight.indexBuffer, scene.shaderDefault);

    scene.geometryCube.bind();
    scene.shaderLight.bind();
    scene.shaderLight.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.shaderLight.setUniformMat4f("projection", projection);
    glm.glmc_mat4_identity(&model);
    glm.glmc_translate(&model, &scene.cubePos);
    glm.glmc_rotate(&model, 0 * glm.glm_rad(scene.rotAngle), &rotAxis);
    scene.shaderLight.setUniformMat4f("model", model);

    scene.shaderLight.setUniform1f("material.shininess", 64);

    var lightPosView: glm.vec3 = undefined;
    var viewMatrix: glm.mat4 = scene.camera.getViewMatrix();
    glm.glmc_mat4_mulv3(&viewMatrix, &scene.camera.position, 1.0, &lightPosView);

    var lightDirView: glm.vec3 = undefined;
    glm.glmc_mat4_mulv3(&viewMatrix, &scene.camera.front, 0.0, &lightDirView);
    glm.glmc_vec3_normalize(&lightDirView);

    scene.shaderLight.setUniform3f("light.position", lightPosView[0], lightPosView[1], lightPosView[2]);
    scene.shaderLight.setUniform3f("light.direction", lightDirView[0], lightDirView[1], lightDirView[2]);
    scene.shaderLight.setUniform3f("light.ambient", lightR * 0.1, lightG * 0.1, lightB * 0.1);
    scene.shaderLight.setUniform3f("light.diffuse", lightR * 0.5, lightG * 0.5, lightB * 0.5);
    scene.shaderLight.setUniform3f("light.specular", lightR, lightG, lightB);
    Renderer.draw(scene.geometryCube.vertexArray, scene.geometryCube.indexBuffer, scene.shaderLight);

    scene.rotAngle += 3 * dt;

    _ = ImGui.c.igBegin("Scene controls", null, 0);
    _ = ImGui.c.igColorEdit3("Light color", &scene.lightColor, 0);
    _ = ImGui.c.igSliderFloat3("Light position", &scene.lightPos, -10, 10);
    ImGui.c.igEnd();

    winSize = scene.window.getFramebufferSize();
    gl.Disable(gl.BLEND);
}

pub fn destroy(scene: *Self) void {
    scene.geometryCube.destroy();
    scene.geometryLight.destroy();
    scene.shaderDefault.destroy();
    scene.shaderLight.destroy();
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
