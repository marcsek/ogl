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

var gl_procs: gl.ProcTable = undefined;

const App = @This();

window: glfw.Window,
allocator: std.mem.Allocator,
ImGuiCtx: ImGui,

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn init(allocator: std.mem.Allocator) !App {
    glfw.setErrorCallback(errorCallback);

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
    if (comptime std.meta.hasFn(gl, "CONTEXT_FLAGS")) {
        if (flags != gl.FALSE and gl.CONTEXT_FLAGS != 0) comptime {
            gl.Enable(gl.DEBUG_OUTPUT);
            gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
            gl.DebugMessageCallback(glDebugOutput, null);
            gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, null, gl.TRUE);
        };
    }

    std.debug.print("OpenGL version: {s}\n", .{gl.GetString(gl.VERSION) orelse ""});

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

pub fn loop(app: App) void {
    //gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    //gl.Enable(gl.BLEND);
    gl.Enable(gl.DEPTH_TEST);

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

    //var camera_diretion: glm.vec3 = undefined;
    //glm.glmc_vec3_sub(&camera_pos, &camera_target, &camera_diretion);
    //glm.glmc_vec3_normalize(&camera_diretion);

    //var camera_right: glm.vec3 = undefined;
    //glm.glmc_vec3_crossn(&up, &camera_diretion, &camera_right);

    //var camera_up: glm.vec3 = undefined;
    //glm.glm_vec3_cross(&camera_diretion, &camera_right, &camera_up);

    var shader = Shader.init("./res/shaders/vert.glsl", "./res/shaders/frag.glsl") catch unreachable;
    shader.bind();

    const texture = Texture.init(app.allocator, "./res/textures/sauron_eye.png") catch unreachable;
    texture.bind(0);
    shader.setUniform1i("u_Texture", 0);

    var view: glm.mat4 = undefined;
    var model: glm.mat4 = undefined;
    var projection: glm.mat4 = undefined;

    var camera_pos: glm.vec3 = .{ 0, 0, -5 };
    var camera_target: glm.vec3 = .{ 0, 0, 0 };
    var rotAxis: glm.vec3 = .{ 1, 1, 1 };
    var up: glm.vec3 = .{ 0, 1, 0 };

    shader.unbind();

    vao.bind();
    defer vao.destroy();

    const rand = std.crypto.random;
    var poses: [6]glm.vec3 = undefined;
    poses[0] = glm.vec3{ 0, 0, 0 };
    for (1..poses.len) |i| {
        const mx: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const my: f32 = @floatFromInt(rand.intRangeAtMost(i32, -200, 200));
        const mz: f32 = @floatFromInt(rand.intRangeAtMost(i32, 0, 500));
        poses[i] = glm.vec3{ mx / 40, my / 40, mz / 25 };
    }

    const radius: f32 = 20.0;
    var rotAngle: f32 = 0.0;
    var winSize = app.window.getFramebufferSize();

    const io = ImGui.c.igGetIO();
    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    Renderer.setClearColor(0.2, 0.4, 0.4, 1.0);
    while (!app.window.shouldClose()) {
        app.handleInput();

        Renderer.clear();
        ImGui.newFrame();

        glm.glmc_mat4_identity(&view);
        glm.glmc_lookat(&camera_pos, &camera_target, &up, &view);

        const aspect: f32 = @as(f32, @floatFromInt(winSize.width)) / @as(f32, @floatFromInt(winSize.height));
        glm.glmc_perspective(comptime glm.glm_rad(45), aspect, 0.1, 100, &projection);

        shader.setUniformMat4f("view", view);
        shader.setUniformMat4f("projection", projection);

        camera_pos[0] = @sin(@as(f32, @floatCast(glfw.getTime()))) * radius;
        camera_pos[2] = @cos(@as(f32, @floatCast(glfw.getTime()))) * radius;

        for (0..5) |i| {
            glm.glmc_mat4_identity(&model);
            glm.glmc_translate(&model, &poses[i]);
            glm.glmc_rotate(&model, rotAngle - @as(f32, @floatFromInt(i * 3)), &rotAxis);
            shader.setUniformMat4f("model", model);

            Renderer.draw(vao, ibo, shader);
        }

        rotAngle += 0.0205;

        ImGui.c.igSetNextWindowPos(.{ .x = io.*.DisplaySize.x - 200, .y = 5 }, ImGui.c.ImGuiCond_Always);
        _ = ImGui.c.igBegin("Framerate", null, ImGui.c.ImGuiWindowFlags_NoDecoration | ImGui.c.ImGuiWindowFlags_NoBackground | ImGui.c.ImGuiWindowFlags_NoInputs);

        ImGui.c.igText("%.3f ms/frame (%.1f FPS)", 1000.0 / io.*.Framerate, io.*.Framerate);
        ImGui.c.igEnd();

        _ = ImGui.c.igBegin("Debug", null, 0);
        _ = ImGui.c.igSliderFloat("cam-x", &camera_pos[0], -10, 10);
        _ = ImGui.c.igSliderFloat("cam-y", &camera_pos[1], -10, 10);
        _ = ImGui.c.igSliderFloat("cam-z", &camera_pos[2], -120, -0.1);
        ImGui.c.igEnd();

        ImGui.render();

        winSize = app.window.getFramebufferSize();
        app.window.swapBuffers();

        glfw.pollEvents();
    }
}

