const std = @import("std");
const core = @import("mach_core");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });

    const zig_imgui_dep = b.dependency("zig_imgui", .{});

    const imgui_module = b.addModule("imgui", .{
        .root_source_file = zig_imgui_dep.path("src/imgui.zig"),
        .imports = &.{
            .{ .name = "mach-core", .module = mach_core_dep.module("mach-core") },
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "imgui",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    const imgui_dep = b.dependency("imgui", .{});

    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    try files.appendSlice(&.{
        zig_imgui_dep.path("src/cimgui.cpp").getPath(b),
        imgui_dep.path("imgui.cpp").getPath(b),
        imgui_dep.path("imgui_widgets.cpp").getPath(b),
        imgui_dep.path("imgui_tables.cpp").getPath(b),
        imgui_dep.path("imgui_draw.cpp").getPath(b),
        imgui_dep.path("imgui_demo.cpp").getPath(b),
    });

    lib.addIncludePath(imgui_dep.path("."));
    lib.addCSourceFiles(.{
        .files = files.items,
        .flags = flags.items,
    });
    b.installArtifact(lib);

    const app = try core.App.init(b, mach_core_dep.builder, .{
        .name = "pixani",
        .src = "src/pixani.zig",
        .target = target,
        .optimize = optimize,
        .deps = &[_]std.Build.Module.Import{
            .{ .name = "imgui", .module = imgui_module },
        },
    });
    app.compile.linkLibrary(lib);

    const run_step = b.step("run", "run pixani");
    run_step.dependOn(&app.run.step);

    // app.compile.root_module.addImport("imgui", zig_imgui_pkg.zig_imgui);
}
