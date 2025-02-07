const std = @import("std");
const glfw = @import("mach-glfw");
const vb = @import("VertexBuffer.zig");
const ib = @import("IndexBuffer.zig");
const va = @import("VertexArray.zig");
const vbl = @import("VertexBufferLayout.zig");
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");
const Camera = @import("Camera.zig");
const ImGui = @import("imgui.zig");
const Renderer = @import("Renderer.zig");
const glm = @import("glm.zig").unaligned;

const Self = @This();

allocator: std.mem.Allocator,
window: glfw.Window,
camera: Camera = undefined,
shader: Shader = undefined,

var poses: [6]glm.vec3 = undefined;
var vao: va = undefined;
var ibo: ib = undefined;
var vblo: vbl = undefined;
var vbo: vb = undefined;
var texture: Texture = undefined;
pub fn init(alloc: std.mem.Allocator, win: glfw.Window) Self {
    const winSize = win.getFramebufferSize();

    vao = va.init();
    vbo = vb.init(&position, 4 * 6 * 5 * @sizeOf(f32));

    vblo = vbl.init(alloc);
    vblo.push(3) catch unreachable;
    vblo.push(2) catch unreachable;

    vao.addBuffer(vbo, vblo);

    ibo = ib.init(&indices, 6 * 6);

    var shader = Shader.init("./res/shaders/vert.glsl", "./res/shaders/frag.glsl") catch unreachable;
    shader.bind();

    texture = Texture.init(alloc, "./res/textures/sauron_eye.png") catch unreachable;
    texture.bind(0);
    shader.setUniform1i("u_Texture", 0);

    const rand = std.crypto.random;
    poses[0] = glm.vec3{ 0, 0, 0 };
    for (1..poses.len) |i| {
        const mx: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const my: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const mz: f32 = @floatFromInt(rand.intRangeAtMost(i32, -500, -100));
        poses[i] = glm.vec3{ mx / 40, my / 40, mz / 50 };
    }

    var camera = Camera.init(45);
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    return Self{ .allocator = alloc, .window = win, .shader = shader, .camera = camera };
}

var fov: f32 = 45;
var rotAngle: f32 = 0.0;
pub fn draw(scene: *Self, dt: f32) void {
    vao.bind();
    var winSize = scene.window.getFramebufferSize();
    scene.camera.updateViewMatrix();

    var model: glm.mat4 = undefined;
    var projection: glm.mat4 = undefined;

    var rotAxis: glm.vec3 = .{ 1, 1, 1 };

    const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));
    glm.glmc_perspective(glm.glm_rad(fov), aspect, 0.1, 100, &projection);

    scene.shader.setUniformMat4f("view", scene.camera.getViewMatrix());
    scene.shader.setUniformMat4f("projection", projection);

    for (0..5) |i| {
        glm.glmc_mat4_identity(&model);
        glm.glmc_translate(&model, &poses[i]);
        glm.glmc_rotate(&model, rotAngle - @as(f32, @floatFromInt(i * 3)), &rotAxis);
        scene.shader.setUniformMat4f("model", model);

        Renderer.draw(vao, ibo, scene.shader);
    }

    rotAngle += 3 * dt;

    scene.camera.imGuiDebugWindow();

    winSize = scene.window.getFramebufferSize();
}

pub fn destroy(scene: *Self) void {
    vao.destroy();
    ibo.destroy();
    vblo.destroy();
    vbo.destroy();
    texture.destroy();
    scene.shader.destroy();
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

pub fn handleScroll(_: *Self, _: f32, yOffset: f32) void {
    fov = std.math.clamp(fov - yOffset * 2, 1, 90);
}

// zig fmt: off
const position = [_]f32{ 
// Front
-0.5, -0.5,  0.5,  0.0, 0.0,
 0.5, -0.5,  0.5,  1.0, 0.0,
 0.5,  0.5,  0.5,  1.0, 1.0,
-0.5,  0.5,  0.5,  0.0, 1.0,
// Back
-0.5, -0.5, -0.5,  1.0, 0.0,
-0.5,  0.5, -0.5,  1.0, 1.0,
 0.5,  0.5, -0.5,  0.0, 1.0,
 0.5, -0.5, -0.5,  0.0, 0.0,
// Left
-0.5, -0.5, -0.5,  0.0, 0.0,
-0.5, -0.5,  0.5,  1.0, 0.0,
-0.5,  0.5,  0.5,  1.0, 1.0,
-0.5,  0.5, -0.5,  0.0, 1.0,
// Right
 0.5, -0.5, -0.5,  1.0, 0.0,
 0.5,  0.5, -0.5,  1.0, 1.0,
 0.5,  0.5,  0.5,  0.0, 1.0,
 0.5, -0.5,  0.5,  0.0, 0.0,
// Top
-0.5,  0.5, -0.5,  0.0, 0.0,
-0.5,  0.5,  0.5,  0.0, 1.0,
 0.5,  0.5,  0.5,  1.0, 1.0,
 0.5,  0.5, -0.5,  1.0, 0.0,
// Bottom
-0.5, -0.5, -0.5,  0.0, 1.0,
 0.5, -0.5, -0.5,  1.0, 1.0,
 0.5, -0.5,  0.5,  1.0, 0.0,
-0.5, -0.5,  0.5,  0.0, 0.0,
};
// zig fmt: on

const indices = [_]u32{
    0, 1, 2, 2, 3, 0, // Back face
    4, 5, 6, 6, 7, 4, // Front face
    8, 9, 10, 10, 11, 8, // Left face
    12, 13, 14, 14, 15, 12, // Right face
    16, 17, 18, 18, 19, 16, // Bottom face
    20, 21, 22, 22, 23, 20, // Top face;
};
