const std = @import("std");

const Range = @import("Range.zig");

const MaxUint = u65535;
const MaxInt = i65535;

pub fn from(int: anytype) From(@TypeOf(int)) {
    if (comptime isBint(@TypeOf(int)))
        return int;
    return @enumFromInt(int);
}

pub fn fromComptime(comptime int: comptime_int) FromComptime(int) {
    return @enumFromInt(int);
}

pub fn FromComptime(comptime int: comptime_int) type {
    return Bint(int, int);
}

pub fn From(comptime T: type) type {
    return Bint(
        if (isBint(T))
            T.min_int
        else
            std.math.minInt(T),
        if (isBint(T))
            T.max_int
        else
            std.math.maxInt(T),
    );
}

pub fn rangeCompileError(
    comptime e: Range.FromError,
    comptime minimum: comptime_int,
    comptime maximum: comptime_int,
) noreturn {
    switch (e) {
        error.LowerOverUpper => compileError(
            \\The `minimum` parameter must be less or equal to the `maximum` parameter. 
            \\Found {} as the `minimum` and {} as the `maximum`. 
        ,
            .{ minimum, maximum },
        ),
        error.LowerTooSmall => compileError(
            "The `minimum` parameter must be at least {}. Found {}.",
            .{ Range.any_min, minimum },
        ),
        error.UpperTooBig => compileError(
            "The `maximum` parameter must be at most {}. Found {}.",
            .{ Range.any_max, maximum },
        ),
    }
}

/// This function checks whether the `T` parameter has been returned specifically by `Bint`.
pub fn isBint(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        else => false,
        .@"enum" => @hasDecl(T, "max_int") and
            @hasDecl(T, "min_int") and
            @TypeOf(T.max_int) == comptime_int and
            @TypeOf(T.min_int) == comptime_int and
            T.min_int <= T.max_int and
            T == Bint(T.min_int, T.max_int),
    };
}

pub fn FromRange(r: Range) type {
    return Bint(r.lower, r.upper);
}

