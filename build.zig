const std = @import("std");
const io = std.io;
const Level = std.log.Level;
const Build = std.Build;

const Pack = struct {
    step: *Build.Step,
    zjb: *Build.Dependency,
    zjb_art: *Build.Step.Run,

    fn init(b: *Build, comptime zjb_bridge_name: []const u8) Pack {
        const step = b.step("pack", "Accumulate static assets");
        // configure zjb
        const zjb = b.dependency("zjb", .{});
        const zjb_art = b.addRunArtifact(zjb.artifact("generate_js"));
        const zjb_out = zjb_art.addOutputFileArg(zjb_bridge_name);
        zjb_art.addArg("Zjb");
        // add JS bindings
        const bridge = b.addInstallFileWithDir(zjb_out, Build.InstallDir.bin, zjb_bridge_name);
        step.dependOn(&bridge.step);
        // return `Pack` object
        return .{ .step = step, .zjb = zjb, .zjb_art = zjb_art };
    }

    fn add_dir(self: *const Pack, b: *Build, path: Build.LazyPath) void {
        const dir = b.addInstallDirectory(.{
            .source_dir = path,
            .install_dir = Build.InstallDir.bin,
            .install_subdir = "",
        });
        self.step.dependOn(&dir.step);
    }

    fn add_exe(
        self: *const Pack,
        b: *Build,
        comptime name: []const u8,
        path: Build.LazyPath,
    ) void {
        // define target architecture
        const target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        };
        // describe executable
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = path,
            .target = b.resolveTargetQuery(target),
            .optimize = b.standardOptimizeOption(.{}),
        });
        exe.entry = .disabled;
        exe.rdynamic = true;
        exe.root_module.addImport("zjb", self.zjb.module("zjb"));
        // expose JS bindings to executable
        self.zjb_art.addArtifactArg(exe);
        // add dependency to 'pack' step
        self.step.dependOn(&b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = Build.InstallDir.bin,
            },
        }).step);
    }
};

pub fn build(b: *Build) void {
    const pack = Pack.init(b, "bridge.js");
    // if `zig build` is called, the 'pack' step is executed
    b.default_step = pack.step;
    // generates a WASM executable named 'core'
    pack.add_exe(b, "core", b.path("src/main.zig"));
    // contains site root and assets
    pack.add_dir(b, b.path("static"));

    // only fails when stderr is unwritable
    // error can be safely ignored
    const host = build_host(b, &[_]([]const u8){ "python", "python3" });
    host.dependOn(pack.step);
}

// always returns
fn build_host(
    b: *Build,
    comptime py_path_entries: []const []const u8,
) *Build.Step {
    // handle failed 'host' composition
    if (build_host_inner(b, py_path_entries)) |host| {
        return host;
    } else |err| {
        const writer = io.getStdErr().writer();
        // log the actual error
        writer.print("Configuration of 'host' step failed:\n\t{}\n", .{err}) catch {};
        // log python binary name options
        writer.print("PATH must contain at least one of [", .{}) catch {};
        var idx: usize = 0;
        for (py_path_entries) |item| {
            writer.print("'{s}'", .{item}) catch {};
            idx += 1;
            if (idx < py_path_entries.len) {
                writer.print(", ", .{}) catch {};
            }
        }
        writer.print("].", .{}) catch {};
        // make a dummy 'host' step and return
        return b.step("host", "Python must be installed to serve the project");
    }
}

fn build_host_inner(
    b: *Build,
    comptime py_path_entries: []const []const u8,
) !*Build.Step {
    // ensure python is in PATH
    const py_path = try b.findProgram(py_path_entries, &.{""});
    // configure `host` build step
    const host = b.step("host", "Statically serve project files");
    // allow the user to specify a port
    const port_default = 8080;
    const port_option_text = b.fmt("Specify the port (default {d})", .{port_default});
    const port = b.option(u32, "port", port_option_text) orelse port_default;
    // compose the command
    const host_command = b.addSystemCommand(&.{
        py_path,
        "-m",
        "http.server",
        b.fmt("{d}", .{port}),
        "--directory",
        b.getInstallPath(Build.InstallDir.bin, ""),
    });
    host.dependOn(&host_command.step);
    // return 'host' step to build
    return host;
}
