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

var gl_procs: gl.ProcTable = undefined;

const App = @This();

window: glfw.Window,
allocator: std.mem.Allocator,

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn init(allocator: std.mem.Allocator) !App {
    glfw.setErrorCallback(errorCallback);

    if (!glfw.init(.{}))
        return error.GlfwInitFailed;

    errdefer glfw.terminate();
    const window = glfw.Window.create(640, 480, "Fuckery", null, null, .{
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

    // Debug callback setup
    var flags: c_int = undefined;
    gl.GetIntegerv(gl.CONTEXT_FLAGS, @ptrCast(&flags));
    if (flags != gl.FALSE and gl.CONTEXT_FLAG_DEBUG_BIT != 0) {
        gl.Enable(gl.DEBUG_OUTPUT);
        gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
        gl.DebugMessageCallback(glDebugOutput, null);
        gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, null, gl.TRUE);
    }

    std.debug.print("OpenGL version: {s}\n", .{gl.GetString(gl.VERSION) orelse ""});

    return App{ .window = window, .allocator = allocator };
}

// zig fmt: off
const position = [_]f32{ 
    -0.5, -0.5, 0.0, 0.0,
     0.5, -0.5, 1.0, 0.0, 
     0.5,  0.5, 1.0, 1.0,
    -0.5,  0.5, 0.0, 1.0,
};
// zig fmt: on

const indices = [_]u32{ 0, 1, 2, 2, 3, 0 };

pub fn loop(app: App) void {
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.Enable(gl.BLEND);

    var vao = va.init();
    var vbo = vb.init(&position, 4 * 4 * @sizeOf(f32));
    defer vbo.destroy();

    var vblo = vbl.init(app.allocator);
    defer vblo.destroy();
    vblo.push(2) catch unreachable;
    vblo.push(2) catch unreachable;

    vao.addBuffer(vbo, vblo);

    var ibo = ib.init(&indices, 6);
    defer ibo.destroy();

    var proj: glm.mat4 = undefined;
    glm.glm_ortho(-2.0, 2.0, -1.5, 1.5, -1.0, 1.0, &proj);

    var shader = Shader.init("./res/shaders/vert.glsl", "./res/shaders/frag.glsl") catch unreachable;
    shader.bind();
    shader.setUniformMat4f("u_MVP", proj);

    const texture = Texture.init(app.allocator, "./res/textures/sauron_eye.png") catch unreachable;
    texture.bind(0);
    shader.setUniform1i("u_Texture", 0);

    shader.unbind();

    vao.bind();
    defer vao.destroy();

    var r: f32 = 0.0;
    var inc: f32 = 0.05;

    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    Renderer.setClearColor(0.2, 0.4, 0.4, 1.0);
    while (!app.window.shouldClose()) {
        app.handleInput();

        Renderer.clear();

        //shader.bind();
        //shader.setUniform4f("u_Color", r, r, r, 1.0);

        Renderer.draw(vao, ibo, shader);

        if (r > 1.0 or r < 0.0) inc *= -1.0;
        r += inc;

        app.window.swapBuffers();

        glfw.pollEvents();
    }
}

pub fn destroy(app: App) void {
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
