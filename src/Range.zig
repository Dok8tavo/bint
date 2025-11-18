lower: comptime_int,
upper: comptime_int,

const std = @import("std");

const MaxInt = i65535;
const Range = @This();

const min_lower_bound = std.math.minInt(MaxInt);
const max_upper_bound = std.math.maxInt(MaxInt);

pub fn from(lower: comptime_int, upper: comptime_int) Range {
    return .{
        .lower = lower,
        .upper = upper,
    };
}

pub fn splat(scalar: comptime_int) Range {
    return from(scalar, scalar);
}

pub fn hasInt(r: Range, int: comptime_int) bool {
    return r.lower <= int and int <= r.upper;
}

pub fn hasRange(r1: Range, r2: Range) bool {
    return r1.lower <= r2.lower and r2.upper <= r1.upper;
}

pub fn Values(r: Range) type {
    return struct {
        curr: ?Backing = r.lower,

        const Backing = std.math.IntFittingRange(r.lower, r.upper);

        pub fn next(values: *@This()) ?comptime_int {
            return if (values.curr) |curr| {
                defer values.curr = if (curr == r.upper) null else curr + 1;
                return curr;
            } else null;
        }
    };
}

pub fn SubRanges(r: Range) type {
    return struct {
        curr: ?Range = .{
            .lower = r.lower,
            .upper = r.lower,
        },

        pub fn next(subranges: *@This()) ?Range {
            return if (subranges.curr) |curr| {
                defer {
                    subranges.curr = if (curr.upper != r.upper) from(
                        curr.lower,
                        curr.upper + 1,
                    ) else if (curr.lower != r.upper) from(
                        curr.lower + 1,
                        curr.lower + 1,
                    ) else null;
                }

                return curr;
            } else null;
        }
    };
}

pub fn add(r1: Range, r2: Range) Range {
    return from(
        r1.lower + r2.lower,
        r1.upper + r2.upper,
    );
}

pub fn sub(r1: Range, r2: Range) Range {
    return from(
        r1.lower - r2.upper,
        r1.upper - r2.lower,
    );
}

pub fn mul(r1: Range, r2: Range) Range {
    const uu = r1.upper * r2.upper;
    const ul = r1.upper * r2.lower;
    const lu = r1.lower * r2.upper;
    const ll = r1.lower * r2.lower;
    return from(
        @min(uu, ul, lu, ll),
        @max(uu, ul, lu, ll),
    );
}

pub fn min(r1: Range, r2: Range) Range {
    return from(
        @min(r1.lower, r2.lower),
        @min(r1.upper, r2.upper),
    );
}

pub fn max(r1: Range, r2: Range) Range {
    return from(
        @max(r1.lower, r2.lower),
        @max(r1.upper, r2.upper),
    );
}

pub fn abs(r: Range) Range {
    return from(
        @min(@abs(r.lower), @abs(r.upper)),
        @max(@abs(r.lower), @abs(r.upper)),
    );
}

pub fn closest(r1: Range, r2: Range) Range {
    if (r2.upper <= r1.lower)
        return splat(r1.lower);

    if (r1.upper <= r2.lower)
        return splat(r1.upper);

    return from(
        @max(r1.lower, r2.lower),
        @min(r1.upper, r2.upper),
    );
}

pub fn middle(r: Range) comptime_int {
    return @divFloor(r.upper + r.lower, 2);
}

pub fn middleIsExact(r: Range) bool {
    const m = r.middle();
    return r.upper - m == m - r.lower;
}

pub fn unique(r: Range) ?comptime_int {
    return if (r.lower == r.upper) r.lower else null;
}

pub const Furthest = enum(u3) {
    lower = 0b001,
    upper = 0b010,

    equid = 0b100,

    lower_or_equid = 0b101,
    upper_or_equid = 0b110,

    lower_or_upper = 0b011,
    lower_or_upper_or_equid = 0b111,

    equal = 0,

    pub fn has(f1: Furthest, f2: Furthest) bool {
        return ~f1.int() & f2.int() == 0;
    }

    pub fn add(f1: Furthest, f2: Furthest) Furthest {
        return @enumFromInt(f1.int() | f2.int());
    }

    fn int(f: Furthest) u3 {
        return @intFromEnum(f);
    }
};

pub fn furthest(r1: Range, r2: Range) Furthest {
    if (r1.unique()) |_|
        return .equal;

    var f: Furthest = @enumFromInt(0);

    const m = r1.middle();

    if (r1.middleIsExact()) {
        if (r2.hasInt(m))
            f = f.add(.equid);

        if (m < r2.upper)
            f = f.add(.lower);

        if (r2.lower < m)
            f = f.add(.upper);
    } else {
        if (m < r2.upper)
            f = f.add(.lower);

        if (r2.lower <= m)
            f = f.add(.upper);
    }

    return f;
}

