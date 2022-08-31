const std = @import("std");

const pkgs = struct {
    const strided_array = std.build.Pkg{
        .name = "zig-strided-array",
        .source = .{ .path = "./lib/zig-strided-arrays/src/strided_array.zig" },
        .dependencies = &[_]std.build.Pkg{},
    };
};

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    // b.use_stage1 = true;
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zignpy", "src/main.zig");
    lib.addPackage(pkgs.strided_array);
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.addPackage(pkgs.strided_array);
    const parse_tests = b.addTest("src/dictparse.zig");
    parse_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&parse_tests.step);
}
