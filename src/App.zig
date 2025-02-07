const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const vb = @import("VertexBuffer.zig");
const ib = @import("IndexBuffer.zig");
const va = @import("VertexArray.zig");
const vbl = @import("VertexBufferLayout.zig");
const Shader = @import("Shader.zig");
const Renderer = @import("Renderer.zig");
const Texture = @import("Texture.zig");
const glm = @import("glm.zig").unaligned;
const ImGui = @import("imgui.zig");
const Camera = @import("Camera.zig");
const utils = @import("utils.zig");
const log = std.log;
const openGlLog = utils.scopes.openGlLog;
const glfwLog = utils.scopes.glfwLog;

var gl_procs: gl.ProcTable = undefined;

const App = @This();

window: glfw.Window,
allocator: std.mem.Allocator,
ImGuiCtx: ImGui,

var camera: Camera = undefined;

pub fn init(allocator: std.mem.Allocator) !App {
    log.info("Initializing application", .{});

    glfw.setErrorCallback(utils.glfwErrorCallback);

    if (!glfw.init(.{}))
        return error.GlfwInitFailed;

    errdefer glfw.terminate();
    const window = glfw.Window.create(1440, 1080, "Fuckery", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
        .context_debug = true,
    }) orelse return error.InitFailed;
    errdefer window.destroy();

    glfwLog.info("Created window '{s}' of size {d}x{d}", .{ "Fuckery", 1440, 1080 });

    glfw.makeContextCurrent(window);
    errdefer glfw.makeContextCurrent(null);

    if (!gl_procs.init(glfw.getProcAddress))
        return error.GlInitFailed;

    gl.makeProcTableCurrent(&gl_procs);
    errdefer gl.makeProcTableCurrent(null);

    glfw.swapInterval(1);
    window.setFramebufferSizeCallback(frameBufferSizeCallback);

    const imgGuiCtx = ImGui.init(window) catch unreachable;

    // Debug callback setup
    var flags: c_int = undefined;
    gl.GetIntegerv(gl.CONTEXT_FLAGS, @ptrCast(&flags));
    if (@hasDecl(gl, "DEBUG_OUTPUT")) {
        if (flags != gl.FALSE and gl.CONTEXT_FLAGS != 0) {
            gl.Enable(gl.DEBUG_OUTPUT);
            gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
            gl.DebugMessageCallback(utils.glDebugOutput, null);
            gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, null, gl.TRUE);

            openGlLog.debug("Debugging enabled", .{});
        }
    } else openGlLog.debug("Debugging not available", .{});

    camera = Camera.init(45);

    openGlLog.info("Version: {s}", .{gl.GetString(gl.VERSION) orelse ""});
    log.info("Initalization done", .{});

    return App{ .window = window, .allocator = allocator, .ImGuiCtx = imgGuiCtx };
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

var fov: f32 = 45;

var deltaTime: f32 = 0;
var lastFrame: f32 = 0;