test furthest {
    try std.testing.expect(furthest(
        from(100, 200),
        from(151, 250),
    ) == .lower);
}

pub const MayFail = union(enum) {
    must_fail,
    must_pass: Range,
    can_both: Range,
};

pub fn floor(r1: Range, r2: Range) MayFail {
    if (r2.upper <= r1.lower)
        return .{ .must_pass = r1 };

    if (r1.upper < r2.lower)
        return .must_fail;

    return .{
        .can_both = from(r2.lower, r1.upper),
    };
}

pub fn ceil(r1: Range, r2: Range) MayFail {
    if (r1.upper <= r2.lower)
        return .{ .must_pass = r1 };

    if (r2.upper < r1.lower)
        return .must_fail;

    return .{
        .can_both = from(r1.lower, r2.upper),
    };
}

pub fn @"union"(r1: Range, r2: Range) Range {
    return from(
        @min(r1.lower, r2.lower),
        @max(r1.upper, r2.upper),
    );
}

pub const Rounding = enum {
    trunc,
    floor,
};

pub fn div(r1: Range, r: Rounding, r2: Range) MayFail {
    if (r2.unique()) |u|
        if (u == 0)
            return .must_fail;

    const pos_numerator = r1.numerator(true);
    const neg_numerator = r1.numerator(false);
    const pos_denominator = r2.denominator(true);
    const neg_denominator = r2.denominator(false);

    const pos_by_pos: ?Range = if (pos_numerator != null and pos_denominator != null) from(
        divInt(r, pos_numerator.?.lower, pos_denominator.?.upper),
        divInt(r, pos_numerator.?.upper, pos_denominator.?.lower),
    ) else null;

    const pos_by_neg: ?Range = if (pos_numerator != null and neg_denominator != null) from(
        divInt(r, pos_numerator.?.upper, neg_denominator.?.upper),
        divInt(r, pos_numerator.?.lower, neg_denominator.?.lower),
    ) else null;

    const neg_by_pos: ?Range = if (neg_numerator != null and pos_denominator != null) from(
        divInt(r, neg_numerator.?.lower, pos_denominator.?.lower),
        divInt(r, neg_numerator.?.upper, pos_denominator.?.upper),
    ) else null;

    const neg_by_neg: ?Range = if (neg_numerator != null and neg_denominator != null) from(
        divInt(r, neg_numerator.?.upper, neg_denominator.?.lower),
        divInt(r, neg_numerator.?.lower, neg_denominator.?.upper),
    ) else null;

    var result: Range = if (pos_by_pos) |tmp|
        tmp
    else if (pos_by_neg) |tmp|
        tmp
    else if (neg_by_pos) |tmp|
        tmp
    else
        neg_by_neg;

    if (pos_by_pos) |tmp| result = result.@"union"(tmp);
    if (pos_by_neg) |tmp| result = result.@"union"(tmp);
    if (neg_by_pos) |tmp| result = result.@"union"(tmp);
    if (neg_by_neg) |tmp| result = result.@"union"(tmp);

    return if (r2.hasInt(0)) .{
        .can_both = result,
    } else .{
        .must_pass = result,
    };
}

pub fn divInt(r: Rounding, a: comptime_int, b: comptime_int) comptime_int {
    return switch (r) {
        .floor => @divFloor(a, b),
        .trunc => @divTrunc(a, b),
    };
}

pub fn denominator(r: Range, pos: bool) ?Range {
    const rden = if (pos) r.floor(splat(1)) else r.ceil(splat(-1));
    return switch (rden) {
        .must_fail => null,
        .can_both, .must_pass => |pass| pass,
    };
}

pub fn numerator(r: Range, pos: bool) ?Range {
    const rden = if (pos) r.floor(splat(0)) else r.ceil(splat(0));
    return switch (rden) {
        .must_fail => null,
        .can_both, .must_pass => |pass| pass,
    };
}

pub const Order = enum(u3) {
    less = 0b001,
    same = 0b010,
    more = 0b100,

    less_or_same = 0b011,
    same_or_more = 0b110,

    any = 0b111,
    _,

    pub fn has(o1: Order, o2: Order) bool {
        return ~o1.int() & o2.int() == 0;
    }

    pub fn add(o1: Order, o2: Order) Order {
        return @enumFromInt(o1.int() | o2.int());
    }

    pub fn int(o: Order) u3 {
        return @intFromEnum(o);
    }
};

