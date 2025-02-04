const glfw = @import("mach-glfw");
pub const c = @cImport(@cInclude("dcimgui.h"));
pub const igOpenGl = @cImport(@cInclude("dcimgui_impl_opengl3.h"));
pub const igGlfw = @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("dcimgui_impl_glfw.h");
});

const Self = @This();

ImGuiCtx: *c.ImGuiContext,

pub fn init(window: glfw.Window) !Self {
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
    igOpenGl.cImGui_ImplOpenGL3_NewFrame();
    igGlfw.cImGui_ImplGlfw_NewFrame();
    c.igNewFrame();
}

pub fn render() void {
    c.igRender();
    igOpenGl.cImGui_ImplOpenGL3_RenderDrawData(@ptrCast(c.igGetDrawData()));
}

pub fn destroy(ig: Self) void {
    igOpenGl.cImGui_ImplOpenGL3_Shutdown();
    igGlfw.cImGui_ImplGlfw_Shutdown();
    c.igDestroyContext(ig.ImGuiCtx);
}
