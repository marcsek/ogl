const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ogl",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const glfw_dep = b.dependency("mach-glfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.3",
        .profile = .core,
    });
    exe.root_module.addImport("gl", gl_bindings);

    b.installArtifact(exe);

    exe.linkLibC();
    exe.addCSourceFile(.{ .file = b.path("./vendor/stb_image/stb_imageimpl.c"), .flags = &[_][]const u8{ "-g", "-O3" } });
    exe.addIncludePath(b.path("vendor/stb_image/"));
    exe.addIncludePath(b.path("vendor/cglm/include"));
    exe.addIncludePath(b.path("vendor/glfw/include"));

    const IMGUI_SOURCES = [_][]const u8{
        "vendor/imgui_bindings/generated/dcimgui.cpp",
        "vendor/imgui_bindings/generated/dcimgui_impl_opengl3.cpp",
        "vendor/imgui_bindings/generated/dcimgui_impl_glfw.cpp",

        "vendor/imgui_bindings/imgui/imgui.cpp",
        "vendor/imgui_bindings/imgui/imgui_demo.cpp",
        "vendor/imgui_bindings/imgui/imgui_draw.cpp",
        "vendor/imgui_bindings/imgui/imgui_tables.cpp",
        "vendor/imgui_bindings/imgui/imgui_widgets.cpp",
        "vendor/imgui_bindings/imgui/imgui_impl_glfw.cpp",
        "vendor/imgui_bindings/imgui/imgui_impl_opengl3.cpp",
    };

    exe.linkLibCpp();
    exe.addIncludePath(b.path("vendor/imgui_bindings/generated/"));
    // LSP bug, need to include "explicitly"
    exe.addIncludePath(b.path("vendor/imgui_bindings/generated/dcimgui.h"));
    //
    exe.addIncludePath(b.path("vendor/imgui_bindings/imgui/"));
    exe.addCSourceFiles(.{ .files = &IMGUI_SOURCES, .flags = &[_][]const u8{ "-g", "-O3" } });

    const exe_check = b.addExecutable(.{
        .name = "ogl",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const check = b.step("check", "Check if compiles");
    check.dependOn(&exe_check.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));
    exe_unit_tests.root_module.addImport("gl", gl_bindings);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
