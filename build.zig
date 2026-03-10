// build.zig
// TITAN VISION OS - Zig Build System
// Copyright © Julius Cameron Hill

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the Metal shared library
    const lib = b.addSharedLibrary(.{
        .name = "titan_metal",
        .root_source_file = b.path("camera_driver.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the library
    b.installArtifact(lib);
    
    // Create a test executable
    const test_exe = b.addExecutable(.{
        .name = "titan_metal_test",
        .root_source_file = b.path("test_metal.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    test_exe.linkLibrary(lib);
    b.installArtifact(test_exe);
}
