const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cherry = b.addLibrary(.{
        .name = "cherry",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cherry.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .use_llvm = true,
    });

    cherry.root_module.linkSystemLibrary("sdl3", .{});
    b.installArtifact(cherry);

    const cherry_tests = b.addTest(.{
        .root_module = cherry.root_module,
    });

    const run_cherry_tests = b.addRunArtifact(cherry_tests);

    const exampleStep = b.step("example", "Run example");
    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example/main.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{
                .{ .name = "cherry", .module = cherry.root_module },
            },
            .link_libc = true,
        }),
        .use_llvm = true,
    });
    example.root_module.linkSystemLibrary("sdl3", .{});
    
    b.installArtifact(example);
    const exampleRun = b.addRunArtifact(example);
    exampleStep.dependOn(&exampleRun.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_cherry_tests.step);
}