pub fn loop(app: App) void {
    var winSize = app.window.getFramebufferSize();
    camera.mouse.lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    camera.mouse.lastY = @as(f32, @floatFromInt(winSize.height)) / 2;

    //gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    //gl.Enable(gl.BLEND);
    gl.Enable(gl.DEPTH_TEST);

    app.window.setInputMode(glfw.Window.InputMode.cursor, glfw.Window.InputModeCursor.disabled);
    app.window.setScrollCallback(scrollCallback);
    app.window.setCursorPosCallback(mouseCallback);

    var vao = va.init();
    var vbo = vb.init(&position, 4 * 6 * 5 * @sizeOf(f32));
    defer vbo.destroy();

    var vblo = vbl.init(app.allocator);
    defer vblo.destroy();
    vblo.push(3) catch unreachable;
    vblo.push(2) catch unreachable;

    vao.addBuffer(vbo, vblo);

    var ibo = ib.init(&indices, 6 * 6);
    defer ibo.destroy();

    var shader = Shader.init("./res/shaders/vert.glsl", "./res/shaders/frag.glsl") catch unreachable;
    shader.bind();

    const texture = Texture.init(app.allocator, "./res/textures/sauron_eye.png") catch unreachable;
    texture.bind(0);
    shader.setUniform1i("u_Texture", 0);

    defer shader.unbind();

    vao.bind();
    defer vao.destroy();

    var model: glm.mat4 = undefined;
    var projection: glm.mat4 = undefined;

    var rotAxis: glm.vec3 = .{ 1, 1, 1 };

    const rand = std.crypto.random;
    var poses: [6]glm.vec3 = undefined;
    poses[0] = glm.vec3{ 0, 0, 0 };
    for (1..poses.len) |i| {
        const mx: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const my: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const mz: f32 = @floatFromInt(rand.intRangeAtMost(i32, -500, -100));
        poses[i] = glm.vec3{ mx / 40, my / 40, mz / 50 };
    }

    var rotAngle: f32 = 0.0;
    const io = ImGui.c.igGetIO();
    Renderer.setClearColor(0.2, 0.4, 0.4, 1.0);

    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    while (!app.window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        app.handleInput();

        Renderer.clear();
        ImGui.newFrame();

        camera.updateViewMatrix();

        const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));
        glm.glmc_perspective(glm.glm_rad(fov), aspect, 0.1, 100, &projection);

        shader.setUniformMat4f("view", camera.getViewMatrix());
        shader.setUniformMat4f("projection", projection);

        for (0..5) |i| {
            glm.glmc_mat4_identity(&model);
            glm.glmc_translate(&model, &poses[i]);
            glm.glmc_rotate(&model, rotAngle - @as(f32, @floatFromInt(i * 3)), &rotAxis);
            shader.setUniformMat4f("model", model);

            Renderer.draw(vao, ibo, shader);
        }

        rotAngle += 3 * deltaTime;

        ImGui.c.igSetNextWindowPos(.{ .x = io.*.DisplaySize.x - 200, .y = 5 }, ImGui.c.ImGuiCond_Always);
        ImGui.c.igSetNextWindowSize(.{ .x = 0, .y = 50 }, ImGui.c.ImGuiCond_Always);
        _ = ImGui.c.igBegin("Framerate", null, ImGui.c.ImGuiWindowFlags_NoDecoration | ImGui.c.ImGuiWindowFlags_NoBackground | ImGui.c.ImGuiWindowFlags_NoInputs);

        ImGui.c.igText("%.3f ms/frame (%.1f FPS)", 1000.0 / io.*.Framerate, io.*.Framerate);
        ImGui.c.igText("%.3f deltaTime", deltaTime);
        ImGui.c.igEnd();

        camera.imGuiDebugWindow();

        ImGui.render();

        winSize = app.window.getFramebufferSize();
        app.window.swapBuffers();

        glfw.pollEvents();
    }
}

pub fn destroy(app: App) void {
    log.info("Destroying application", .{});

    app.ImGuiCtx.destroy();
    gl.makeProcTableCurrent(null);
    glfw.makeContextCurrent(null);
    app.window.destroy();
    glfw.terminate();
}

var cursorHidden = true;
var start: f32 = 0;
fn handleInput(app: App) void {
    if (app.window.getKey(glfw.Key.escape) == glfw.Action.press)
        app.window.setShouldClose(true);

    if (app.window.getKey(glfw.Key.left_control) == glfw.Action.press) blk: {
        if (glfw.getTime() - start < 0.5) break :blk;

        log.debug("Mouse mode changed", .{});

        app.window.setInputMode(glfw.Window.InputMode.cursor, if (cursorHidden)
            glfw.Window.InputModeCursor.captured
        else
            glfw.Window.InputModeCursor.disabled);

        if (!cursorHidden)
            app.window.setCursorPos(camera.mouse.lastX, camera.mouse.lastY);

        cursorHidden = !cursorHidden;
        start = @floatCast(glfw.getTime());
    }

    const cameraSpeed: f32 = 5 * deltaTime;
    if (app.window.getKey(glfw.Key.w) == glfw.Action.press)
        camera.moveInDirection(Camera.directions.up, cameraSpeed);

    if (app.window.getKey(glfw.Key.s) == glfw.Action.press)
        camera.moveInDirection(Camera.directions.down, cameraSpeed);

    if (app.window.getKey(glfw.Key.a) == glfw.Action.press)
        camera.moveInDirection(Camera.directions.left, cameraSpeed);

    if (app.window.getKey(glfw.Key.d) == glfw.Action.press)
        camera.moveInDirection(Camera.directions.right, cameraSpeed);
}

var firstMouseCb = true;
fn mouseCallback(window: glfw.Window, xpos: f64, ypos: f64) void {
    ImGui.igGlfw.cImGui_ImplGlfw_CursorPosCallback(@ptrCast(window.handle), xpos, ypos);

    if (firstMouseCb) {
        firstMouseCb = false;
        return;
    }

    if (!cursorHidden) return;

    camera.updateMousePosition(@floatCast(xpos), @floatCast(ypos));
}

fn scrollCallback(_: glfw.Window, _: f64, yoffset: f64) void {
    fov = std.math.clamp(fov - @as(f32, @floatCast(yoffset)) * 2, 1, 90);
}

fn frameBufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

test "detect memory leak" {
    const app = App.init(std.testing.allocator) catch {
        try std.testing.expect(false);
        return;
    };
    defer app.destroy();

    app.loop();
}
