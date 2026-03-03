const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zap_dep = b.dependency("zap", .{ .target = target, .optimize = optimize });
    const pg_dep = b.dependency("pg", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "benchmark_zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zap", zap_dep.module("zap"));
    exe.root_module.addImport("pg", pg_dep.module("pg"));
    b.installArtifact(exe);
}
