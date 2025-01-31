const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");

var gl_procs: gl.ProcTable = undefined;

pub fn main() !void {
    if (!glfw.init(.{}))
        return error.GlfwInitFailed;

    defer glfw.terminate();

    const window = glfw.Window.create(640, 480, "Fuckery", null, null, .{}) orelse return error.InitFailed;

    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    if (!gl_procs.init(glfw.getProcAddress))
        return error.GlInitFailed;

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    while (!window.shouldClose()) {
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.Begin(gl.TRIANGLES);
        gl.Vertex2f(-0.5, -0.5);
        gl.Vertex2f(0, 0.5);
        gl.Vertex2f(0.5, -0.5);
        gl.End();

        window.swapBuffers();

        glfw.pollEvents();
    }

    std.debug.print("No nazdar.\n", .{});
}
