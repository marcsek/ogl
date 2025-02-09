const math = @import("std").math;
const glfw = @import("mach-glfw");
const glm = @import("glm.zig");
const ImGui = @import("imgui.zig");

const Self = @This();

pub const directions = enum {
    left,
    right,
    up,
    down,
};

pub const Mouse = struct {
    fov: f32 = 45,
    yaw: f32 = -90,
    pitch: f32 = 0,
    lastX: f32 = 0,
    lastY: f32 = 0,
};

viewMatrix: glm.mat4 = undefined,
mouse: Mouse,
position: glm.vec3,
front: glm.vec3 = .{ 0, 0, -1 },
up: glm.vec3 = .{ 0, 1, 0 },

pub fn init(fov: f32, pos: glm.vec3) Self {
    var result = Self{
        .mouse = .{ .fov = fov },
        .position = pos,
    };

    glm.glmc_mat4_identity(&result.viewMatrix);

    return result;
}

pub fn updateViewMatrix(cam: *Self) void {
    var cameraTarget: glm.vec3 = undefined;
    glm.glmc_vec3_add(&cam.position, &cam.front, &cameraTarget);

    glm.glmc_mat4_identity(&cam.viewMatrix);
    glm.glmc_lookat(&cam.position, &cameraTarget, &cam.up, &cam.viewMatrix);
}

pub fn getViewMatrix(cam: *Self) glm.mat4 {
    return cam.viewMatrix;
}

pub fn moveInDirection(cam: *Self, direction: directions, amount: f32) void {
    switch (direction) {
        .up => glm.glmc_vec3_muladds(&cam.front, amount, &cam.position),
        .down => glm.glmc_vec3_mulsubs(&cam.front, amount, &cam.position),
        .left, .right => {
            var cross: glm.vec3 = undefined;
            glm.glmc_vec3_crossn(&cam.front, &cam.up, &cross);

            if (direction == .left)
                glm.glmc_vec3_mulsubs(&cross, amount, &cam.position)
            else
                glm.glmc_vec3_muladds(&cross, amount, &cam.position);
        },
    }
}

pub fn updateMousePosition(cam: *Self, xPos: f32, yPos: f32) void {
    var xOffset: f32 = xPos - cam.mouse.lastX;
    var yOffset: f32 = cam.mouse.lastY - yPos;

    cam.mouse.lastX = xPos;
    cam.mouse.lastY = yPos;

    const sensitivity: f32 = 0.1;
    xOffset *= sensitivity;
    yOffset *= sensitivity;

    cam.mouse.yaw += xOffset;
    cam.mouse.pitch = math.clamp(cam.mouse.pitch + yOffset, -89.0, 89.0);

    var direction: glm.vec3 = undefined;
    direction[0] = @cos(glm.glm_rad(cam.mouse.yaw)) * @cos(glm.glm_rad(cam.mouse.pitch));
    direction[1] = @sin(glm.glm_rad(cam.mouse.pitch));
    direction[2] = @sin(glm.glm_rad(cam.mouse.yaw)) * @cos(glm.glm_rad(cam.mouse.pitch));
    glm.glmc_vec3_normalize(&direction);
    glm.glmc_vec3_copy(&direction, &cam.front);
}

pub fn setPosition(cam: *Self, newPosition: glm.vec3) void {
    cam.position = newPosition;
    cam.front = .{ 0, 0, -1 };
    cam.up = .{ 0, 1, 0 };
}

pub fn resetMousePosition(cam: *Self, viewWidth: f32, viewHeight: f32) void {
    cam.mouse = Mouse{ .lastX = viewWidth / 2, .lastY = viewHeight / 2 };
}

pub fn imGuiDebugWindow(cam: *Self) void {
    _ = ImGui.c.igBegin("Scene controls", null, 0);
    _ = ImGui.c.igSliderFloat("cam-x", &cam.position[0], -10, 10);
    _ = ImGui.c.igSliderFloat("cam-y", &cam.position[1], -10, 10);
    _ = ImGui.c.igSliderFloat("cam-z", &cam.position[2], 0.1, 120);
    ImGui.c.igEnd();
}
