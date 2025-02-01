const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");

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
    }) orelse return error.InitFailed;

    errdefer window.destroy();

    glfw.makeContextCurrent(window);
    errdefer glfw.makeContextCurrent(null);

    if (!gl_procs.init(glfw.getProcAddress))
        return error.GlInitFailed;

    gl.makeProcTableCurrent(&gl_procs);
    errdefer gl.makeProcTableCurrent(null);

    window.setFramebufferSizeCallback(frameBufferSizeCallback);

    std.debug.print("OpenGL version: {s}\n", .{gl.GetString(gl.VERSION) orelse ""});

    return App{ .window = window, .allocator = allocator };
}

const position = [_]f32{ -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5 };
const indices = [_]u32{ 0, 1, 2, 2, 3, 0 };

pub fn loop(app: App) void {
    //
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    gl.BindVertexArray(vao);
    //

    var vbo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, 8 * @sizeOf(f32), &position, gl.STATIC_DRAW);

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), 0);
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    var ibo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&ibo));
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, 6 * @sizeOf(u32), &indices, gl.STATIC_DRAW);
    defer gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

    const vertexShader = loadFile(app.allocator, "./res/shaders/vert.glsl") catch unreachable;
    const fragmentShader = loadFile(app.allocator, "./res/shaders/frag.glsl") catch unreachable;

    defer app.allocator.free(vertexShader);
    defer app.allocator.free(fragmentShader);

    const shader = createShader(vertexShader, fragmentShader) catch unreachable;

    gl.UseProgram(shader);
    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);

    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    while (!app.window.shouldClose()) {
        app.handleInput();

        gl.ClearColor(0.2, 0.4, 0.4, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

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

test "detect memory leak" {
    const app = App.init(std.testing.allocator) catch {
        try std.testing.expect(false);
        return;
    };
    defer app.destroy();

    app.loop();
}
