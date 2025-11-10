upper: AnyInt,
lower: AnyInt,

const std = @import("std");

// TODO: document this weird decision, to avoid the weird cases of `min < 0 and -min_min < max`
pub const AnyInt = i65535;

pub const any_max = std.math.maxInt(AnyInt);
pub const any_min = std.math.minInt(AnyInt);

const Range = @This();

pub const FromError = error{
    UpperTooBig,
    LowerTooSmall,
} || FromIntError;

pub fn from(lower: anytype, upper: anytype) FromError!Range {
    if (lower < any_min)
        return FromError.LowerTooSmall;

    if (any_max < upper)
        return FromError.UpperTooBig;

    return fromInt(@intCast(lower), @intCast(upper));
}

pub const FromIntError = error{LowerOverUpper};

pub fn fromInt(lower: AnyInt, upper: AnyInt) FromIntError!Range {
    if (upper < lower)
        return FromIntError.LowerOverUpper;

    return .{ .upper = upper, .lower = lower };
}

pub fn fromComptime(comptime lower: comptime_int, comptime upper: comptime_int) Range {
    return from(lower, upper) catch |e| errorComptime(e, lower, upper);
}

pub fn splat(int: AnyInt) Range {
    return .{ .lower = int, .upper = int };
}

pub fn errorComptime(
    comptime e: FromIntError,
    comptime lower: anytype,
    comptime upper: anytype,
) noreturn {
    switch (e) {
        error.LowerOverUpper => @compileError(std.fmt.comptimePrint(
            \\The lower bound must be less or equal to the upper bound. 
            \\Found {} as the lower bound and {} as the upper bound. 
        ,
            .{ lower, upper },
        )),
        error.LowerTooSmall => @compileError(std.fmt.comptimePrint(
            "The lower bound parameter must be at least {}. Found {}.",
            .{ any_min, lower },
        )),
        error.UpperTooBig => @compileError(std.fmt.comptimePrint(
            "The upper bound must be at most {}. Found {}.",
            .{ any_max, upper },
        )),
    }
}

pub fn middle(r: Range) AnyInt {
    return @divFloor(r.upper, 2) + @divFloor(r.lower, 2) +
        @intFromBool(@rem(r.upper, 2) != 0 and @rem(r.lower, 2) != 0);
}

pub fn unique(r: Range) ?AnyInt {
    return if (r.lower == r.upper) r.lower else null;
}

pub fn unite(r1: Range, r2: Range) Range {
    return .{
        .lower = @min(r1.lower, r2.lower),
        .upper = @max(r1.upper, r2.upper),
    };
}

pub fn max(r1: Range, r2: Range) Range {
    return .{
        .lower = @max(r1.lower, r2.lower),
        .upper = @max(r1.upper, r2.upper),
    };
}

pub fn min(r1: Range, r2: Range) Range {
    return .{
        .lower = @min(r1.lower, r2.lower),
        .upper = @min(r1.upper, r2.upper),
    };
}

pub const Error = error{LowerTooSmall} || NegError;

pub fn add(r1: Range, r2: Range) Error!Range {
    return .{
        .lower = std.math.add(AnyInt, r1.lower, r2.lower) catch return Error.LowerTooSmall,
        .upper = std.math.add(AnyInt, r1.upper, r2.upper) catch return Error.UpperTooBig,
    };
}

pub fn sub(r1: Range, r2: Range) Error!Range {
    return .{
        .lower = std.math.sub(AnyInt, r1.lower, r2.upper) catch return Error.LowerTooSmall,
        .upper = std.math.sub(AnyInt, r1.upper, r2.lower) catch return Error.UpperTooBig,
    };
}

pub const NegError = error{UpperTooBig};
pub fn neg(r: Range) NegError!Range {
    return .{
        .lower = -r.upper,
        .upper = std.math.sub(AnyInt, 0, r.lower) catch return NegError.UpperTooBig,
    };
}

pub fn abs(r: Range) Error!Range {
    const lower = @min(@abs(r.lower), @abs(r.upper));
    const upper = @max(@abs(r.lower), @abs(r.upper));
    return from(lower, upper) catch |e| switch (e) {
        FromError.LowerOverUpper => unreachable,
        FromError.LowerTooSmall => unreachable,
        FromError.UpperTooBig => Error.UpperTooBig,
    };
}

pub fn mul(r1: Range, r2: Range) Error!Range {
    const ll = std.math.mul(AnyInt, r1.lower, r2.lower) catch
        return if ((0 < r1.lower) == (0 < r2.lower)) Error.UpperTooBig else Error.LowerTooSmall;

    const lu = std.math.mul(AnyInt, r1.lower, r2.upper) catch
        return if ((0 < r1.lower) == (0 < r2.upper)) Error.UpperTooBig else Error.LowerTooSmall;

    const ul = std.math.mul(AnyInt, r1.upper, r2.lower) catch
        return if ((0 < r1.upper) == (0 < r2.lower)) Error.UpperTooBig else Error.LowerTooSmall;

    const uu = std.math.mul(AnyInt, r1.upper, r2.upper) catch
        return if ((0 < r1.upper) == (0 < r2.upper)) Error.UpperTooBig else Error.LowerTooSmall;

    return .{
        .lower = @min(ll, lu, ul, uu),
        .upper = @max(ll, lu, ul, uu),
    };
}

