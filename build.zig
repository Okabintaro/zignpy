const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    // b.use_stage1 = true;
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zignpy", "src/main.zig");
    lib.use_stage1 = false;
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    const parse_tests = b.addTest("src/dictparse.zig");
    parse_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&parse_tests.step);
}
