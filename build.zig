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
