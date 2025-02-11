const std = @import("std");
const builtin = @import("builtin");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const Shader = @import("../Shader.zig");
const Texture = @import("../Texture.zig");
const Camera = @import("../Camera.zig");
const Renderer = @import("../Renderer.zig");
const glm = @import("../glm.zig");
const cube = @import("../shapes.zig").cube;
const Geometry = @import("../Geometry.zig");

allocator: std.mem.Allocator,
window: glfw.Window,
camera: Camera,
shader: Shader,
poses: [6]glm.vec3,
geometry: Geometry,
texture: Texture,
fov: f32 = 45,
rotAngle: f32 = 0.0,

const Self = @This();

pub fn init(alloc: std.mem.Allocator, win: glfw.Window) Self {
    gl.Enable(gl.DEPTH_TEST);

    const winSize = win.getFramebufferSize();

    const geometry = cube.createGeometry(alloc, .{ .texture = true }) catch unreachable;

    var shader = Shader.init("./res/shaders/texVert.glsl", "./res/shaders/texFrag.glsl") catch unreachable;
    errdefer shader.destroy();
    shader.bind();

    var texture = Texture.init(alloc, "./res/textures/sauron_eye.png") catch unreachable;
    errdefer texture.destroy();
    texture.bind(0);
    shader.setUniform1i("u_Texture", 0);

    const rand = std.crypto.random;
    var poses: [6]glm.vec3 = undefined;
    poses[0] = glm.vec3{ 0, 0, 0 };
    for (1..poses.len) |i| {
        const mx: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const my: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const mz: f32 = @floatFromInt(rand.intRangeAtMost(i32, -500, -100));
        poses[i] = glm.vec3{ mx / 40, my / 40, mz / 50 };
    }

    var camera = Camera.init(45, .{ 0, 0, 20 });
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    return Self{
        .allocator = alloc,
        .window = win,
        .shader = shader,
        .camera = camera,
        .geometry = geometry,
        .texture = texture,
        .poses = poses,
    };
}

pub fn draw(scene: *Self, dt: f32) void {
    Renderer.setClearColor(0.2, 0.4, 0.4, 1.0);

    scene.texture.bind(0);
    scene.geometry.bind();
    var winSize = scene.window.getFramebufferSize();
    scene.camera.updateViewMatrix();

    var model: glm.mat4 = undefined;
    var projection: glm.mat4 = undefined;

    var rotAxis: glm.vec3 = .{ 1, 1, 1 };

    const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));
    glm.glmc_perspective(glm.glm_rad(scene.fov), aspect, 0.1, 100, &projection);

    scene.shader.bind();
    scene.shader.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.shader.setUniformMat4f("projection", projection);

    for (0..5) |i| {
        glm.glmc_mat4_identity(&model);
        glm.glmc_translate(&model, &scene.poses[i]);
        glm.glmc_rotate(&model, scene.rotAngle - @as(f32, @floatFromInt(i * 3)), &rotAxis);
        scene.shader.setUniformMat4f("model", model);

        Renderer.draw(scene.geometry.vertexArray, scene.geometry.indexBuffer, scene.shader);
    }

    scene.rotAngle += 3 * dt;

    if (comptime builtin.mode == .Debug)
        scene.camera.imGuiDebugWindow();

    scene.texture.unbind();

    winSize = scene.window.getFramebufferSize();
}

pub fn destroy(scene: *Self) void {
    scene.geometry.destroy();
    scene.texture.destroy();
    scene.shader.destroy();
}

pub fn onSceneReentry(scene: *Self) void {
    const winSize = scene.window.getSize();
    scene.camera.setPosition(.{ 0, 0, 20 });
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
    return "Default Scene";
}
