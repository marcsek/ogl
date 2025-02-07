const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const Renderer = @import("Renderer.zig");
const ImGui = @import("imgui.zig");
const Scene = @import("Scene.zig");
const utils = @import("utils.zig");
const log = std.log;
const openGlLog = utils.scopes.openGlLog;
const glfwLog = utils.scopes.glfwLog;

var gl_procs: gl.ProcTable = undefined;

const App = @This();

window: glfw.Window,
allocator: std.mem.Allocator,
ImGuiCtx: ImGui,

var scene: Scene = undefined;
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

    glfw.swapInterval(1);
    window.setFramebufferSizeCallback(frameBufferSizeCallback);

    if (!gl_procs.init(glfw.getProcAddress))
        return error.GlInitFailed;

    gl.makeProcTableCurrent(&gl_procs);
    errdefer gl.makeProcTableCurrent(null);

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

    openGlLog.info("Version: {s}", .{gl.GetString(gl.VERSION) orelse ""});

    scene = Scene.init(allocator, window);

    log.info("Initalization done", .{});

    return App{ .window = window, .allocator = allocator, .ImGuiCtx = imgGuiCtx };
}

var deltaTime: f32 = 0;
var lastFrame: f32 = 0;

pub fn loop(app: App) void {
    var winSize = app.window.getFramebufferSize();
    app.window.setCursorPos(@floatFromInt(winSize.width), @floatFromInt(winSize.height));
    gl.Enable(gl.DEPTH_TEST);

    app.window.setInputMode(glfw.Window.InputMode.cursor, glfw.Window.InputModeCursor.disabled);
    app.window.setScrollCallback(scrollCallback);
    app.window.setCursorPosCallback(mouseCallback);

    Renderer.setClearColor(0.2, 0.4, 0.4, 1.0);

    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    while (!app.window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        app.handleInput();

        Renderer.clear();
        ImGui.newFrame();

        scene.draw(deltaTime);

        imGuiDebugInfo(ImGui.c.igGetIO());

        ImGui.render();

        winSize = app.window.getFramebufferSize();
        app.window.swapBuffers();

        glfw.pollEvents();
    }
}

pub fn destroy(app: App) void {
    log.info("Destroying application", .{});

    scene.destroy();
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
            app.window.setCursorPos(lastX, lastY);

        cursorHidden = !cursorHidden;
        start = @floatCast(glfw.getTime());
    }

    scene.handleInput(app.window, deltaTime);
}

var firstMouseCb = true;
var lastX: f32 = 0;
var lastY: f32 = 0;
fn mouseCallback(window: glfw.Window, xpos: f64, ypos: f64) void {
    ImGui.igGlfw.cImGui_ImplGlfw_CursorPosCallback(@ptrCast(window.handle), xpos, ypos);

    if (firstMouseCb) {
        firstMouseCb = false;
        return;
    }

    if (!cursorHidden) return;

    lastX = @floatCast(xpos);
    lastY = @floatCast(ypos);

    scene.handleMouse(@floatCast(xpos), @floatCast(ypos));
}

fn scrollCallback(_: glfw.Window, xoffset: f64, yoffset: f64) void {
    scene.handleScroll(@floatCast(xoffset), @floatCast(yoffset));
}

fn frameBufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

fn imGuiDebugInfo(io: *ImGui.c.ImGuiIO) void {
    ImGui.c.igSetNextWindowPos(.{ .x = io.*.DisplaySize.x - 200, .y = 5 }, ImGui.c.ImGuiCond_Always);
    ImGui.c.igSetNextWindowSize(.{ .x = 0, .y = 50 }, ImGui.c.ImGuiCond_Always);
    _ = ImGui.c.igBegin("Framerate", null, ImGui.c.ImGuiWindowFlags_NoDecoration | ImGui.c.ImGuiWindowFlags_NoBackground | ImGui.c.ImGuiWindowFlags_NoInputs);

    ImGui.c.igText("%.3f ms/frame (%.1f FPS)", 1000.0 / io.*.Framerate, io.*.Framerate);
    ImGui.c.igText("%.3f deltaTime", deltaTime);
    ImGui.c.igEnd();
}

test "detect memory leak" {
    const app = App.init(std.testing.allocator) catch {
        try std.testing.expect(false);
        return;
    };
    defer app.destroy();

    app.loop();
}