pub fn Bint(comptime minimum: comptime_int, comptime maximum: comptime_int) type {
    const r = Range.from(minimum, maximum) catch |e|
        rangeCompileError(e, minimum, maximum);

    return enum(Backing) {
        _,

        const Self = @This();

        pub const range = r;

        pub const min_bint: Self = @enumFromInt(min_int);
        pub const mid_bint: Self = @enumFromInt(mid_int);
        pub const max_bint: Self = @enumFromInt(max_int);

        pub const min_int = minimum;
        pub const max_int = maximum;
        pub const mid_int: comptime_int = range.middle();

        pub const unique_int: ?comptime_int = range.unique() orelse null;

        pub const Backing = std.math.IntFittingRange(min_int, max_int);

        pub const DivisionError = error{DivisionByZero};
        pub const BoundsError = error{
            /// An attempt to make/use a bint outside of its defined bounds.
            OutOfBoundsInteger,
        };

        pub fn InitError(comptime T: type) type {
            const Other = From(T);
            return if (Self.range.hasRange(Other.range))
                error{}
            else
                BoundsError;
        }

        pub fn InitPayload(comptime T: type) type {
            const Other = From(T);
            return Bint(
                if (Self.range.upper < Other.range.lower)
                    return noreturn
                else
                    min_int,
                if (Other.range.upper < Self.range.lower)
                    return noreturn
                else
                    max_int,
            );
        }

        pub fn Init(comptime T: type) type {
            return InitError(T)!InitPayload(T);
        }

        pub fn Add(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.add(Other.range) catch @compileError("TODO"));
        }

        pub fn Sub(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.sub(Other.range) catch @compileError("TODO"));
        }

        pub const Neg = FromRange(range.neg() catch @compileError("TODO"));

        pub fn Mul(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.mul(Other.range) catch @compileError("TODO"));
        }

        pub fn Min(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.min(Other.range));
        }

        pub fn Max(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.max(Other.range));
        }

        pub const Abs = FromRange(range.abs() catch @compileError("TODO"));

        pub fn FloorError(comptime T: type) type {
            const Other = From(T);
            return switch (range.floor(Other.range)) {
                .cant_error => error{},
                else => BoundsError,
            };
        }

        pub fn FloorPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.floor(Other.range)) {
                .must_error => return noreturn,
                else => |floored_range| floored_range,
            });
        }

        pub fn Floor(comptime T: type) type {
            return FloorError(T)!FloorPayload(T);
        }

        pub fn CeilPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.ceil(Other.range)) {
                .must_error => return noreturn,
                else => |ceiled_range| ceiled_range,
            });
        }

        pub fn CeilError(comptime T: type) type {
            const Other = From(T);
            return switch (range.ceil(Other.range)) {
                .cant_error => error{},
                else => BoundsError,
            };
        }

        pub fn Ceil(comptime T: type) type {
            return CeilError(T)!CeilPayload(T);
        }

        pub fn Closest(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.closest(Other.range));
        }

        pub fn Furthest(comptime T: type) type {
            const Other = From(T);

            const rf = range.furthest(Other.range);

            const Upper = if (rf.has(.upper)) void else noreturn;
            const Lower = if (rf.has(.lower)) void else noreturn;
            const Equid = if (rf.has(.equid)) void else noreturn;
            const Equal = if (rf == .equal) void else noreturn;

            return union(enum) {
                /// The upper bound is furthest.
                upper: Upper,
                /// The lower bound is furthest.
                lower: Lower,
                /// The upper and lower bound aren't equal, but equidistant.
                equid: Equid,
                /// The upper and lower bound are equals anyway.
                equal: Equal,

                pub fn int(f: Furthest(T)) ?Backing {
                    return switch (f) {
                        .equal => null,
                        .upper => max_int,
                        .lower => min_int,
                        .equid => unique_int.?,
                    };
                }

                pub fn bint(f: Furthest(T)) ?Self {
                    return switch (f) {
                        .equal => null,
                        .upper => max_bint,
                        .lower => min_bint,
                        .equid => mid_bint,
                    };
                }
            };
        }

        pub fn Union(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.unite(Other.range));
        }

        pub fn DivError(comptime T: type) type {
            const Other = From(T);
            return switch (range.div(Other.range, .floor)) {
                .cant_error => error{},
                else => DivisionError,
            };
        }

        pub fn DivFloorPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.div(Other.range, .floor)) {
                .must_error => return noreturn,
                else => |div_range| div_range,
            });
        }

        pub fn DivFloor(comptime T: type) type {
            return DivError(T)!DivFloorPayload(T);
        }

        pub fn DivTruncPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.div(Other.range, .trunc)) {
                .must_error => return noreturn,
                else => |div_range| div_range,
            });
        }

        pub fn DivTrunc(comptime T: type) type {
            return DivError(T)!DivTruncPayload(T);
        }

        pub fn init(int: anytype) Init(@TypeOf(int)) {
            const other = from(int);
            const Other = From(@TypeOf(int));

            if (comptime Other.range.upper < Self.range.lower)
                return error.OutOfBoundsInteger;

            if (comptime Self.range.upper < Other.range.lower)
                return error.OutOfBoundsInteger;

            if (comptime (Self.range.lower <= Other.range.lower and Other.range.upper <= Self.range.upper))
                return @enumFromInt(int);

            if (other.asInt() < Self.range.lower)
                return error.OutOfBoundsInteger;

            if (Self.range.upper < other.asInt())
                return error.OutOfBoundsInteger;

            return @enumFromInt(int);
        }

        pub fn add(s: Self, other: anytype) Add(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return @enumFromInt(unique_self + unique_other);

            const Result = Self.Add(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .init(s) catch comptime unreachable;
            const other_wide: Wide = .init(other) catch comptime unreachable;
            return @enumFromInt(self_wide.asInt() + other_wide.asInt());
        }

        pub fn sub(s: Self, other: anytype) Sub(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return @enumFromInt(unique_self - unique_other);

            const Result = Self.Sub(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .init(s) catch comptime unreachable;
            const other_wide: Wide = .init(other) catch comptime unreachable;
            return @enumFromInt(self_wide.asInt() - other_wide.asInt());
        }

        pub fn neg(s: Self) Neg {
            return fromComptime(0).sub(s);
        }

        pub fn mul(s: Self, other: anytype) Mul(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return @enumFromInt(unique_self * unique_other);

            const Result = Self.Mul(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .init(s) catch comptime unreachable;
            const other_wide: Wide = .insit(other) catch comptime unreachable;

            return @enumFromInt(self_wide.asInt() * other_wide.asInt());
        }

        pub fn divFloor(s: Self, other: anytype) DivFloor(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            const Wide = Self.Union(Other).Union(Self.DivFloor(Other));

            if (comptime Self.unique_int) |unique_self| {
                if (comptime Other.unique_int) |unique_other| {
                    if (unique_other == 0)
                        return error.DivisionByZero;
                    return @enumFromInt(@divFloor(unique_self, unique_other));
                }
            }

            const other_wide: Wide = .init(other) catch comptime unreachable;
            const self_wide: Wide = .init(s) catch comptime unreachable;

            if (comptime Self.unique_int) |unique_self| {
                if (other_wide.ord(0) == .eq)
                    return error.DivisionByZero;

                return @divFloor(unique_self, other_wide.asInt());
            }

            if (comptime Other.unique_int) |unique_other| {
                if (unique_other == 0)
                    return error.DivisionByZero;

                return @divFloor(self_wide.asInt(), unique_other);
            }

            if (other_wide.ord(0) == .eq)
                return error.DivisionByZero;

            return @enumFromInt(@divFloor(
                self_wide.asInt(),
                other_wide.asInt(),
            ));
        }

        pub fn divTrunc(s: Self, other: anytype) DivFloor(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            const Wide = Self.Union(Other).Union(Self.DivTrunc(Other));

            if (comptime Self.unique_int) |unique_self| {
                if (comptime Other.unique_int) |unique_other| {
                    if (unique_other == 0)
                        return error.DivisionByZero;
                    return @enumFromInt(@divTrunc(
                        unique_self,
                        unique_other,
                    ));
                }
            }

            const other_wide: Wide = .init(other) catch comptime unreachable;
            const self_wide: Wide = .init(s) catch comptime unreachable;

            if (comptime Self.unique_int) |unique_self| {
                if (other_wide.ord(0) == .eq)
                    return error.DivisionByZero;

                return @enumFromInt(@divTrunc(
                    unique_self,
                    other_wide.asInt(),
                ));
            }

            if (comptime Other.unique_int) |unique_other| {
                if (unique_other == 0)
                    return error.DivisionByZero;

                return @enumFromInt(@divTrunc(
                    self_wide.asInt(),
                    unique_other,
                ));
            }

            if (other_wide.ord(0) == .eq)
                return error.DivisionByZero;

            return @enumFromInt(@divTrunc(
                self_wide.asInt(),
                other_wide.asInt(),
            ));
        }

        pub fn min(s: Self, other: anytype) Min(@TypeOf(other)) {
            const o = from(other);
            const Other = From(@TypeOf(other));
            return switch (s.ord(other)) {
                .lt => if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.asInt()),
                .gt => if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(o.asInt()),
                .eq => if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.asInt()),
            };
        }

        pub fn max(s: Self, other: anytype) Max(@TypeOf(other)) {
            const o = from(other);
            const Other = From(@TypeOf(other));
            return switch (s.ord(other)) {
                .lt => if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(o.asInt()),
                .gt => if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.asInt()),
                .eq => if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.asInt()),
            };
        }

        pub fn abs(s: Self) Abs {
            if (comptime Self.unique_int) |uv|
                return comptime @enumFromInt(@abs(uv));

            if (comptime 0 <= Self.min_int)
                return @enumFromInt(s.asInt());

            const wide: Self.Union(Abs) = .init(s) catch comptime unreachable;

            if (comptime Self.max_int <= 0)
                return @enumFromInt(-wide.asInt());

            return @enumFromInt(@abs(wide.asInt()));
        }

        pub fn floor(s: Self, bound: anytype) Floor(@TypeOf(bound)) {
            const Other = From(@TypeOf(bound));

            if (comptime Self.max_int < Other.min_int)
                return BoundsError.OutOfBoundsInteger;

            if (comptime Other.max_int <= Self.min_int)
                return @enumFromInt(s.asInt());

            const b = from(bound);

            if (s.asInt() < b.asInt())
                return BoundsError.OutOfBoundsInteger;

            return @enumFromInt(s.asInt());
        }

        pub fn ceil(s: Self, bound: anytype) Ceil(@TypeOf(bound)) {
            const Other = From(@TypeOf(bound));

            if (comptime Other.max_int < Self.min_int)
                return BoundsError.OutOfBoundsInteger;

            if (comptime Self.max_int <= Other.min_int)
                return @enumFromInt(s.asInt());

            const b = from(bound);

            if (b.asInt() < s.asInt())
                return BoundsError.OutOfBoundsInteger;

            return @enumFromInt(s.asInt());
        }

        pub fn closest(int: anytype) Closest(@TypeOf(int)) {
            const i = from(int);
            const Int = @TypeOf(i);

            if (comptime Self.unique_int) |unique_self|
                return @enumFromInt(unique_self);

            if (comptime Int.max_int < Self.min_int)
                return @enumFromInt(Self.min_int);

            if (comptime Self.max_int < Int.min_int)
                return @enumFromInt(Self.max_int);

            if (comptime Int.unique_int) |unique_other| {
                if (comptime unique_other <= Self.min_int)
                    return @enumFromInt(Self.min_int);

                if (comptime Self.max_int <= unique_other)
                    return @enumFromInt(Self.max_int);

                return @enumFromInt(unique_other);
            }

            if (i.asInt() <= Self.min_int)
                return @enumFromInt(Self.min_int);

            if (Self.max_int <= i.asInt())
                return @enumFromInt(Self.max_int);

            return @enumFromInt(i.asInt());
        }

        pub fn furthest(int: anytype) Furthest(From(@TypeOf(int))) {
            const i = from(int);
            const Int = @TypeOf(i);

            if (comptime Self.unique_int) |_|
                return .equid;

            if (comptime Int.max_int < Self.min_int)
                return .upper;

            if (comptime Self.max_int < Int.min_int)
                return .lower;

            if (comptime Self.mid_int * 2 == Self.max_int + Self.min_int)
                if (i.asInt() == Self.mid_int)
                    return .equal;

            if (i.asInt() <= Self.mid_int)
                return .upper;

            return .lower;
        }

        pub fn ord(s: Self, other: anytype) std.math.Order {
            const o = switch (@TypeOf(other)) {
                comptime_int => fromComptime(other),
                else => from(other),
            };

            const Other = @TypeOf(o);

            if (comptime Other.max_int < Self.min_int)
                return .gt;

            if (comptime Self.max_int < Other.min_int)
                return .lt;

            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return comptime std.math.order(unique_self, unique_other);

            // TODO: use `@branchHint` for runtime operations
            if (comptime Self.unique_int) |unique_self|
                return std.math.order(unique_self, o.asInt());

            if (comptime Other.unique_int) |unique_other|
                return std.math.order(s.asInt(), unique_other);

            return std.math.order(s.asInt(), o.asInt());
        }

        pub fn expect(s: Self) BoundsError!void {
            if (s.asInt() < min_int or max_int < s.asInt())
                return BoundsError.OutOfBoundsInteger;
        }

        pub fn asInt(s: Self) Backing {
            return @intFromEnum(s);
        }
    };
}

inline fn compileError(comptime fmt: []const u8, comptime args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}
