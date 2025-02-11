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
const daco = @import("assimp.zig");

var gl_procs: gl.ProcTable = undefined;

const App = @This();

window: glfw.Window,
allocator: std.mem.Allocator,
ImGuiCtx: ImGui,

var scenes: [3]Scene.Scene = undefined;
var sceneSelector: Scene.SceneSelector = undefined;

pub fn init(allocator: std.mem.Allocator) !App {
    log.info("Initializing application", .{});
    daco.load();

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

    const winSize = window.getSize();
    window.setCursorPos(@as(f32, @floatFromInt(winSize.width)) / 2.0, @as(f32, @floatFromInt(winSize.height)) / 2.0);

    window.setKeyCallback(keyCallback);
    window.setCursorPosCallback(mouseCallback);
    window.setScrollCallback(scrollCallback);
    window.setInputMode(glfw.Window.InputMode.cursor, glfw.Window.InputModeCursor.disabled);

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

    log.info("Initializing scene: Default Scene", .{});
    const defaultScene = Scene.DefaultScene.init(allocator, window);

    log.info("Initializing scene: Lighting Scene", .{});
    const lightingScene = Scene.LightingScene.init(allocator, window);

    log.info("Initializing scene: Lighting Texture Scene", .{});
    const lightingTexScene = Scene.LightingTexScene.init(allocator, window);

    scenes[0] = .{ .defaultScene = defaultScene };
    scenes[1] = .{ .lightingScene = lightingScene };
    scenes[2] = .{ .lightingTexScene = lightingTexScene };

    sceneSelector = Scene.SceneSelector.init(&scenes);

    log.info("Initalization done", .{});

    return App{ .window = window, .allocator = allocator, .ImGuiCtx = imgGuiCtx };
}

var deltaTime: f32 = 0;
var lastFrame: f32 = 0;
var lastSceneIdx: u32 = 2;

pub fn loop(app: App) void {

    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    while (!app.window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        if (lastSceneIdx != sceneSelector.sceneIdx) {
            app.handleSceneChange();
            lastSceneIdx = sceneSelector.sceneIdx;
        }

        app.handleInput();

        Renderer.clear();
        ImGui.newFrame();

        sceneSelector.currentScene().draw(deltaTime);

        imGuiDebugInfo(ImGui.c.igGetIO());

        ImGui.render();

        app.window.swapBuffers();

        glfw.pollEvents();
    }
}

pub fn destroy(app: App) void {
    log.info("Destroying application", .{});

    sceneSelector.destroyScenes();
    app.ImGuiCtx.destroy();
    gl.makeProcTableCurrent(null);
    glfw.makeContextCurrent(null);
    app.window.destroy();
    glfw.terminate();
}

fn handleInput(app: App) void {
    sceneSelector.currentScene().handleInput(app.window, deltaTime);
}

var cursorHidden = true;
fn keyCallback(window: glfw.Window, key: glfw.Key, _: i32, action: glfw.Action, _: glfw.Mods) void {
    if (key == glfw.Key.escape and action == glfw.Action.press)
        window.setShouldClose(true);

    if (key == glfw.Key.tab and action == glfw.Action.press) {
        sceneSelector.nextScene();

        if (cursorHidden) {
            const winSize = window.getSize();
            window.setCursorPos(@floatFromInt(winSize.width / 2), @floatFromInt(winSize.height / 2));
        }
    }

    if (key == glfw.Key.left_control and action == glfw.Action.press) {
        log.debug("Mouse mode changed", .{});

        window.setInputMode(glfw.Window.InputMode.cursor, if (cursorHidden)
            glfw.Window.InputModeCursor.captured
        else
            glfw.Window.InputModeCursor.disabled);

        if (!cursorHidden)
            window.setCursorPos(lastX, lastY);

        cursorHidden = !cursorHidden;
    }
}

var lastX: f32 = 0;
var lastY: f32 = 0;
fn mouseCallback(window: glfw.Window, xpos: f64, ypos: f64) void {
    ImGui.igGlfw.cImGui_ImplGlfw_CursorPosCallback(@ptrCast(window.handle), xpos, ypos);

    if (!cursorHidden) return;

    lastX = @floatCast(xpos);
    lastY = @floatCast(ypos);

    sceneSelector.currentScene().handleMouse(@floatCast(xpos), @floatCast(ypos));
}

fn scrollCallback(_: glfw.Window, xoffset: f64, yoffset: f64) void {
    sceneSelector.currentScene().handleScroll(@floatCast(xoffset), @floatCast(yoffset));
}

fn frameBufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

fn handleSceneChange(app: App) void {
    const winSize = app.window.getSize();
    lastX = @as(f32, @floatFromInt(winSize.width)) / 2;
    lastY = @as(f32, @floatFromInt(winSize.height)) / 2;
    sceneSelector.currentScene().onSceneRenentry();
    log.debug("Switched to scene {d}", .{sceneSelector.sceneIdx});
}

fn imGuiDebugInfo(io: *ImGui.c.ImGuiIO) void {
    ImGui.c.igSetNextWindowPos(.{ .x = io.*.DisplaySize.x - 200, .y = 5 }, ImGui.c.ImGuiCond_Always);
    ImGui.c.igSetNextWindowSize(.{ .x = 0, .y = 50 }, ImGui.c.ImGuiCond_Always);
    _ = ImGui.c.igBegin("Framerate", null, ImGui.c.ImGuiWindowFlags_NoDecoration | ImGui.c.ImGuiWindowFlags_NoBackground | ImGui.c.ImGuiWindowFlags_NoInputs);
    ImGui.c.igText("%.3f ms/frame (%.1f FPS)", 1000.0 / io.*.Framerate, io.*.Framerate);
    ImGui.c.igText("%.3f deltaTime", deltaTime);
    ImGui.c.igEnd();
    var sceneNames: [scenes.len][*c]const u8 = undefined;
    for (0..scenes.len) |i| {
        sceneNames[i] = scenes[i].getSceneName().ptr;
    }
    _ = ImGui.c.igBegin("Scene selector", null, 0);
    _ = ImGui.c.igListBox("##", @ptrCast(&sceneSelector.sceneIdx), &sceneNames, sceneNames.len, 4);
    ImGui.c.igEnd();

    //ImGui.c.igShowDemoWindow(null);
}

test "detect memory leak" {
    const app = App.init(std.testing.allocator) catch {
        try std.testing.expect(false);
        return;
    };
    defer app.destroy();

    app.loop();
}
