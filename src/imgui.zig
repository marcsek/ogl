const options = @import("options");
pub const enabled = options.imgui;

const std = @import("std");
const glfw = @import("mach-glfw");
pub const c = if (enabled) @cImport(@cInclude("dcimgui.h")) else struct {};
pub const igOpenGl = if (enabled) @cImport(@cInclude("dcimgui_impl_opengl3.h")) else struct {};
pub const igGlfw = if (enabled) @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("dcimgui_impl_glfw.h");
}) else struct {};

const Self = @This();

ImGuiCtx: if (enabled) *c.ImGuiContext else void,

pub fn init(window: glfw.Window) !Self {
    if (!enabled)
        return;

    const ctx = c.igCreateContext(null) orelse return error.ImGuiInitFailed;
    const glfwInit = igGlfw.cImGui_ImplGlfw_InitForOpenGL(@ptrCast(window.handle), true);
    const openGlInit = igOpenGl.cImGui_ImplOpenGL3_Init();

    if (!glfwInit or !openGlInit) {
        return error.ImGuiImplInitFailed;
    }

    c.igStyleColorsDark(null);

    return Self{ .ImGuiCtx = ctx };
}

pub fn newFrame() void {
    if (!enabled)
        return;

    igOpenGl.cImGui_ImplOpenGL3_NewFrame();
    igGlfw.cImGui_ImplGlfw_NewFrame();
    c.igNewFrame();
}

pub fn render() void {
    if (!enabled)
        return;

    c.igRender();
    igOpenGl.cImGui_ImplOpenGL3_RenderDrawData(@ptrCast(c.igGetDrawData()));
}

pub fn destroy(ig: Self) void {
    if (!enabled)
        return;

    igOpenGl.cImGui_ImplOpenGL3_Shutdown();
    igGlfw.cImGui_ImplGlfw_Shutdown();
    c.igDestroyContext(ig.ImGuiCtx);
}
