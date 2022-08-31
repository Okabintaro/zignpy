const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const testing = std.testing;
const sa = @import("zig-strided-array");

const dictparser = @import("dictparse.zig");

const NpyError = error{
    InvalidMagic,
    NonMatchingType,
    NonMatchingDims,
    UnsupportedFortranOrder,
};

// The numpy format is documented here:
// https://numpy.org/devdocs/reference/generated/numpy.lib.format.html

const NPY_MAGIC = "\x93NUMPY";
const MAX_DIM = 8;

pub fn Tensor(comptime T: type, comptime num_dims: usize) type {
    return struct {
        const Self = @This();
        const dtype = NumpyType.from_type(T);

        data: []T = undefined,
        shape: [num_dims]u32 = .{0} ** num_dims,
        allocator: mem.Allocator = undefined,
        view: sa.StridedArrayView(T, num_dims) = undefined,

        pub fn readNpy(reader: anytype, allocator: mem.Allocator) anyerror!Self {
            var header = try NumpyHeader.read(reader, allocator);
            if (header.dtype != dtype) {
                return NpyError.NonMatchingType;
            }
            var self = Self{};
            self.allocator = allocator;

            std.mem.copy(u32, self.shape[0..num_dims], header.shape[0..num_dims]);
            // std.debug.print("\ndim[{}] = {}\n", .{ 0, self.shape[0] });

            var size: usize = 1;
            comptime var i = 0;
            inline while (i < num_dims) : (i += 1) {
                size *= self.shape[i];
            }
            self.data = try allocator.alloc(T, size);
            try reader.readNoEof(mem.sliceAsBytes(self.data));

            self.view = try sa.StridedArrayView(T, num_dims).ofSlicePacked(self.data, self.shape[0..num_dims].*);
            return self;
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.data);
        }
    };
}

pub const NumpyType = enum {
    float32_LE,
    float64_LE,

    pub fn parse(str: []const u8) ?NumpyType {
        // TODO: Proper/Faster parsing
        if (std.mem.eql(u8, str, "<f4")) {
            return .float32_LE;
        } else if (std.mem.eql(u8, str, "<f8")) {
            return .float64_LE;
        }
        return null;
    }

    pub fn dtype(self: NumpyType) type {
        return switch (self) {
            .float64_LE => f64,
            .float32_LE => f32,
        };
    }

    pub fn from_type(comptime T: type) NumpyType {
        return switch (T) {
            f64 => .float64_LE,
            f32 => .float32_LE,
            else => @compileError("The given type is not supported yet"),
        };
    }
};

pub const NumpyHeader = struct {
    major_version: u8,
    minor_version: u8,
    header_length: u16,

    // TODO: Parse or match descr_type
    // https://numpy.org/devdocs/reference/arrays.dtypes.html
    // https://numpy.org/devdocs/reference/arrays.interface.html#arrays-interface
    dtype: NumpyType,
    fortran_order: bool,
    shape: [MAX_DIM:0]u32,

    pub fn read(reader: anytype, allocator: mem.Allocator) anyerror!NumpyHeader {
        var magic: [6]u8 = undefined;
        try reader.readNoEof(magic[0..]);
        if (!mem.eql(u8, &magic, NPY_MAGIC)) {
            return NpyError.InvalidMagic;
        }

        var header: NumpyHeader = undefined;

        // TODO: Sanity check those?
        header.major_version = try reader.readByte();
        header.minor_version = try reader.readByte();
        header.header_length = try reader.readIntLittle(u16);

        var headerString: [1024]u8 = undefined;
        try reader.readNoEof(headerString[0..header.header_length]);

        var parser = dictparser.Parser.init();
        var headerMap = try parser.parseDict(headerString[0..header.header_length], allocator);
        defer headerMap.deinit();

        // TODO: More descriptive errors
        header.dtype = NumpyType.parse(headerMap.get("descr").?.string).?;
        header.fortran_order = headerMap.get("fortran_order").?.boolean;
        header.shape = headerMap.get("shape").?.tuple;

        if (header.fortran_order) {
            return NpyError.UnsupportedFortranOrder;
        }

        return header;
    }
};

test "read header successfully" {
    var file = try std.fs.cwd().openFile("test/simple_f64.npy", .{});
    defer file.close();
    const allocator = std.testing.allocator;

    var reader = file.reader();
    const header = try NumpyHeader.read(reader, allocator);
    try testing.expectEqual([_:0]u32{ 99, 0, 0, 0, 0, 0, 0, 0 }, header.shape);
    try testing.expectEqual(NumpyType.float64_LE, header.dtype);
    try testing.expectEqual(false, header.fortran_order);
}

fn test_arange(comptime T: type, filename: []const u8) anyerror!Tensor(T, 1) {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    var reader = file.reader();

    const allocator = std.testing.allocator;
    var tensor = try Tensor(T, 1).readNpy(reader, allocator);

    for (tensor.data) |elem, i| {
        const testVal = @intToFloat(T, i + 1);
        try testing.expectEqual(testVal, elem);
    }
    return tensor;
}

fn test_2d_iter(comptime T: type, filename: []const u8) anyerror!void {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    var reader = file.reader();

    const allocator = std.testing.allocator;
    var tensor = try Tensor(T, 2).readNpy(reader, allocator);
    defer tensor.deinit();

    try testing.expectEqual(@as(T, 0), tensor.view.get(.{ 0, 0 }));
    try testing.expectEqual(@as(T, 101), tensor.view.get(.{ 1, 1 }));
    try testing.expectEqual(@as(T, 202), tensor.view.get(.{ 2, 2 }));
    try testing.expectEqual(@as(T, 303), tensor.view.get(.{ 3, 3 }));
    try testing.expectEqual(@as(T, 404), tensor.view.get(.{ 4, 4 }));

    // Iterate over 6th row: 500..599
    var iter = tensor.view.slice(.{ 5, 0 }, .{ 0, 100 }).iterate();
    var i: usize = 500;
    while (iter.next()) |val| : (i += 1) {
        try testing.expectEqual(@intToFloat(T, i), val);
    }
}

test "read simple 1-d npy file" {
    var simple_f64: Tensor(f64, 1) = try test_arange(f64, "test/simple_f64.npy");
    defer simple_f64.deinit();
    try testing.expectEqual(@as(u32, 99), simple_f64.shape[0]);

    var simple_f32: Tensor(f32, 1) = try test_arange(f32, "test/simple_f32.npy");
    defer simple_f32.deinit();
    try testing.expectEqual(@as(u32, 99), simple_f32.shape[0]);

    var bigger_f32: Tensor(f32, 1) = try test_arange(f32, "test/bigger_f32.npy");
    defer bigger_f32.deinit();
    try testing.expectEqual(@as(u32, 999), bigger_f32.shape[0]);
}

test "read simple 2-d npy file" {
    try test_2d_iter(f32, "test/simple_2d_f32.npy");
}

test "read wrongly typed simple 1-d npy file" {
    var err = test_arange(f64, "test/simple_f32.npy");
    var err2 = test_arange(f64, "test/simple_f32.npy");
    try testing.expectError(NpyError.NonMatchingType, err);
    try testing.expectError(NpyError.NonMatchingType, err2);
}