pub fn destroy(app: App) void {
    app.ImGuiCtx.destroy();
    gl.makeProcTableCurrent(null);
    glfw.makeContextCurrent(null);
    app.window.destroy();
    glfw.terminate();
}

fn handleInput(app: App) void {
    if (app.window.getKey(glfw.Key.escape) == glfw.Action.press) {
        app.window.setShouldClose(true);
    }
}

fn frameBufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

pub fn glDebugOutput(source: c_uint, debugType: c_uint, id: c_uint, severity: c_uint, _: c_int, message: [*:0]const u8, _: ?*const anyopaque) callconv(gl.APIENTRY) void {
    if (id == 131169 or id == 131185 or id == 131218 or id == 131204) return;

    const sourceString = switch (source) {
        gl.DEBUG_SOURCE_API => "API",
        gl.DEBUG_SOURCE_WINDOW_SYSTEM => "Window System",
        gl.DEBUG_SOURCE_SHADER_COMPILER => "Shader Compiler",
        gl.DEBUG_SOURCE_THIRD_PARTY => "Third Party",
        gl.DEBUG_SOURCE_APPLICATION => "Application",
        gl.DEBUG_SOURCE_OTHER => "Other",
        else => "unknown",
    };

    const typeString = switch (debugType) {
        gl.DEBUG_TYPE_ERROR => "Error",
        gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR => "Deprecated Behaviour",
        gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR => "Undefined Behaviour",
        gl.DEBUG_TYPE_PORTABILITY => "Portability",
        gl.DEBUG_TYPE_PERFORMANCE => "Performance",
        gl.DEBUG_TYPE_MARKER => "Marker",
        gl.DEBUG_TYPE_PUSH_GROUP => "Push Group",
        gl.DEBUG_TYPE_POP_GROUP => "Pop Group",
        gl.DEBUG_TYPE_OTHER => "Other",
        else => "unknown",
    };

    const severityString = switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => "high",
        gl.DEBUG_SEVERITY_MEDIUM => "medium",
        gl.DEBUG_SEVERITY_LOW => "low",
        gl.DEBUG_SEVERITY_NOTIFICATION => "notification",
        else => "unknown",
    };

    std.debug.print("--------\n", .{});
    std.debug.print("[GL_DEBUG] ({d}): {s}\n", .{ id, message });
    std.debug.print("    Source: {s}\n    Type: {s}\n    Severity: {s}\n", .{ sourceString, typeString, severityString });
}

test "detect memory leak" {
    const app = App.init(std.testing.allocator) catch {
        try std.testing.expect(false);
        return;
    };
    defer app.destroy();

    app.loop();
}
