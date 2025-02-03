const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const vb = @import("VertexBuffer.zig");
const ib = @import("IndexBuffer.zig");
const va = @import("VertexArray.zig");
const vbl = @import("VertexBufferLayout.zig");
const Shader = @import("Shader.zig");

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

const position = [_]f32{ -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5 };
const indices = [_]u32{ 0, 1, 2, 2, 3, 0 };

pub fn loop(app: App) void {
    var vao = va.init();
    var vbo = vb.init(&position, 8 * @sizeOf(f32));
    defer vbo.destroy();

    var vblo = vbl.init(app.allocator);
    vblo.push(2) catch unreachable;

    vao.addBuffer(vbo, vblo);

    var ibo = ib.init(&indices, 6);
    defer ibo.destroy();

    var shader = Shader.init("./res/shaders/vert.glsl", "./res/shaders/frag.glsl") catch unreachable;
    shader.bind();

    shader.setUniform4f("u_Color", 0.8, 0.3, 0.8, 1.0);

    shader.unbind();

    vao.bind();
    defer vao.destroy();

    var r: f32 = 0.0;
    var inc: f32 = 0.05;
    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    while (!app.window.shouldClose()) {
        app.handleInput();

        gl.ClearColor(0.2, 0.4, 0.4, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        shader.bind();
        shader.setUniform4f("u_Color", r, 1.0, 0.0, 1.0);

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

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

fn createShader(vertexShader: [:0]const u8, fragmentShader: [:0]const u8) !c_uint {
    const program = gl.CreateProgram();
    const vs = try compileShader(gl.VERTEX_SHADER, vertexShader);
    const fs = try compileShader(gl.FRAGMENT_SHADER, fragmentShader);
    defer gl.DeleteShader(vs);
    defer gl.DeleteShader(fs);

    gl.AttachShader(program, vs);
    gl.AttachShader(program, fs);

    gl.LinkProgram(program);
    gl.ValidateProgram(program);

    return program;
}

fn compileShader(shaderType: c_uint, source: [:0]const u8) !c_uint {
    const id = gl.CreateShader(shaderType);
    gl.ShaderSource(id, 1, @ptrCast(&source), null);
    gl.CompileShader(id);
    errdefer gl.DeleteShader(id);

    var result: c_int = undefined;
    gl.GetShaderiv(id, gl.COMPILE_STATUS, &result);

    if (result == gl.FALSE) {
        var length: c_int = undefined;
        gl.GetShaderiv(id, gl.INFO_LOG_LENGTH, &length);

        const allocator = std.heap.page_allocator;
        const message = try allocator.alloc(u8, @intCast(length));
        defer allocator.free(message);

        gl.GetShaderInfoLog(id, length, &length, message.ptr);

        std.debug.print("Failed to compile shader: {s}\n", .{message});

        return error.FailedShaderCompilation;
    }

    return id;
}

fn loadFile(allocator: std.mem.Allocator, filepath: []const u8) ![:0]u8 {
    const file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return error.FailedToOpenFile;
    };
    defer file.close();

    const contents = file.reader().readAllAlloc(allocator, std.math.maxInt(usize)) catch |err| {
        std.log.err("Failed to read file: {s}", .{@errorName(err)});
        return error.FailedToReadFile;
    };

    const null_term_contents = allocator.dupeZ(u8, contents[0..]);
    defer allocator.free(contents);

    return null_term_contents;
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
