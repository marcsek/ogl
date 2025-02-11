const std = @import("std");
const builtin = @import("builtin");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const vb = @import("../VertexBuffer.zig");
const ib = @import("../IndexBuffer.zig");
const va = @import("../VertexArray.zig");
const vbl = @import("../VertexBufferLayout.zig");
const Shader = @import("../Shader.zig");
const Texture = @import("../Texture.zig");
const Camera = @import("../Camera.zig");
const ImGui = @import("../imgui.zig");
const Renderer = @import("../Renderer.zig");
const glm = @import("../glm.zig");
const cube = @import("../shapes.zig").cube;

allocator: std.mem.Allocator,
window: glfw.Window,
camera: Camera,
shaderDefault: Shader,
shaderLight: Shader,
vaoCube: va,
vaoLight: va,
vboCube: vb,
vboLight: vb,
ibo: ib,
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

    var vaoCube = va.init();
    errdefer va.destroy();

    var vboCube = vb.init(&cube.verticesNormals, 4 * 6 * 6 * @sizeOf(f32));
    errdefer vboCube.destroy();

    var vbloCube = vbl.init(alloc);
    defer vbloCube.destroy();
    vbloCube.push(3) catch unreachable;
    vbloCube.push(3) catch unreachable;

    vaoCube.addBuffers(vboCube, vbloCube);

    var vaoLight = va.init();
    errdefer va.destroy();

    var vboLight = vb.init(&cube.vertices, 4 * 6 * 3 * @sizeOf(f32));
    errdefer vboLight.destroy();

    var vbloLight = vbl.init(alloc);
    defer vbloLight.destroy();
    vbloLight.push(3) catch unreachable;

    vaoLight.addBuffers(vboLight, vbloLight);

    var ibo = ib.init(&cube.indices, 6 * 6);
    errdefer ibo.destroy();

    var shaderDefault = Shader.init("./res/shaders/defaultVert.glsl", "./res/shaders/defaultFrag.glsl") catch unreachable;
    errdefer shaderDefault.destroy();

    var shaderLight = Shader.init("./res/shaders/lightVert.glsl", "./res/shaders/lightFrag.glsl") catch unreachable;
    errdefer shaderLight.destroy();

    var camera = Camera.init(45, .{ 0, 0, 7 });
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    return Self{
        .allocator = alloc,
        .window = win,
        .shaderDefault = shaderDefault,
        .shaderLight = shaderLight,
        .camera = camera,
        .vaoCube = vaoCube,
        .vaoLight = vaoLight,
        .vboCube = vboCube,
        .vboLight = vboLight,
        .ibo = ibo,
        .cubePos = .{ 0, 0, 0 },
        .lightPos = .{ 0, 0, 0 },
        .lightColor = .{ 1.0, 1.0, 1.0 },
        .cubeColor = .{ 1.0, 0.5, 0.31 },
        .rotAngle = 0,
    };
}

pub fn draw(scene: *Self, dt: f32) void {
    Renderer.setClearColor(0.1, 0.1, 0.1, 1);

    var winSize = scene.window.getFramebufferSize();

    scene.camera.updateViewMatrix();

    var model: glm.mat4 = undefined;
    var projection: glm.mat4 = undefined;

    var rotAxis: glm.vec3 = .{ 1, 1, 1 };

    const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));
    glm.glmc_perspective(glm.glm_rad(scene.fov), aspect, 0.1, 100, &projection);

    var lightScale: glm.vec3 = .{ 0.3, 0.3, 0.3 };
    const lightR, const lightG, const lightB = scene.lightColor;
    scene.vaoLight.bind();
    scene.shaderDefault.bind();
    scene.shaderDefault.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.shaderDefault.setUniformMat4f("projection", projection);
    scene.lightPos[0] = @sin(scene.rotAngle / 4) * 2;
    scene.lightPos[1] = @cos(scene.rotAngle / 4) * 2;
    scene.lightPos[2] = @sin(scene.rotAngle / 2) * 1;
    glm.glmc_mat4_identity(&model);
    glm.glmc_translate(&model, &scene.lightPos);
    glm.glmc_scale(&model, &lightScale);
    //glm.glmc_rotate(&model, 0, &rotAxis);
    scene.shaderDefault.setUniformMat4f("model", model);
    scene.shaderDefault.setUniform3f("lightColor", lightR, lightG, lightB);
    Renderer.draw(scene.vaoLight, scene.ibo, scene.shaderDefault);

    scene.vaoCube.bind();
    scene.shaderLight.bind();
    scene.shaderLight.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.shaderLight.setUniformMat4f("projection", projection);
    glm.glmc_mat4_identity(&model);
    glm.glmc_translate(&model, &scene.cubePos);
    glm.glmc_rotate(&model, 0 * glm.glm_rad(scene.rotAngle), &rotAxis);
    scene.shaderLight.setUniformMat4f("model", model);
    Renderer.draw(scene.vaoCube, scene.ibo, scene.shaderLight);

    const objectR, const objectG, const objectB = scene.cubeColor;
    scene.shaderLight.setUniform3f("material.ambient", objectR, objectG, objectB);
    scene.shaderLight.setUniform3f("material.diffuse", objectR, objectG, objectB);
    scene.shaderLight.setUniform3f("material.specular", 0.5, 0.5, 0.5);
    scene.shaderLight.setUniform1f("material.shininess", 32);

    var lightPosView: glm.vec3 = undefined;
    var viewMatrix: glm.mat4 = scene.camera.getViewMatrix();
    glm.glmc_mat4_mulv3(&viewMatrix, &scene.lightPos, 1.0, &lightPosView);

    scene.shaderLight.setUniform3f("light.position", lightPosView[0], lightPosView[1], lightPosView[2]);
    scene.shaderLight.setUniform3f("light.ambient", lightR * 0.2, lightG * 0.2, lightB * 0.2);
    scene.shaderLight.setUniform3f("light.diffuse", lightR * 0.5, lightG * 0.5, lightB * 0.5);
    scene.shaderLight.setUniform3f("light.specular", lightR, lightG, lightB);

    scene.rotAngle += 3 * dt;

    if (comptime builtin.mode == .Debug) {
        _ = ImGui.c.igBegin("Scene controls", null, 0);
        _ = ImGui.c.igColorEdit3("Light color", &scene.lightColor, 0);
        _ = ImGui.c.igColorEdit3("Cube color", &scene.cubeColor, 0);
        _ = ImGui.c.igSliderFloat3("Light position", &scene.lightPos, -10, 10);
        ImGui.c.igEnd();
    }

    winSize = scene.window.getFramebufferSize();
}

pub fn destroy(scene: *Self) void {
    scene.vboCube.destroy();
    scene.vboLight.destroy();
    scene.vaoCube.destroy();
    scene.vaoLight.destroy();
    scene.ibo.destroy();
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
    return "Lighting Scene";
}
