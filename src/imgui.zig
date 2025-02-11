const builtin = @import("builtin");
const glfw = @import("mach-glfw");
pub const c = if (builtin.mode == .Debug) @cImport(@cInclude("dcimgui.h")) else struct {};
pub const igOpenGl = if (builtin.mode == .Debug) @cImport(@cInclude("dcimgui_impl_opengl3.h")) else struct {};
pub const igGlfw = if (builtin.mode == .Debug) @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("dcimgui_impl_glfw.h");
}) else struct {};

const Self = @This();

ImGuiCtx: if (builtin.mode == .Debug) *c.ImGuiContext else void,

pub fn init(window: glfw.Window) !Self {
    if (builtin.mode != .Debug)
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
    if (builtin.mode != .Debug)
        return;

    igOpenGl.cImGui_ImplOpenGL3_NewFrame();
    igGlfw.cImGui_ImplGlfw_NewFrame();
    c.igNewFrame();
}

pub fn render() void {
    if (builtin.mode != .Debug)
        return;

    c.igRender();
    igOpenGl.cImGui_ImplOpenGL3_RenderDrawData(@ptrCast(c.igGetDrawData()));
}

pub fn destroy(ig: Self) void {
    if (builtin.mode != .Debug)
        return;

    igOpenGl.cImGui_ImplOpenGL3_Shutdown();
    igGlfw.cImGui_ImplGlfw_Shutdown();
    c.igDestroyContext(ig.ImGuiCtx);
}
