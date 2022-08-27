const example = "{'descr': '<f8', 'fortran_order': False, 'shape': (99,), }";
const std = @import("std");
const mem = std.mem;

const ParserState = enum {
    Start,
    ExpectKey,
    InKey,
    ExpectColon,
    InVal,
    Finished,
};

const ParseError = error{
    InvalidStart,
    ExpectedColon,
    Todo,
};

fn parseDict(input: []const u8, allocator: mem.Allocator) anyerror!std.StringHashMap([]const u8) {
    _ = input;
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer map.deinit();

    var state: ParserState = ParserState.Start;
    var start: usize = 0;
    var end: usize = 0;
    var key: ?[]const u8 = null;

    for (input) |ch, i| {
        switch (state) {
            .Start => {
                if (ch == '{') {
                    state = ParserState.ExpectKey;
                } else {
                    return ParseError.InvalidStart;
                }
            },
            .ExpectKey => {
                state = switch (ch) {
                    '}' => ParserState.Finished,
                    '\'' => blk: {
                        start = i + 1;
                        break :blk ParserState.InKey;
                    },
                    else => {
                        return ParseError.Todo;
                    },
                };
            },
            .InKey => {
                state = switch (ch) {
                    '\'' => blk: {
                        end = i;
                        key = input[start..end];
                        break :blk ParserState.ExpectColon;
                    },
                    else => ParserState.InKey, // Waiting for '
                };
            },
            .ExpectColon => {
                state = switch (ch) {
                    ':' => blk: {
                        start = i + 1;
                        break :blk ParserState.InVal;
                    },
                    else => {
                        return ParseError.ExpectedColon;
                    },
                };
            },
            .InVal => {
                state = switch (ch) {
                    ',' => blk: {
                        end = i;
                        const val = input[start..end];
                        try map.put(key.?, val);
                        // std.debug.print("put(|{s}|, |{s}|)", .{ key.?, val });
                        break :blk ParserState.ExpectKey;
                    },
                    '}' => blk: {
                        end = i;
                        const val = input[start..end];
                        // std.debug.print("put(|{s}|, |{s}|)", .{ key.?, val });
                        try map.put(key.?, val);
                        break :blk ParserState.Finished;
                    },
                    else => ParserState.InVal,
                };
            },

            else => unreachable,
        }
        // std.debug.print("ch: {c}, i: {}, state: {}\n", .{ ch, i, state });
    }

    return map;
}

const testing = std.testing;

test "empty dict" {
    const empty = "{}";
    const alloc = std.testing.allocator;
    var result = try parseDict(empty[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 0), result.count());
}

test "A string" {
    const in = "{'hello':'world'}";
    const alloc = std.testing.allocator;
    var result = try parseDict(in[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 1), result.count());

    const val = result.get("hello").?;
    try testing.expect(mem.eql(u8, "'world'", val));
}
