const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "zigl",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.root_module.link_libc = true;
    lib.root_module.addIncludePath(b.path("include"));
    lib.root_module.addCSourceFile(.{ .file = b.path("src/glad/gl.c") });

    const use_x11 = b.option(bool, "x11", "Build with X11. Only useful on Linux") orelse true;
    const use_wl = b.option(bool, "wayland", "Build with Wayland. Only useful on Linux") orelse false;

    const use_opengl = b.option(bool, "opengl", "Build with OpenGL; deprecated on MacOS") orelse false;
    const use_gles = b.option(bool, "gles", "Build with GLES; not supported on MacOS") orelse false;
    const use_metal = b.option(bool, "metal", "Build with Metal; only supported on MacOS") orelse false;

    lib.root_module.addCSourceFiles(.{
        .files = &base_sources,
    });
    switch (target.result.os.tag) {
        .windows => {
            lib.root_module.linkSystemLibrary("gdi32", .{});
            lib.root_module.linkSystemLibrary("user32", .{});
            lib.root_module.linkSystemLibrary("shell32", .{});

            if (use_opengl) {
                lib.root_module.linkSystemLibrary("opengl32", .{});
            }

            if (use_gles) {
                lib.root_module.linkSystemLibrary("GLESv3", .{});
            }

            lib.root_module.addCMacro("_GLFW_WIN32", "1");
            lib.root_module.addCSourceFiles(.{
                .files = &windows_sources,
            });
        },
        .macos => {
            lib.root_module.linkSystemLibrary("objc", .{});
            lib.root_module.linkFramework("IOKit", .{});
            lib.root_module.linkFramework("CoreFoundation", .{});
            lib.root_module.linkFramework("AppKit", .{});
            lib.root_module.linkFramework("CoreServices", .{});
            lib.root_module.linkFramework("CoreGraphics", .{});
            lib.root_module.linkFramework("Foundation", .{});

            if (use_metal) {
                lib.root_module.linkFramework("Metal", .{});
            }

            if (use_opengl) {
                lib.root_module.linkFramework("OpenGL", .{});
            }

            lib.root_module.addCMacro("_GLFW_COCOA", "1");
            lib.root_module.addCSourceFiles(.{
                .files = &macos_sources,
            });
        },
        // linux
        else => {
            lib.root_module.addCSourceFiles(.{
                .files = &linux_sources,
            });

            if (use_x11) {
                lib.root_module.addCMacro("_GLFW_X11", "1");
                lib.root_module.addCSourceFiles(.{
                    .files = &linux_x11_sources,
                });
            }

            if (use_wl) {
                lib.root_module.addCMacro("_GLFW_WAYLAND", "1");

                lib.root_module.addCSourceFiles(.{
                    .files = &linux_wl_sources,
                    .flags = &.{
                        "-Wno-implicit-function-declaration",
                    },
                });
            }
        },
    }

    b.installArtifact(lib);

    // expose the GLAD and GLFW headers to dependents as a Zig module named "zigl",
    // which also links the library.
    const translate_c = b.dependency("translate_c", .{});
    const translator: Translator = .init(translate_c, .{
        .name = "zigl",
        .c_source_file = b.addWriteFiles().add("zigl.h",
            \\#include <glad/gl.h>
            \\#include <GLFW/glfw3.h>
            \\
        ),
        .target = target,
        .optimize = optimize,
    });
    translator.addIncludePath(b.path("include"));
    translator.linkLibrary(lib);
    b.modules.put(b.graph.arena, "zigl", translator.mod) catch @panic("OOM");
}

const base_sources = [_][]const u8{
    "src/GLFW/context.c",
    "src/GLFW/egl_context.c",
    "src/GLFW/init.c",
    "src/GLFW/input.c",
    "src/GLFW/monitor.c",
    "src/GLFW/null_init.c",
    "src/GLFW/null_joystick.c",
    "src/GLFW/null_monitor.c",
    "src/GLFW/null_window.c",
    "src/GLFW/osmesa_context.c",
    "src/GLFW/platform.c",
    "src/GLFW/vulkan.c",
    "src/GLFW/window.c",
};

const linux_sources = [_][]const u8{
    "src/GLFW/linux_joystick.c",
    "src/GLFW/posix_module.c",
    "src/GLFW/posix_poll.c",
    "src/GLFW/posix_thread.c",
    "src/GLFW/posix_time.c",
    "src/GLFW/xkb_unicode.c",
};

const linux_wl_sources = [_][]const u8{
    "src/GLFW/wl_init.c",
    "src/GLFW/wl_monitor.c",
    "src/GLFW/wl_window.c",
};

const linux_x11_sources = [_][]const u8{
    "src/GLFW/glx_context.c",
    "src/GLFW/x11_init.c",
    "src/GLFW/x11_monitor.c",
    "src/GLFW/x11_window.c",
};

const windows_sources = [_][]const u8{
    "src/GLFW/wgl_context.c",
    "src/GLFW/win32_init.c",
    "src/GLFW/win32_joystick.c",
    "src/GLFW/win32_module.c",
    "src/GLFW/win32_monitor.c",
    "src/GLFW/win32_thread.c",
    "src/GLFW/win32_time.c",
    "src/GLFW/win32_window.c",
};

const macos_sources = [_][]const u8{
    // C sources
    "src/GLFW/cocoa_time.c",
    "src/GLFW/posix_module.c",
    "src/GLFW/posix_thread.c",

    // ObjC sources
    "src/GLFW/cocoa_init.m",
    "src/GLFW/cocoa_joystick.m",
    "src/GLFW/cocoa_monitor.m",
    "src/GLFW/cocoa_window.m",
    "src/GLFW/nsgl_context.m",
};