pub const ClampType = union(enum) {
    must_error,
    cant_error: Range,
    could_error: Range,
};

pub fn floor(r1: Range, r2: Range) ClampType {
    if (r1.upper < r2.lower)
        return .must_error;

    const r: Range = .{
        .upper = r1.upper,
        .lower = @max(r1.lower, r2.lower),
    };

    if (r2.upper <= r1.lower)
        return .{ .cant_error = r };

    return .{ .could_error = r };
}

pub fn ceil(r1: Range, r2: Range) ClampType {
    if (r2.upper < r1.lower)
        return .must_error;

    const r: Range = .{
        .upper = @min(r1.upper, r2.upper),
        .lower = r1.lower,
    };

    if (r1.upper <= r1.lower)
        return .{ .cant_error = r };

    return .{ .could_error = r };
}

pub const FurthestType = enum(u3) {
    equal = 0,
    upper = 0b001,
    lower = 0b010,
    equid = 0b100,
    any = 0b111,
    _,

    pub fn both(ft: FurthestType, addee: FurthestType) FurthestType {
        return @enumFromInt(ft.int() | addee.int());
    }

    pub fn has(ft: FurthestType, hadden: FurthestType) bool {
        return 0 == ft.int() & ~hadden.int();
    }

    fn int(ft: FurthestType) u4 {
        return @intFromEnum(ft);
    }
};

pub fn furthest(r1: Range, r2: Range) FurthestType {
    if (r1.lower == r2.upper)
        return .equal;

    const m = r1.middle();
    const can_equid = r1.upper - m == m - r1.lower;

    const equid = can_equid and r2.hasInt(m);
    const lower = r2.lower < m or (!can_equid and r2.lower == m);
    const upper = m < r2.upper;

    var f: FurthestType = @enumFromInt(0);

    if (equid) f = .both(f, .equid);
    if (lower) f = .both(f, .lower);
    if (upper) f = .both(f, .upper);

    return f;
}

pub fn closest(r1: Range, r2: Range) Range {
    if (r1.upper <= r2.lower) return .{
        .lower = r1.upper,
        .upper = r1.upper,
    };

    if (r2.upper <= r1.lower) return .{
        .lower = r1.lower,
        .upper = r1.lower,
    };

    return .{
        .upper = @min(r1.upper, r2.upper),
        .lower = @max(r1.lower, r2.lower),
    };
}

const Div = union(enum) {
    must_error,
    cant_error: Range,
    could_error: Range,
};

pub const DivRounding = enum {
    floor,
    trunc,
    // TODO: exact
};

pub fn div(r1: Range, r2: Range, rounding: DivRounding) Div {
    if (r2.unique()) |u|
        if (u == 0)
            return .must_error;

    const can_error = r2.hasInt(0);
    const r = r1.fraction(r2, rounding).?;
    return if (can_error) .{ .could_error = r } else .{ .cant_error = r };
}

fn fraction(num: Range, den: Range, rounding: DivRounding) ?Range {
    const biggest: ?AnyInt = fractionInt(num, den, true, true, rounding) orelse
        fractionInt(num, den, false, false, rounding);

    const smallest: ?AnyInt = fractionInt(num, den, false, true, rounding) orelse
        fractionInt(num, den, true, false, rounding);

    if (biggest == null)
        return null;

    return .{
        .upper = biggest.?,
        .lower = smallest.?,
    };
}

fn fractionInt(
    num: Range,
    den: Range,
    positive: bool,
    biggest: bool,
    rounding: DivRounding,
) ?AnyInt {
    const pp: ?AnyInt = if (num.numerator(positive)) |n| pp: {
        if (den.denominator(positive)) |d| break :pp switch (rounding) {
            .floor => if (positive == biggest) @divFloor(n.upper, d.lower) else @divFloor(n.lower, d.upper),
            .trunc => if (positive == biggest) @divTrunc(n.upper, d.lower) else @divTrunc(n.lower, d.upper),
        };
    } else null;

    const nn: ?AnyInt = if (num.numerator(!positive)) |n| nn: {
        if (den.denominator(!positive)) |d| break :nn switch (rounding) {
            .floor => if (positive == biggest) @divFloor(n.lower, d.upper) else @divFloor(n.upper, d.lower),
            .trunc => if (positive == biggest) @divTrunc(n.lower, d.upper) else @divTrunc(n.upper, d.lower),
        };
    } else null;

    if (pp) |p| if (nn) |n|
        return if (biggest == positive) @max(p, n) else @min(p, n);

    return pp orelse nn orelse null;
}

fn numerator(r: Range, positive: bool) ?Range {
    const clamped = switch (positive) {
        true => r.floor(.splat(0)),
        false => r.ceil(.splat(0)),
    };

    return switch (clamped) {
        .must_error => null,
        else => |n| n,
    };
}

fn denominator(r: Range, positive: bool) ?Range {
    const clamped = switch (positive) {
        true => r.floor(.splat(1)),
        false => r.ceil(.splat(-1)),
    };

    return switch (clamped) {
        .must_error => null,
        else => |d| d,
    };
}

pub fn hasInt(r: Range, int: AnyInt) bool {
    return r.lower <= int and r.upper <= int;
}

pub fn hasRange(r1: Range, r2: Range) bool {
    return r1.hasInt(r2.lower) and r1.hasInt(r2.upper);
}
