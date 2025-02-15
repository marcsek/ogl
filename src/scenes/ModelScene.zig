const std = @import("std");
const builtin = @import("builtin");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const ImGui = @import("../imgui.zig");
const Texture = @import("../Texture.zig");
const Camera = @import("../Camera.zig");
const Geometry = @import("../Geometry.zig");
const Material = @import("../Material.zig");
const Shader = @import("../Shader.zig");
const Mesh = @import("../Mesh.zig");
const Renderer = @import("../Renderer.zig");
const glm = @import("../glm.zig");
const assimp = @import("../assimp.zig");
const ModelLoader = @import("../ModelLoader.zig");

allocator: std.mem.Allocator,
window: glfw.Window,
camera: Camera,
meshes: []Mesh,
fov: f32 = 45,

const Self = @This();

pub fn init(alloc: std.mem.Allocator, win: glfw.Window) Self {
    gl.Enable(gl.DEPTH_TEST);

    const winSize = win.getFramebufferSize();

    const vertexShader = Shader.init("./res/shaders/lightTexVert.glsl", .vertex) catch unreachable;
    const fragmentShader = Shader.init("./res/shaders/lightTexFrag.glsl", .fragment) catch unreachable;
    //const vertexShader = Shader.init("./res/shaders/defaultFrag.glsl", .vertex) catch unreachable;
    //const fragmentShader = Shader.init("./res/shaders/defaultVert.glsl", .fragment) catch unreachable;

    var loader = ModelLoader.init(alloc);
    defer loader.destroy();
    //const meshes = loader.loadFromFile("res/models/backpack/backpack.obj", vertexShader, fragmentShader) catch unreachable;
    const meshes = loader.loadFromFile("res/models/sword/source/SwordLow_UV.fbx", vertexShader, fragmentShader) catch unreachable;
    //const meshes = loader.loadFromFile("res/models/suzzane.obj", vertexShader, fragmentShader) catch unreachable;

    //const geometry = cube.createGeometry(alloc, .{ .texture = true }) catch unreachable;

    //var vertexShader = Shader.init("./res/shaders/lightVert.glsl", .vertex) catch unreachable;
    //errdefer vertexShader.destroy();

    //var fragmentShader = Shader.init("./res/shaders/lightFrag.glsl", .fragment) catch unreachable;
    //errdefer fragmentShader.destroy();

    //const material = Material.init(&vertexShader, &fragmentShader);

    var camera = Camera.init(45, .{ 0, 0, 20 });
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    return Self{
        .allocator = alloc,
        .window = win,
        .camera = camera,
        .meshes = meshes,
    };
}

pub fn draw(scene: *Self, dt: f32) void {
    Renderer.setClearColor(0.2, 0.4, 0.4, 1.0);
    _ = dt;

    //scene.material.bind();
    var winSize = scene.window.getFramebufferSize();
    scene.camera.updateViewMatrix();

    var model: glm.mat4 = undefined;
    var projection: glm.mat4 = undefined;
    const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));

    glm.glmc_perspective(glm.glm_rad(scene.fov), aspect, 0.1, 100, &projection);
    glm.glmc_mat4_identity(&model);

    for (scene.meshes) |*mesh| {
        mesh.material.bind();
        mesh.material.shader.setUniformMat4f("view", scene.camera.getViewMatrix());
        mesh.material.shader.setUniformMat4f("projection", projection);
        mesh.material.shader.setUniformMat4f("model", model);

        //const objectR, const objectG, const objectB, _ = mesh.material.color;
        //mesh.material.shader.setUniform3f("material.ambient", objectR, objectG, objectB);
        //mesh.material.shader.setUniform3f("material.diffuse", objectR, objectG, objectB);
        //mesh.material.shader.setUniform3f("material.specular", 0.5, 0.5, 0.5);
        mesh.material.shader.setUniform1f("material.shininess", 32);

        var lightPos: glm.vec3 = .{ 1.0, 0.5, 1.0 };
        var lightPosView: glm.vec3 = undefined;
        var viewMatrix: glm.mat4 = scene.camera.getViewMatrix();
        glm.glmc_mat4_mulv3(&viewMatrix, &lightPos, 1.0, &lightPosView);

        mesh.material.shader.setUniform3f("light.position", lightPosView[0], lightPosView[1], lightPosView[2]);
        mesh.material.shader.setUniform3f("light.ambient", 0.2, 0.2, 0.2);
        mesh.material.shader.setUniform3f("light.diffuse", 0.5, 0.5, 0.5);
        mesh.material.shader.setUniform3f("light.specular", 1.0, 1.0, 1.0);

        mesh.geometry.bind();
        Renderer.draw(mesh.geometry.vertexArray, mesh.geometry.indexBuffer, mesh.material.shader);
    }

    if (ImGui.enabled)
        scene.camera.imGuiDebugWindow();

    winSize = scene.window.getFramebufferSize();
}

pub fn destroy(scene: *Self) void {
    //scene.geometry.destroy();
    //scene.material.destroy();
    _ = scene;
}

pub fn onSceneReentry(scene: *Self) void {
    const winSize = scene.window.getSize();
    scene.camera.setPosition(.{ 0, 0, 10 });
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
    return "Model Scene";
}
