const std = @import("std");
const glfw = @import("mach-glfw");
const vb = @import("VertexBuffer.zig");
const ib = @import("IndexBuffer.zig");
const va = @import("VertexArray.zig");
const vbl = @import("VertexBufferLayout.zig");
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");
const Camera = @import("Camera.zig");
const ImGui = @import("imgui.zig");
const Renderer = @import("Renderer.zig");
const glm = @import("glm.zig");
const cube = @import("shapes.zig").cube;
pub const DefaultScene = @import("scenes/DefaultScene.zig");
pub const LightingScene = @import("scenes/LightingScene.zig");

pub const Scene = union(enum) {
    defaultScene: DefaultScene,
    lightingScene: LightingScene,
    null: void,

    pub fn draw(self: *Scene, dt: f32) void {
        switch (self.*) {
            .null => {},
            inline else => |*impl| return impl.draw(dt),
        }
    }

    pub fn destroy(self: *Scene) void {
        switch (self.*) {
            .null => {},
            inline else => |*impl| return impl.destroy(),
        }
    }

    pub fn handleInput(self: *Scene, window: glfw.Window, dt: f32) void {
        switch (self.*) {
            .null => {},
            inline else => |*impl| return impl.handleInput(window, dt),
        }
    }

    pub fn handleMouse(self: *Scene, xPos: f32, yPos: f32) void {
        switch (self.*) {
            .null => {},
            inline else => |*impl| return impl.handleMouse(xPos, yPos),
        }
    }

    pub fn handleScroll(self: *Scene, xOffset: f32, yOffset: f32) void {
        switch (self.*) {
            .null => {},
            inline else => |*impl| return impl.handleScroll(xOffset, yOffset),
        }
    }

    pub fn getSceneName(self: *Scene) []const u8 {
        return switch (self.*) {
            .null => "",
            inline else => |*impl| return impl.getSceneName(),
        };
    }

    pub fn onSceneRenentry(self: *Scene) void {
        switch (self.*) {
            .null => {},
            inline else => |*impl| return impl.onSceneReentry(),
        }
    }
};

pub const SceneSelector = struct {
    const Self = @This();

    scenes: []Scene,
    sceneIdx: u32 = 0,

    pub fn init(inScenes: []Scene) Self {
        return Self{ .scenes = inScenes };
    }

    pub fn nextScene(ss: *Self) void {
        ss.sceneIdx = (ss.sceneIdx + 1) % @as(u32, @intCast(ss.scenes.len));
    }

    pub fn currentScene(ss: *Self) *Scene {
        return &ss.scenes[ss.sceneIdx];
    }

    pub fn getIndex(ss: *Self, idx: usize) *Scene {
        return &ss.scenes[idx];
    }

    pub fn destroyScenes(ss: *Self) void {
        for (0..ss.scenes.len) |i|
            ss.scenes[i].destroy();
    }
};