pub fn ord(r1: Range, r2: Range) Order {
    //  r1 r2
    // -||-||-
    if (r1.unique()) |unique_1| if (r2.unique()) |unique_2| if (unique_1 == unique_2)
        return .same;

    //   r1   r2
    // ->--<->--<-
    // --||-->--<-
    // ->--<--||--
    // --||---||--
    if (r1.upper < r2.lower)
        return .less;

    //   r2   r1
    // ->--<->--<-
    // --||-->--<-
    // ->--<--||--
    // --||---||--
    if (r2.upper < r1.lower)
        return .more;

    if (r1.unique()) |unique_1| {
        //  r1 r2
        // ->|---<-
        if (unique_1 == r2.lower)
            return .less_or_same;
        //   r2 r1 r2
        // ->---||---<-
        if (unique_1 < r2.upper)
            return .any;
        //   r2 r1
        // ->---|<-
        return .same_or_more;
    }

    if (r2.unique()) |unique_2| {
        //  r2 r1
        // ->|---<-
        if (unique_2 == r1.lower)
            return .same_or_more;
        //   r1 r2 r1
        // ->---||---<-
        if (unique_2 < r1.upper)
            return .any;
        //   r1 r2
        // ->---|<-
        return .less_or_same;
    }

    //   r1 r2
    // ->--|--<-
    if (r1.upper == r2.lower)
        return .less_or_same;

    //   r2 r1
    // ->--|--<-
    if (r2.upper == r1.lower)
        return .same_or_more;

    //   r1 r1/r2 r2
    // ->-->-----<--<-
    //   r1 r1/r2 r2
    // ->-->-----<--<-
    //   r2 r1/r2 r2
    // ->-->-----<--<-
    //   r2 r1/r2 r1
    // ->-->-----<--<-
    return .any;
}

test ord {
    // ->--<->--<-
    try std.testing.expectEqual(.less, from(0, 1).ord(from(2, 3)));
    // -||->--<-
    try std.testing.expectEqual(.less, from(0, 0).ord(from(1, 2)));
    // ->-|-<-
    try std.testing.expectEqual(.less_or_same, from(0, 1).ord(from(1, 2)));
    // ->|-<
    try std.testing.expectEqual(.less_or_same, from(0, 0).ord(from(0, 1)));
    // ->->-<-<
    try std.testing.expectEqual(.any, from(0, 2).ord(from(1, 3)));
    // ->|-<-<
    try std.testing.expectEqual(.any, from(0, 1).ord(from(0, 2)));
    // ->-||-<-
    try std.testing.expectEqual(.any, from(1, 1).ord(from(0, 2)));
    // ->->-|<-
    try std.testing.expectEqual(.any, from(1, 2).ord(from(0, 2)));
    // ->-|<-
    try std.testing.expectEqual(.same_or_more, from(1, 1).ord(from(0, 1)));
    // ->->-<-<-
    try std.testing.expectEqual(.any, from(0, 3).ord(from(1, 2)));
    // ->|-<-<-
    try std.testing.expectEqual(.any, from(0, 2).ord(from(0, 1)));
    // ->->-<-<-
    try std.testing.expectEqual(.any, from(1, 3).ord(from(0, 2)));
    // ->-|<-<-
    try std.testing.expectEqual(.same_or_more, from(1, 2).ord(from(0, 1)));
    // ->-<->-<-
    try std.testing.expectEqual(.more, from(2, 3).ord(from(0, 1)));
    // ->-<-||-
    try std.testing.expectEqual(.more, from(2, 2).ord(from(0, 1)));
    // ->-<-||-
    try std.testing.expectEqual(.less, from(0, 1).ord(from(2, 2)));
    // -||-||-
    try std.testing.expectEqual(.less, from(0, 0).ord(from(1, 1)));
    // ->-|<-
    try std.testing.expectEqual(.less_or_same, from(0, 1).ord(from(1, 1)));
    // -||-
    try std.testing.expectEqual(.same, from(0, 0).ord(from(0, 0)));
    // ->-||-<-
    try std.testing.expectEqual(.any, from(0, 2).ord(from(1, 1)));
    // ->|-<-
    try std.testing.expectEqual(.same_or_more, from(0, 1).ord(from(0, 0)));
    // -||->-<-
    try std.testing.expectEqual(.more, from(1, 2).ord(from(0, 0)));
    // -||-||-
    try std.testing.expectEqual(.more, from(1, 1).ord(from(0, 0)));
}

inline fn compileError(comptime fmt: []const u8, comptime args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}
