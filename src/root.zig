const std = @import("std");

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
            T.min_value
        else
            std.math.minInt(T),
        if (isBint(T))
            T.max_value
        else
            std.math.maxInt(T),
    );
}

/// This function checks whether the `T` parameter has been returned specifically by `Bint`.
pub fn isBint(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        else => false,
        .@"enum" => @hasDecl(T, "max_value") and
            @hasDecl(T, "min_value") and
            @TypeOf(T.max_value) == comptime_int and
            @TypeOf(T.min_value) == comptime_int and
            T.min_value <= T.max_value and
            T == Bint(T.min_value, T.max_value),
    };
}

pub fn Bint(comptime minimum: comptime_int, comptime maximum: comptime_int) type {
    @setEvalBranchQuota(100_000);
    std.debug.assert(minimum <= maximum);
    std.debug.assert(maximum - minimum <= std.math.maxInt(MaxInt));
    return enum(Backing) {
        _,

        const Self = @This();

        pub const min_bint: Self = @enumFromInt(min_value);
        pub const mid_bint: Self = @enumFromInt(mid_value);
        pub const max_bint: Self = @enumFromInt(max_value);

        pub const min_value = minimum;
        pub const max_value = maximum;
        pub const mid_value = (max_value + min_value) / 2;

        pub const unique_value: ?comptime_int = if (max_value == min_value) mid_value else null;

        pub const Backing = std.math.IntFittingRange(min_value, max_value);
        pub const Error = error{
            /// An attempt to make/use a bounded integer outside of its defined bounds.
            OutOfBoundsInteger,
        };

        /// This is the smallest bounded type that represent all additions of a `Self` and `T`
        /// instance.
        ///
        /// See demo/add
        pub fn Add(comptime T: type) type {
            const Other = From(T);

            return Bint(
                Self.min_value + Other.min_value,
                Self.max_value + Other.max_value,
            );
        }

        pub fn Sub(comptime T: type) type {
            const Other = From(T);
            return Bint(
                Self.min_value - Other.max_value,
                Self.max_value - Other.min_value,
            );
        }

        pub const Neg = Bint(
            @min(-min_value, -max_value),
            @max(-min_value, -max_value),
        );

        pub fn Mul(comptime T: type) type {
            const Other = From(T);
            return Bint(
                @min(
                    Self.min_value * Other.min_value,
                    Self.min_value * Other.max_value,
                    Self.max_value * Other.min_value,
                    Self.max_value * Other.max_value,
                ),
                @max(
                    Self.min_value * Other.min_value,
                    Self.min_value * Other.max_value,
                    Self.max_value * Other.min_value,
                    Self.max_value * Other.max_value,
                ),
            );
        }

        pub fn Min(comptime T: type) type {
            const Other = From(T);
            return Bint(
                @min(Self.min_value, Other.min_value),
                @min(Self.max_value, Other.max_value),
            );
        }

        pub fn Max(comptime T: type) type {
            const Other = From(T);
            return Bint(
                @max(Self.min_value, Other.min_value),
                @max(Self.max_value, Other.max_value),
            );
        }

        pub const Abs = Bint(
            if ((min_value < 0) != (max_value < 0))
                0
            else
                @min(@abs(min_value), @abs(max_value)),
            @max(@abs(min_value), @abs(max_value)),
        );

        pub fn Dist(comptime T: type) type {
            return Self.Sub(T).Abs;
        }

        pub fn FloorPayload(comptime T: type) type {
            const Other = From(T);
            return Bint(
                if (Self.max_value < Other.min_value)
                    return noreturn
                else
                    @max(Other.min_value, Self.min_value),
                Self.max_value,
            );
        }

        pub fn FloorError(comptime T: type) type {
            const Other = From(T);
            return if (Other.max_value <= Self.min_value) error{} else Error;
        }

        pub fn Floor(comptime T: type) type {
            return FloorError(T)!FloorPayload(T);
        }

        pub fn CeilPayload(comptime T: type) type {
            const Other = From(T);
            return Bint(
                Self.min_value,
                if (Other.max_value < Self.min_value)
                    return noreturn
                else
                    @min(Other.max_value, Self.max_value),
            );
        }

        pub fn CeilError(comptime T: type) type {
            const Other = From(T);
            return if (Self.max_value <= Other.min_value) error{} else Error;
        }

        pub fn Ceil(comptime T: type) type {
            return CeilError(T)!CeilPayload(T);
        }

        pub fn Closest(comptime T: type) type {
            const Other = From(T);
            return Bint(
                @max(Self.min_value, @min(Self.max_value, Other.min_value)),
                @min(Self.max_value, @max(Self.min_value, Other.max_value)),
            );
        }

        pub fn Furthest(comptime T: type) type {
            const Other = From(T);

            const Both = if (Self.min_value != Self.max_value)
                noreturn
            else
                void;

            const None = if (Self.unique_value != null or
                Other.max_value < Self.min_value or
                Self.max_value < Other.min_value or
                Self.mid_value * 2 != Self.max_value + Self.min_value) noreturn else void;

            const Upper = if (Self.unique_value != null or Self.max_value < Other.min_value)
                noreturn
            else
                void;

            const Lower = if (Self.unique_value != null or Other.max_value < Self.min_value)
                noreturn
            else
                void;

            return union(enum) {
                none: None,
                upper: Upper,
                lower: Lower,
                both: Both,

                pub fn value(f: Furthest(T)) ?Backing {
                    return switch (f) {
                        .none => null,
                        .upper => max_value,
                        .lower => min_value,
                        .both => unique_value.?,
                    };
                }

                pub fn bint(f: Furthest(T)) ?Self {
                    return switch (f) {
                        .none => null,
                        .upper => max_bint,
                        .lower => min_bint,
                        .both => mid_bint,
                    };
                }
            };
        }

        pub fn Union(comptime T: type) type {
            const Other = From(T);
            return Bint(
                @min(Self.min_value, Other.min_value),
                @max(Self.max_value, Other.max_value),
            );
        }

        fn Div(comptime T: type) type {
            const Other = From(T);
            return enum {
                div_floor,
                div_trunc,
                div_exact,

                const Sign = enum { pos, neg };
                const Kind = enum { num, den };
                const Size = enum {
                    max,
                    min,

                    fn other(s: Size) Size {
                        return switch (s) {
                            .max => .min,
                            .min => .max,
                        };
                    }
                };

                fn getFracPart(kind: Kind, size: Size, sign: Sign) ?comptime_int {
                    const BintType = switch (kind) {
                        .num => Self,
                        .den => Other,
                    };

                    const number = switch (kind) {
                        .num => 0,
                        .den => switch (sign) {
                            .pos => 1,
                            .neg => -1,
                        },
                    };

                    const bint: BintType = switch (size) {
                        .min => .widen(BintType.closestStatic(number)),
                        .max => switch (sign) {
                            .pos => .max_bint,
                            .neg => .min_bint,
                        },
                    };

                    const clamp = switch (sign) {
                        .pos => @TypeOf(bint).floorStatic,
                        .neg => @TypeOf(bint).ceilStatic,
                    };

                    return if (clamp(bint, number)) |clamped| clamped.value() else |_| null;
                }

                fn getNumOnDen(d: Div(T), frac_size: Size, num_sign: Sign, den_sign: Sign) ?comptime_int {
                    const num = getFracPart(.num, frac_size, num_sign) orelse return null;
                    const den = getFracPart(.den, frac_size.other(), den_sign) orelse return null;
                    return switch (d) {
                        .div_floor => @divFloor(num, den),
                        .div_trunc => @divTrunc(num, den),
                        .div_exact => @compileError("Not implemented!"),
                    };
                }

                fn getFrac(d: Div(T), size: Size, sign: Sign) ?comptime_int {
                    const opt_pos_sign = d.getNumOnDen(size, .pos, sign);
                    const opt_neg_sign = d.getNumOnDen(size, .neg, sign);

                    const opt_sign_pos = d.getNumOnDen(size, sign, .pos);
                    const opt_sign_neg = d.getNumOnDen(size, sign, .neg);

                    const ops =
                        if (opt_pos_sign) |ops|
                            ops
                        else if (opt_sign_pos) |osp|
                            osp
                        else
                            return opt_neg_sign;

                    const ons = if (opt_neg_sign) |ons|
                        ons
                    else if (opt_sign_neg) |osn|
                        osn
                    else
                        return opt_pos_sign;

                    const osp = if (opt_sign_pos) |osp| osp else ops;
                    const osn = if (opt_sign_neg) |osn| osn else ons;

                    return switch (size) {
                        .max => switch (sign) {
                            .pos => @max(ops, ons, osp, osn),
                            .neg => @min(ops, ons, osp, osn),
                        },
                        .min => switch (sign) {
                            .pos => @min(ops, ons, osp, osn),
                            .neg => @max(ops, ons, osp, osn),
                        },
                    };
                }

                fn Payload(d: Div(T)) type {
                    const max_frac =
                        // let's take the most positive fraction out there
                        if (d.getFrac(.max, .pos)) |pos_frac|
                            pos_frac
                            // if there are none, the least negative
                        else if (d.getFrac(.min, .neg)) |neg_frac|
                            neg_frac
                        else // else there's no fraction at all.
                            return noreturn; // This makes me laugh

                    const min_frac =
                        // let's take the most negative fraction out there
                        if (d.getFrac(.max, .neg)) |neg_frac|
                            neg_frac
                            // else the least positive
                        else if (d.getFrac(.min, .pos)) |pos_frac|
                            pos_frac
                        else // else there's no fraction at all.
                            return noreturn; // lol

                    return Bint(min_frac, max_frac);
                }

                const Error =
                    if (Other.min_value <= 0 and 0 <= Other.max_value) error{DivisionByZero} else error{};
            };
        }

        pub fn DivFloor(comptime T: type) type {
            return Div(T).Error!Div(T).div_floor.Payload();
        }

        pub fn DivTrunc(comptime T: type) type {
            return Div(T).Error!Div(T).div_trunc.Payload();
        }

        pub fn DivExact(comptime T: type) type {
            return Div(T).Error!Div(T).div_exact.Payload();
        }

        pub const InvFloor = FromComptime(1).DivFloor(Self);
        pub const InvTrunc = FromComptime(1).DivTrunc(Self);
        pub const InvExact = FromComptime(1).DivExact(Self);

        /// This type only stores the necessary bits for representing the range of legal `Self`
        /// values.
        pub const Packed = enum(std.math.IntFittingRange(0, max_value - min_value)) {
            _,

            const Tag = std.math.IntFittingRange(0, max_value - min_value);
            const Wide = std.math.IntFittingRange(
                @min(0, min_value),
                @max(max_value - min_value, max_value),
            );

            pub fn unpack(pint: Packed) Bint(min_value, max_value) {
                return @enumFromInt(@as(Wide, @intFromEnum(pint)) + min_value);
            }
        };

        /// This function turns a `Bint(...)` into a compact form. This could be useful for storing
        /// them efficiently.
        pub fn pack(s: Self) Packed {
            return @enumFromInt(@as(Packed.Wide, s.value()) - min_value);
        }

        /// This function returns the addition of `other` and `s`.
        ///
        /// ```
        /// add(x, y) = x + y
        /// ```
        pub fn add(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `addStatic`.
            other: anytype,
        ) Add(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_value) |unique_self|
                if (comptime Other.unique_value) |unique_other|
                    return @enumFromInt(unique_self + unique_other);

            const Result = Self.Add(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .widen(s);
            const other_wide: Wide = .widen(other);
            return @enumFromInt(self_wide.value() + other_wide.value());
        }
        pub fn addStatic(s: Self, comptime other: comptime_int) Add(FromComptime(other)) {
            return s.add(fromComptime(other));
        }

        test add {
            const pos_one = fromComptime(1);
            const neg_one = fromComptime(-1);

            const zero = pos_one.add(neg_one);
            try std.testing.expectEqual(0, zero.value());

            const two = pos_one.add(pos_one);
            try std.testing.expectEqual(2, two.value());

            const four = two.add(two);
            try std.testing.expectEqual(4, four.value());

            const six = four.add(two);
            try std.testing.expectEqual(6, six.value());

            const five = neg_one.add(six);
            try std.testing.expectEqual(5, five.value());

            try std.testing.expectEqual(five, four.add(pos_one));
        }

        /// This function returns the substraction of `other` from `s`.
        ///
        /// ```
        /// sub(x, y) = x - y
        /// ```
        pub fn sub(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `subStatic`.
            other: anytype,
        ) Sub(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_value) |unique_self|
                if (comptime Other.unique_value) |unique_other|
                    return @enumFromInt(unique_self - unique_other);

            const Result = Self.Sub(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .widen(s);
            const other_wide: Wide = .widen(other);
            return @enumFromInt(self_wide.value() - other_wide.value());
        }
        /// See `sub`. This function returns the substraction of `other` from `s`.
        pub fn subStatic(s: Self, comptime other: comptime_int) Sub(FromComptime(other)) {
            return s.sub(fromComptime(other));
        }

        test sub {
            const ThreeToFive = Bint(3, 5);
            const OneToTwo = Bint(1, 2);

            const four = ThreeToFive.widen(4);
            const one = OneToTwo.widen(1);

            const three = four.sub(one);

            try std.testing.expectEqual(3, three.value());
        }

        /// This function returns the opposite of `s`.
        ///
        /// ```
        /// neg(x) = -x
        /// ```
        pub fn neg(s: Self) Neg {
            return fromComptime(0).sub(s);
        }

        test neg {
            const pos_six = fromComptime(6);
            const neg_six = fromComptime(-6);

            try std.testing.expectEqual(pos_six, neg_six.neg());
            try std.testing.expectEqual(neg_six, pos_six.neg());
        }

        /// This function returns the product of `s` with `other`.
        ///
        /// ```
        /// mul(x, y) = x * y
        /// ```
        pub fn mul(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `mulStatic`.
            other: anytype,
        ) Mul(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_value) |unique_self|
                if (comptime Other.unique_value) |unique_other|
                    return @enumFromInt(unique_self * unique_other);

            const Result = Self.Mul(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .widen(s);
            const other_wide: Wide = .widen(other);

            return @enumFromInt(self_wide.value() * other_wide.value());
        }
        /// See `mul`. This function returns the product of `s` with `other`.
        pub fn mulStatic(s: Self, comptime other: comptime_int) Mul(FromComptime(other)) {
            return s.mul(fromComptime(other));
        }

        test mul {
            const two = fromComptime(2);
            const three = fromComptime(3);
            const four = fromComptime(4);

            const six = two.mul(three);
            const six_again = three.mul(two);

            const eight = two.mul(four);
            const eight_again = four.mul(two);

            const twelve = three.mul(four);
            const twelve_again = four.mul(three);

            try std.testing.expectEqual(6, six.value());
            try std.testing.expectEqual(six, six_again);

            try std.testing.expectEqual(8, eight.value());
            try std.testing.expectEqual(eight, eight_again);

            try std.testing.expectEqual(12, twelve.value());
            try std.testing.expectEqual(twelve, twelve_again);
        }

        /// This function returned the floored division of `s` by `other`. It's floored towards
        /// negative infinity.
        ///
        /// ```
        /// (divFloor(x, y) = d) ⟷ (∃r in [0..|y|[ : x * y = d + r)
        /// ```
        pub fn divFloor(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `divFloorStatic`.
            other: anytype,
        ) DivFloor(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            const Wide = Self.Union(Other).Union(Div(Other).div_floor.Payload());

            if (comptime Self.unique_value) |unique_self| {
                if (comptime Other.unique_value) |unique_other| {
                    if (unique_other == 0)
                        return error.DivisionByZero;
                    return @enumFromInt(@divFloor(unique_self, unique_other));
                }
            }

            const other_wide: Wide = .widen(other);
            const self_wide: Wide = .widen(s);

            if (comptime Self.unique_value) |unique_self| {
                if (other_wide.isEqual(0))
                    return error.DivisionByZero;

                return @divFloor(unique_self, other_wide.value());
            }

            if (comptime Other.unique_value) |unique_other| {
                if (unique_other == 0)
                    return error.DivisionByZero;

                return @divFloor(self_wide.value(), unique_other);
            }

            if (other_wide.isEqual(0))
                return error.DivisionByZero;
            return @enumFromInt(@divFloor(self_wide.value(), other_wide.value()));
        }
        /// This function returne the floored division of `s` by `other`. It's floored towards
        /// negative infinity.
        pub fn divFloorStatic(s: Self, comptime other: comptime_int) DivFloor(FromComptime(other)) {
            return s.divFloor(fromComptime(other));
        }
        /// This function return the floored division of `1` by `s`. It's floored towards negative
        /// infinity.
        pub fn invFloor(s: Self) InvFloor {
            return fromComptime(1).divFloor(s);
        }

        test divFloor {
            const eight: u8 = 8;
            const ten: u8 = 10;

            const neg_five: i8 = -5;

            const zero = try from(eight).divFloor(ten);
            const one = try from(ten).divFloor(eight);
            const neg_two = try from(eight).divFloor(neg_five);
            const neg_two_again = try from(ten).divFloor(neg_five);

            try std.testing.expectEqual(0, zero.value());
            try std.testing.expectEqual(1, one.value());
            try std.testing.expectEqual(-2, neg_two.value());
            try std.testing.expectEqual(-2, neg_two_again.value());

            try std.testing.expectError(error.DivisionByZero, neg_two.divFloor(zero));
        }

        /// This function returned the floored division of `s` by `other`. It's truncated towards
        /// zero.
        ///
        /// ```
        /// (divTrunc(x, y) = d) ⟷ (∃r in ]min(1, y)..max(1, y)[ : x * y = d + r)
        /// ```
        pub fn divTrunc(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `divFloorStatic`.
            other: anytype,
        ) DivFloor(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            const Wide = Self.Union(Other).Union(Div(Other).div_floor.Payload());

            if (comptime Self.unique_value) |unique_self| {
                if (comptime Other.unique_value) |unique_other| {
                    if (unique_other == 0)
                        return error.DivisionByZero;
                    return @enumFromInt(@divTrunc(
                        unique_self,
                        unique_other,
                    ));
                }
            }

            const other_wide: Wide = .widen(other);
            const self_wide: Wide = .widen(s);

            if (comptime Self.unique_value) |unique_self| {
                if (other_wide.isEqual(0))
                    return error.DivisionByZero;

                return @enumFromInt(@divTrunc(
                    unique_self,
                    other_wide.value(),
                ));
            }

            if (comptime Other.unique_value) |unique_other| {
                if (unique_other == 0)
                    return error.DivisionByZero;

                return @enumFromInt(@divTrunc(
                    self_wide.value(),
                    unique_other,
                ));
            }

            if (other_wide.isEqual(0))
                return error.DivisionByZero;
            return @enumFromInt(@divTrunc(
                self_wide.value(),
                other_wide.value(),
            ));
        }
        /// This function returned the floored division of `s` by `other`. It's floored towards
        /// negative infinity.
        pub fn divTruncStatic(s: Self, comptime other: comptime_int) DivFloor(FromComptime(other)) {
            return s.divTrunc(fromComptime(other));
        }
        /// This function return the floored division of `1` by `s`. It's floored towards negative
        /// infinity.
        pub fn invTrunc(s: Self) InvTrunc {
            return fromComptime(1).divTrunc(s);
        }

        test divTrunc {
            const eight: u8 = 8;
            const ten: u8 = 10;

            const neg_five: i8 = -5;

            const zero = try from(eight).divTrunc(ten);
            const one = try from(ten).divTrunc(eight);
            const neg_one = try from(eight).divTrunc(neg_five);
            const neg_two = try from(ten).divTrunc(neg_five);

            try std.testing.expectEqual(0, zero.value());
            try std.testing.expectEqual(1, one.value());
            try std.testing.expectEqual(-1, neg_one.value());
            try std.testing.expectEqual(-2, neg_two.value());

            try std.testing.expectError(error.DivisionByZero, neg_one.divTrunc(zero));
        }

        /// This function selects the minimum value between `s` and `other`.
        ///
        /// ```
        /// (min(x, y) = x) ⟷ (x ≤ y)
        /// (min(x, y) = y) ⟷ (y ≤ x)
        /// ```
        pub fn min(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `minStatic`.
            other: anytype,
        ) Min(@TypeOf(other)) {
            const o = from(other);
            const Other = From(@TypeOf(other));
            return switch (s.ord(other)) {
                .lt => if (comptime Self.unique_value) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.value()),
                .gt => if (comptime Other.unique_value) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(o.value()),
                .eq => if (comptime Self.unique_value) |uv|
                    @enumFromInt(uv)
                else if (comptime Other.unique_value) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.value()),
            };
        }
        /// See `min`. This function selects the minimum value between `s` and `other`.
        pub fn minStatic(s: Self, comptime other: comptime_int) Min(FromComptime(other)) {
            return s.min(fromComptime(other));
        }

        test min {
            const Neg5Pos5 = Bint(-5, 5);

            const neg_5 = Neg5Pos5.widen(-5);
            const neg_2 = Neg5Pos5.widen(-2);
            const pos_3 = Neg5Pos5.widen(3);

            try std.testing.expectEqual(-5, neg_5.min(neg_5).value());
            try std.testing.expectEqual(-5, neg_5.min(neg_2).value());
            try std.testing.expectEqual(-5, neg_2.min(neg_5).value());
            try std.testing.expectEqual(-5, neg_5.min(pos_3).value());
            try std.testing.expectEqual(-5, pos_3.min(neg_5).value());

            try std.testing.expectEqual(-2, neg_2.min(neg_2).value());
            try std.testing.expectEqual(-2, neg_2.min(pos_3).value());

            try std.testing.expectEqual(-2, pos_3.min(neg_2).value());
            try std.testing.expectEqual(3, pos_3.min(pos_3).value());
        }

        /// This function selects the maximum value between `s` and `other`.
        ///
        /// ```
        /// (max(x, y) = x) ⟷ (y ≤ x)
        /// (max(x, y) = y) ⟷ (x ≤ y)
        /// ```
        pub fn max(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `maxStatic`.
            other: anytype,
        ) Max(@TypeOf(other)) {
            const o = from(other);
            const Other = From(@TypeOf(other));
            return switch (s.ord(other)) {
                .lt => if (comptime Other.unique_value) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(o.value()),
                .gt => if (comptime Self.unique_value) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.value()),
                .eq => if (comptime Other.unique_value) |uv|
                    @enumFromInt(uv)
                else if (comptime Self.unique_value) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.value()),
            };
        }
        /// See `max`. This function selects the maximum value between `s` and `other`.
        pub fn maxStatic(s: Self, comptime other: comptime_int) Max(FromComptime(other)) {
            return @enumFromInt(@max(s.value(), other));
        }

        test max {
            const Neg5Pos5 = Bint(-5, 5);

            const neg_5 = Neg5Pos5.widen(-5);
            const neg_2 = Neg5Pos5.widen(-2);
            const pos_3 = Neg5Pos5.widen(3);

            try std.testing.expectEqual(-5, neg_5.max(neg_5).value());
            try std.testing.expectEqual(-2, neg_5.max(neg_2).value());

            try std.testing.expectEqual(-2, neg_2.max(neg_5).value());
            try std.testing.expectEqual(-2, neg_2.max(neg_2).value());

            try std.testing.expectEqual(3, neg_5.max(pos_3).value());
            try std.testing.expectEqual(3, pos_3.max(neg_5).value());
            try std.testing.expectEqual(3, neg_2.max(pos_3).value());
            try std.testing.expectEqual(3, pos_3.max(neg_2).value());
            try std.testing.expectEqual(3, pos_3.max(pos_3).value());
        }

        /// This function returns the asbolute value of `s`.
        ///
        /// ```
        /// abs(x) = |x|
        /// ```
        pub fn abs(s: Self) Abs {
            if (comptime Self.unique_value) |uv|
                return comptime @enumFromInt(@abs(uv));

            if (comptime 0 <= Self.min_value)
                return @enumFromInt(s.value());

            const wide: Self.Union(Abs) = .widen(s);

            if (comptime Self.max_value <= 0)
                return @enumFromInt(-wide.value());

            return @enumFromInt(@abs(wide.value()));
        }

        test abs {
            // It works when it's always negative.
            const Negative = Bint(-10, -5);

            const neg_seven = Negative.widen(-7);
            const abs_neg_seven = neg_seven.abs();
            try std.testing.expectEqual(7, abs_neg_seven.value());

            // It works when it's mixed.
            const IByte = From(i8);

            const pos_ten = IByte.widen(10);
            const abs_pos_ten = pos_ten.abs();
            try std.testing.expectEqual(10, abs_pos_ten.value());

            // It also works when using the smaller of a signed integer type.
            const neg_128 = IByte.min_bint;
            const abs_neg_128 = neg_128.abs();
            try std.testing.expectEqual(128, abs_neg_128.value());

            // And it obviously work when it's always positive.
            const Positive = Bint(42, 69);

            const fifty = Positive.widen(50);
            const abs_fifty = fifty.abs();
            try std.testing.expectEqual(50, abs_fifty.value());
        }

        /// This function returns a `Bint(...)` whose value is the same as `s`, with eventually a
        /// bigger lower bound, or an `Error.OutOfBoundsInteger` when the value of `s` is smaller
        /// than that of `bound`.
        ///
        /// If the `bound` parameter is necessarily smaller than `s`, then the error set of the
        /// return type is empty. Similarily, if the `bound` parameter is necessarily bigger than
        /// `s`, the payload of the return type is `noreturn`.
        ///
        /// Typical flooring functions will return the bound instead of an error when the main
        /// parameter smaller. For this kind of behaviour use `s.floor(bound) catch bound` or similar.
        ///
        /// ```
        /// (floor(x, y) = error) ⟷ (x < y)
        /// (floor(x, y) = x)     ⟷ (y ≤ x)
        /// ```
        pub fn floor(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `floorStatic`.
            bound: anytype,
        ) Floor(@TypeOf(bound)) {
            const Other = From(@TypeOf(bound));

            if (comptime Self.max_value < Other.min_value)
                return Error.OutOfBoundsInteger;

            if (comptime Other.max_value <= Self.min_value)
                return @enumFromInt(s.value());

            const b = from(bound);

            if (s.value() < b.value())
                return Error.OutOfBoundsInteger;

            return @enumFromInt(s.value());
        }
        /// See `floor`. This function returns a `Bint(...)` whose value is the same as `s`, with
        /// eventually a bigger lower bound, or an `Error.OutOfBoundsInteger` when the value `s` is
        /// smaller than that of `bound`.
        pub fn floorStatic(s: Self, comptime bound: comptime_int) Floor(FromComptime(bound)) {
            return try s.floor(fromComptime(bound));
        }

        test floor {
            const TenToTwenty = Bint(10, 20);

            // Anything above or equal to the floor won't trigger an error.
            const fourteen = TenToTwenty.widen(14);
            const fifteen = TenToTwenty.widen(15);

            const still_fifteen = try fifteen.floor(@as(u8, 14));
            const still_fourteen = try fourteen.floor(@as(u8, 14));

            try std.testing.expectEqual(fifteen, still_fifteen);
            try std.testing.expectEqual(fourteen, still_fourteen);

            // Anything below the floor will trigger an error.
            try std.testing.expectError(Error.OutOfBoundsInteger, fifteen.floor(@as(u8, 16)));

            // If the floor can't be above a value within the bounds, it'll narrow the type of the result.
            const TwelveToFifteen = Bint(12, 15);

            const fifteen_again = TenToTwenty.widen(15);
            const still_fifteen_again = try fifteen_again.floor(TwelveToFifteen.widen(13));

            try std.testing.expectEqual(fifteen_again.value(), still_fifteen_again.value());
            try std.testing.expectEqual(Bint(12, 20), @TypeOf(still_fifteen_again));

            // If the floor must be a value above the bounds, it'll narrow the result to `noreturn`.
            try std.testing.expectEqual(Error!noreturn, @TypeOf(fifteen_again.floor(fromComptime(21))));
        }

        /// This function returns a `Bint(...)` whose value is the same as `s`, with eventually a
        /// smaller upper bound, or an `Error.OutOfBoundsInteger` when the value of `s` is smaller
        /// than that of `bound`.
        ///
        /// If the `bound` parameter is necessarily bigger than `s`, then the error set of the
        /// return type is empty. Similarily, if the `bound` parameter is necessarily smaller than
        /// `s`, the payload of the return type is `noreturn`.
        ///
        /// Typical ceiling functions will return the bound instead of an error when the main
        /// parameter bigger. For the same behaviour use `s.ceil(bound) catch bound` or similar.
        ///
        /// ```
        /// (ceil(x, y) = x)     ⟷ (x ≤ y)
        /// (ceil(x, y) = error) ⟷ (y < x)
        /// ```
        pub fn ceil(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `ceilStatic`.
            bound: anytype,
        ) Ceil(@TypeOf(bound)) {
            const Other = From(@TypeOf(bound));

            if (comptime Other.max_value < Self.min_value)
                return Error.OutOfBoundsInteger;

            if (comptime Self.max_value <= Other.min_value)
                return @enumFromInt(s.value());

            const b = from(bound);

            if (b.value() < s.value())
                return Error.OutOfBoundsInteger;

            return @enumFromInt(s.value());
        }
        /// See `ceil`. This function returns a `Bint(...)` whose value is the same as `s`, with
        /// eventually a smaller upper bound, or an `Error.OutOfBoundsInteger` when the value of
        /// `s` is smaller than that of `bound`.
        pub fn ceilStatic(s: Self, comptime bound: comptime_int) Ceil(FromComptime(bound)) {
            return try s.ceil(fromComptime(bound));
        }

        test ceil {
            const TenToTwenty = Bint(10, 20);

            // Anything below or equal to the ceil won't trigger an error.
            const fourteen = TenToTwenty.widen(14);
            const fifteen = TenToTwenty.widen(15);

            const still_fifteen = try fifteen.ceil(@as(u8, 15));
            const still_fourteen = try fourteen.ceil(@as(u8, 15));

            try std.testing.expectEqual(fifteen, still_fifteen);
            try std.testing.expectEqual(fourteen, still_fourteen);

            // Anything above the ceil will trigger an error.
            try std.testing.expectError(Error.OutOfBoundsInteger, fifteen.ceil(@as(u8, 14)));

            // If the ceil can't be above a value within the bounds, it'll narrow the type of the result.
            const TwelveToFifteen = Bint(12, 15);

            const thirteen = TenToTwenty.widen(13);
            const still_thirteen = try thirteen.ceil(TwelveToFifteen.widen(14));

            try std.testing.expectEqual(thirteen.value(), still_thirteen.value());
            try std.testing.expectEqual(Bint(10, 15), @TypeOf(still_thirteen));

            // If the ceil must be a value below the bounds, it'll narrow the result to `noreturn`.
            try std.testing.expectEqual(Error!noreturn, @TypeOf(thirteen.ceil(fromComptime(9))));
        }

        /// This function returns the linear distance between `s` and `other`.
        ///
        /// ```
        /// distance(x, y) = |x - y|
        /// ```
        pub fn distance(
            s: Self,
            /// The type of this parameter can be:
            /// - an integer,
            /// - a `Bint(...)`.
            ///
            /// For a `comptime_int`, see `distanceStatic`.
            other: anytype,
        ) Dist(@TypeOf(other)) {
            return s.sub(other).abs();
        }
        /// See `distance`. This function returns the linear distance between `s` and `other`.
        pub fn distanceStatic(s: Self, comptime other: comptime_int) Dist(FromComptime(other)) {
            return s.subStatic(other).abs();
        }

        test distance {
            const Neg10ToPos12 = Bint(-10, 12);

            const neg10 = Neg10ToPos12.widen(-10);
            const zero = Neg10ToPos12.widen(0);
            const pos5 = Neg10ToPos12.widen(5);
            const pos12 = Neg10ToPos12.widen(12);

            // The distance with itself is always zero.
            try std.testing.expectEqual(0, neg10.distance(neg10).value());
            try std.testing.expectEqual(0, zero.distance(zero).value());
            try std.testing.expectEqual(0, pos5.distance(pos5).value());
            try std.testing.expectEqual(0, pos12.distance(pos12).value());

            // The distance between two numbers is the same no matter the order.
            try std.testing.expectEqual(10, neg10.distance(zero).value());
            try std.testing.expectEqual(10, zero.distance(neg10).value());

            try std.testing.expectEqual(15, neg10.distance(pos5).value());
            try std.testing.expectEqual(22, neg10.distance(pos12).value());
            try std.testing.expectEqual(5, zero.distance(pos5).value());
            try std.testing.expectEqual(12, zero.distance(pos12).value());
            try std.testing.expectEqual(7, pos5.distance(pos12).value());
        }

        /// This function looks for the closest bounded integer from the given `int`, which is
        /// always one of the bounds.
        ///
        /// This function will return the upper bound of `Self` if the `int` parameter is bigger.
        /// And similarily, it will return the lower bound of `Self` if the `int` parameter is
        /// smaller. Otherwise, it will return the same value as the `int` parameter.
        ///
        /// The return type is ceiled by the upper bound of either `int` or `Self`, whichever is
        /// the smallest. It's also and floored by the lower bound of either `int` or `Self`,
        /// whichever is the biggest.
        ///
        /// The result can always be passed to `widen`.
        ///
        /// ```
        /// closest(x) = y ∈ Closest ⊆ Self
        ///     ⟷
        /// ∀z ∈ Self : |x - y| ≤ |x - z|
        /// ```
        pub fn closest(
            /// Thhis parameter can be:
            /// - an integer,
            /// - a bint,
            ///
            /// For a `comptime_int`, see `closestStatic`.
            int: anytype,
        ) Closest(@TypeOf(int)) {
            const i = from(int);
            const Int = @TypeOf(i);

            if (comptime Self.unique_value) |unique_self|
                return @enumFromInt(unique_self);

            if (comptime Int.max_value < Self.min_value)
                return @enumFromInt(Self.min_value);

            if (comptime Self.max_value < Int.min_value)
                return @enumFromInt(Self.max_value);

            if (comptime Int.unique_value) |unique_other| {
                if (comptime unique_other <= Self.min_value)
                    return @enumFromInt(Self.min_value);

                if (comptime Self.max_value <= unique_other)
                    return @enumFromInt(Self.max_value);

                return @enumFromInt(unique_other);
            }

            if (i.value() <= Self.min_value)
                return @enumFromInt(Self.min_value);

            if (Self.max_value <= i.value())
                return @enumFromInt(Self.max_value);

            return @enumFromInt(i.value());
        }

        /// See `closest`. This function looks for the closest bounded integer from the given `int`.
        pub fn closestStatic(comptime int: comptime_int) Closest(FromComptime(int)) {
            return comptime closest(fromComptime(int));
        }

        test closest {
            const TenToTwelve = Bint(10, 12);

            const closest_to_nine = TenToTwelve.closest(@as(u8, 9));
            const closest_to_ten = TenToTwelve.closest(@as(u8, 10));
            const closest_to_eleven = TenToTwelve.closest(@as(u8, 11));
            const closest_to_twelve = TenToTwelve.closest(@as(u8, 12));
            const closest_to_thirteen = TenToTwelve.closest(@as(u8, 13));

            // Whatever is below the lower bound is closest to said bound.
            try std.testing.expectEqual(10, closest_to_nine.value());

            // Whatever is within the bounds is closest to itself.
            try std.testing.expectEqual(10, closest_to_ten.value());
            try std.testing.expectEqual(11, closest_to_eleven.value());
            try std.testing.expectEqual(12, closest_to_twelve.value());

            // Whatever is above the upper bound is closest to said bound.
            try std.testing.expectEqual(12, closest_to_thirteen.value());

            // It's always possible to call `widen` on the result.
            _ = TenToTwelve.widen(closest_to_nine);
        }

        /// This function looks for the furthest bounded integer from the given `int`, which is
        /// always one of the bounds.
        ///
        /// The `int` parameter can be an integer or a `Bint(...)`. For a `comptime_int`, see
        /// `furthestStatic`.
        ///
        /// This function returns:
        /// - `.upper` if the upper bound is further from `int` than the lower bound,
        /// - `.lower` if the lower bound is further from `int` than the upper bound,
        /// - `.both` if the upper and lower bound are equals,
        /// - `.none` if the upper and lower bound aren't equal but are equally far from `int`.
        ///
        /// If, given the type of `int` one of those variant is known unreachable, its payload type
        /// is `noreturn`. Else it's a `Bint(...)` with a unique value.
        ///
        /// ```
        /// furthest(x) = y
        ///     ⟷
        /// ∀z : |x - z| < |x - y|
        /// ```
        ///
        pub fn furthest(int: anytype) Furthest(From(@TypeOf(int))) {
            const i = from(int);
            const Int = @TypeOf(i);

            if (comptime Self.unique_value) |_|
                return .both;

            if (comptime Int.max_value < Self.min_value)
                return .upper;

            if (comptime Self.max_value < Int.min_value)
                return .lower;

            if (comptime Self.mid_value * 2 == Self.max_value + Self.min_value)
                if (i.value() == Self.mid_value)
                    return .none;

            if (i.value() <= Self.mid_value)
                return .upper;

            return .lower;
        }

        /// See `furthest`. This function looks for the furthest bounded integer from the given
        /// `int`, which is always one of the bounds.
        pub fn furthestStatic(comptime int: comptime_int) Furthest(FromComptime(int)) {
            return comptime furthest(fromComptime(int));
        }

        test furthest {
            // When the difference between the upper and lower bounds is pair, it can return `.none`.
            const TenToEighteen = Bint(10, 18);

            try std.testing.expectEqual(.upper, TenToEighteen.furthest(@as(u8, 13)));
            try std.testing.expectEqual(.none, TenToEighteen.furthest(@as(u8, 14)));
            try std.testing.expectEqual(.lower, TenToEighteen.furthest(@as(u8, 15)));

            // When the difference between the upper and lower bounds is odd, it can't.
            const ElevenToSixteen = Bint(11, 16);

            try std.testing.expectEqual(.upper, ElevenToSixteen.furthest(@as(u8, 13)));
            try std.testing.expectEqual(.lower, ElevenToSixteen.furthest(@as(u8, 14)));

            // When the difference between the upper and lower bounds is zero, it always returns `.both`.
            const OnlyTwelve = Bint(12, 12);

            try std.testing.expectEqual(.both, OnlyTwelve.furthest(@as(u8, 11)));
            try std.testing.expectEqual(.both, OnlyTwelve.furthest(@as(u8, 12)));
            try std.testing.expectEqual(.both, OnlyTwelve.furthest(@as(u8, 13)));
        }

        /// This function compares whether the `s` parameter is
        /// - strictly greater than (`.gt`),
        /// - strictly less than (`.lt`),
        /// - equal to (`.eq`) the `to` parameter.
        ///
        /// For convenience functions see `isEqual`, `isMore` and `isLess`.
        ///
        /// ```
        /// (ord(x, y) = .lt) ⟷ (x < y)
        /// (ord(x, y) = .eq) ⟷ (x = y)
        /// (ord(x, y) = .gt) ⟷ (x > y)
        /// ```
        pub fn ord(
            s: Self,
            /// This parameter can be:
            /// - an integer,
            /// - a `comptime_int`,
            /// - a `Bint(...)`.
            other: anytype,
        ) std.math.Order {
            const o = switch (@TypeOf(other)) {
                comptime_int => fromComptime(other),
                else => from(other),
            };

            const Other = @TypeOf(o);

            if (comptime Other.max_value < Self.min_value)
                return .gt;

            if (comptime Self.max_value < Other.min_value)
                return .lt;

            if (comptime Self.unique_value) |unique_self|
                if (comptime Other.unique_value) |unique_other|
                    return comptime std.math.order(unique_self, unique_other);

            // TODO: use `@branchHint` for runtime operations
            if (comptime Self.unique_value) |unique_self|
                return std.math.order(unique_self, o.value());

            if (comptime Other.unique_value) |unique_other|
                return std.math.order(s.value(), unique_other);

            return std.math.order(s.value(), o.value());
        }

        test ord {
            const Ubyte = Bint(0x00, 0xFF);
            const Ibyte = Bint(-0x80, 0x7F);

            const one = try Ubyte.init(1);

            // We can use `cmp` with a `comptime_int`.
            try std.testing.expectEqual(.gt, one.ord(0));
            try std.testing.expectEqual(.eq, one.ord(1));
            try std.testing.expectEqual(.lt, one.ord(2));

            // Or an integer.
            try std.testing.expectEqual(.gt, one.ord(@as(c_int, 0)));
            try std.testing.expectEqual(.eq, one.ord(@as(i1024, 1)));
            try std.testing.expectEqual(.lt, one.ord(@as(usize, 2)));

            // Or another `Bint(...)`.
            try std.testing.expectEqual(.gt, one.ord(try Ibyte.init(-1)));
            try std.testing.expectEqual(.eq, one.ord(try Ibyte.init(1)));
            try std.testing.expectEqual(.lt, one.ord(try Ibyte.init(10)));
        }

        /// See `ord`. This function compares the `s` parameter with the `to` parameter. And
        /// returns `true` when they're equal.
        ///
        /// ```
        /// isEqual(x, y) ⟷ x = y
        /// ```
        pub fn isEqual(
            s: Self,
            /// This parameter can be:
            /// - an integer,
            /// - a `comptime_int`,
            /// - a `Bint(...)`.
            to: anytype,
        ) bool {
            return s.ord(to) == .eq;
        }

        /// See `ord`. This function compares the `s` parameter with the `than` parameter. And
        /// returns `true` when `s` is strictly greater than `than`.
        ///
        /// ```
        /// isMore(x, y) ⟷ y < x
        /// ```
        pub fn isMore(
            s: Self,
            /// This parameter can be:
            /// - an integer,
            /// - a `comptime_int`,
            /// - a `Bint(...)`.
            than: anytype,
        ) bool {
            return s.ord(than) == .gt;
        }

        /// See `ord`. This function compares the `s` parameter with the `than` parameter. And
        /// returns `true` when `s` is strictly smaller than `than`.
        ///
        /// ```
        /// isLess(x, y) ⟷ x < y
        /// ```
        pub fn isLess(
            s: Self,
            /// This parameter can be:
            /// - an integer,
            /// - a `comptime_int`,
            /// - a `Bint(...)`.
            than: anytype,
        ) bool {
            return s.ord(than) == .lt;
        }

        /// This function checks the validity of the bint its given. An invalid bint violates the
        /// invariant `min_value <= bint <= max_value`.
        ///
        /// A bint that violate the invariant can only be ever be found after an unsafe cast, or
        /// as an undefined variable. This can happen with:
        ///
        /// 1. an unsound use of `@enumFromInt`, `@bitCast` or `@ptrCast`,
        /// 2. the use of `undefined` without setting the bint before its use,
        /// 3. allocating the bint without setting the bint before its use (equivalent to 2.),
        ///
        /// Bints initiated by other means (typically, `init` and `widen`) are expected not to
        /// return an error when passed to this function.
        pub fn expect(s: Self) Error!void {
            if (s.value() < min_value or max_value < s.value())
                return Error.OutOfBoundsInteger;
        }

        test expect {
            const TenToTwenty = Bint(10, 20);

            // It's recommended not to use `@enumFromInt`. Prefer `init` or `widen`, unless there's
            // an invariant that implies, the value is within bounds.
            const thirteen: TenToTwenty = @enumFromInt(13);
            // Otherwise, this kind of thing could happen:
            const eight: TenToTwenty = @enumFromInt(8);
            // Or this:
            const thirty: TenToTwenty = @enumFromInt(30);

            // This is passing.
            try thirteen.expect();
            // But these are failing.
            try std.testing.expectError(error.OutOfBoundsInteger, eight.expect());
            try std.testing.expectError(error.OutOfBoundsInteger, thirty.expect());
        }

        /// This function conveniently converts the `s` parameter into a `Backing` instance which
        /// is always the smallest native integer type that contains both bounds.
        pub fn value(s: Self) Backing {
            return @intFromEnum(s);
        }

        /// This function makes a `Self` instance out of the `int` parameter.
        ///
        /// If the value of the `int` parameter isn't within the bounds of `Self`, it returns an
        /// `error.OutOfBoundsInteger`.
        ///
        /// If the type of the `int` parameter forbid the representation of values outside of the
        /// bounds of `Self`, consider using `widen` instead.
        pub fn init(
            /// This parameter can be either:
            /// - a primitive integer,
            /// - a `comptime_int`,
            /// - another `Bint(...)`.
            int: anytype,
        ) Error!Self {
            const Int = @TypeOf(int);
            const Other = if (Int == comptime_int) FromComptime(int) else From(Int);
            const other: Other = if (comptime isBint(Int)) int else @enumFromInt(int);

            if (comptime Self.max_value < Other.min_value)
                return error.OutOfBoundsInteger;

            if (comptime Other.max_value < Self.min_value)
                return error.OutOfBoundsInteger;

            if (comptime Other.min_value < Self.min_value)
                if (other.value() < Self.min_value)
                    return Error.OutOfBoundsInteger;

            if (comptime Self.max_value < Other.max_value)
                if (Self.max_value < other.value())
                    return Error.OutOfBoundsInteger;

            return @enumFromInt(other.value());
        }

        test init {
            // An integer that's only valid between 10 and 20, included.
            const TenToTwenty = Bint(10, 20);

            // Before 10 it doesn't work.
            try std.testing.expectEqual(error.OutOfBoundsInteger, TenToTwenty.init(-1));
            try std.testing.expectError(error.OutOfBoundsInteger, TenToTwenty.init(9));

            // From 10 (included) it works
            const ten: TenToTwenty = try .init(10);
            const twelve: TenToTwenty = try .init(12);
            const twenty: TenToTwenty = try .init(20);

            // From 20 (not included), it doesn't work anymore
            try std.testing.expectError(error.OutOfBoundsInteger, TenToTwenty.init(21));

            // The values are those you used.
            try std.testing.expectEqual(10, ten.value());
            try std.testing.expectEqual(12, twelve.value());
            try std.testing.expectEqual(20, twenty.value());

            // One can also use an integer
            const eleven: TenToTwenty = try .init(@as(u8, 11));
            try std.testing.expectEqual(11, eleven.value());

            // Or a `Bint(...)`
            const thirteen: TenToTwenty = try .init(from(@as(u8, 13)));
            try std.testing.expectEqual(13, thirteen.value());
        }

        /// This function makes a `Self` instance out of the `int` parameter.
        ///
        /// The type of the `int` parameter must forbid the representation of values outside of the
        /// bounds of `Self`.
        ///
        ///  If the type of the `int` parameter allow the representation of values outside of the
        /// bounds of `Self`, consider using `init` instead.
        ///
        /// ```
        /// isValidParameterType(Int) ⟷ Int ⊆ Self
        /// ```
        pub fn widen(
            /// This parameter can be either:
            /// - a primitive integer,
            /// - a `comptime_int`,
            /// - another `Bint(...)`.
            int: anytype,
        ) Self {
            const Int = @TypeOf(int);
            const Other = if (Int == comptime_int) FromComptime(int) else From(@TypeOf(int));
            const other = if (Int == comptime_int) fromComptime(int) else from(int);

            if (Other.min_value < Self.min_value) compileError(
                \\In order to use `widen`, the `int` parameter must guarantee to be within the
                \\bounds of `{s}`.
                \\
                \\Here, the `int` paramater is of type `{s}`, whose lower bound is `{}`.
                \\  
            , .{ @typeName(Self), @typeName(Int), Other.min_value });

            if (Self.max_value < Other.max_value) compileError(
                \\In order to use `widen`, the `int` parameter must guarantee to be within the
                \\bounds of `{s}`.
                \\
                \\Here, the `int` paramater is of type `{s}`, whose upper bound is `{}`.
                \\  
            , .{ @typeName(Self), @typeName(Int), Other.max_value });

            return @enumFromInt(other.value());
        }

        test widen {
            const MyBint = Bint(-42, 69);

            // One can use a `comptime_int`
            const fifty: MyBint = .widen(50);
            // another `Bint`, as long as its bounds are within `MyBint` bounds
            const fourty: MyBint = .widen(Bint(-42, 42).widen(40));
            // an integer primitive, as long as it can't represent values out of bound
            const thirty: MyBint = .widen(@as(i6, 30));

            try std.testing.expectEqual(50, fifty.value());
            try std.testing.expectEqual(40, fourty.value());
            try std.testing.expectEqual(30, thirty.value());
        }
    };
}

test {
    // I'm doing this to reference the test of the functions instead of putting them directly in
    // the root, so they're included in the documentation.
    //
    // TODO: find a better method, this is expensive compile-time stuff, because it doesn't cache
    // the tests that depends on compile-time parameters apparently (?), and it recursively
    // reference all the bints, so...
    _ = Bint(0, 0);
}

inline fn compileError(comptime fmt: []const u8, comptime args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}
