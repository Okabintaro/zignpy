const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const testing = std.testing;

const dictparser = @import("dictparse.zig");

const InvalidHeader = error{
    NoMagic,
};

// The numpy format is documented here:
// https://numpy.org/devdocs/reference/generated/numpy.lib.format.html

const NPY_MAGIC = "\x93NUMPY";
const MAX_DIM = 8;

pub fn Tensor(comptime dtype: type) type {
    return struct {
        shape: [MAX_DIM]u32,
        data: []dtype,
    };
}

const TensorF64 = Tensor(f64);

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
        if (!mem.eql(u8, &magic, NPY_MAGIC))
            return InvalidHeader.NoMagic;

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

        return header;
    }
};

fn readData(reader: anytype, header: NumpyHeader, allocator: mem.Allocator) anyerror!TensorF64 {
    const len = @intCast(usize, header.shape[0]);
    var buffer = try allocator.lloc(f64, len);
    var tensor = TensorF64{ .data = buffer, .shape = header.shape };
    try reader.readNoEof(mem.sliceAsBytes(tensor.data));
    return tensor;
}

test "read header successfully" {
    var file = try std.fs.cwd().openFile("test/simple.npy", .{});
    defer file.close();
    const allocator = std.testing.allocator;

    var reader = file.reader();
    const header = try NumpyHeader.read(reader, allocator);
    try testing.expectEqual([_:0]u32{ 99, 0, 0, 0, 0, 0, 0, 0 }, header.shape);
    try testing.expectEqual(NumpyType.float64_LE, header.dtype);
    try testing.expectEqual(false, header.fortran_order);
}

test "read tensor" {
    // var tensor = Tensor(f64).read_npy("test/simple.npy");

}
