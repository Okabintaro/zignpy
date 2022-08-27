const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const testing = std.testing;

const parser = @import("dictparse.zig");

const InvalidHeader = error{
    NoMagic,
};

// The numpy format is documented here:
// https://numpy.org/devdocs/reference/generated/numpy.lib.format.html

const NPY_MAGIC = "\x93NUMPY";
const MAX_DIM = 1;

// https://numpy.org/devdocs/reference/arrays.dtypes.html
// https://numpy.org/devdocs/reference/arrays.interface.html#arrays-interface
const NpyDtype = enum {};

pub fn Tensor(comptime dtype: type) type {
    return struct {
        shape: [MAX_DIM]i32,
        data: []dtype,
    };
}

const TensorF64 = Tensor(f64);

const NumpyHeader = struct {
    major_version: u8,
    minor_version: u8,
    header_length: u16,

    // descr_dtype: ,
    descr_type: [8]u8,
    fortran_order: bool,
    shape: [MAX_DIM]i32,
};

fn readHeader(reader: anytype) anyerror!NumpyHeader {
    var magic: [6]u8 = undefined;
    try reader.readNoEof(magic[0..]);
    if (!mem.eql(u8, &magic, NPY_MAGIC))
        return InvalidHeader.NoMagic;

    var header: NumpyHeader = undefined;

    header.major_version = try reader.readByte();
    header.minor_version = try reader.readByte();
    header.header_length = try reader.readIntLittle(u16);
    // TODO: Sanity check those

    var headerString: [1024]u8 = undefined;
    try reader.readNoEof(headerString[0..header.header_length]);
    // print("{s}", .{headerString[0..header.header_length]});
    // TODO: Parse header

    header.shape[0] = 99;

    return header;
}

fn readData(reader: anytype, header: NumpyHeader, allocator: mem.Allocator) anyerror!TensorF64 {
    const len = @intCast(usize, header.shape[0]);
    var buffer = try allocator.alloc(f64, len);
    var tensor = TensorF64{ .data = buffer, .shape = header.shape };
    try reader.readNoEof(mem.sliceAsBytes(tensor.data));
    return tensor;
}

test "readHeader - success" {
    var file = try std.fs.cwd().openFile("test/simple.npy", .{});
    defer file.close();
    const allocator = std.testing.allocator;
    var reader = file.reader();
    const header = try readHeader(reader);
    const tensor = try readData(reader, header, allocator);
    defer allocator.free(tensor.data);

    //for (tensor.data) |val, i| {
    //    print("{d}= {d}\n", .{ i, val });
    //}

    try testing.expectEqual(tensor.shape, header.shape);
}
