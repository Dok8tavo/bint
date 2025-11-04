# ⚡ Bint

Bint is a Zig module for bounded integers —bints— defined by their minimum and maximum values.

It provides arithmetic operations safe from overflow/underflow through type-checking, and safe from division by zero and narrow-casting by type-checking when possible and by runtime regular Zig errors otherwise.
It also provides a few guaranteed optimizations (even in debug mode), like operations on "unique-values", _i.e._ bints whose minimum and maximum values are equal, are no-op even when they're operated at runtime.

## ⚙️ Operations

| name       | variants                      | implemented | documented | testing |
|------------|-------------------------------|-------------|------------|---------|
| `widen`    |                               | ✅           | ✅          | ✅       |
| `init`     |                               | ✅           | ✅          | ✅       |
| `add`      | `addStatic`                   | ✅           | ✅          | ✅       |
| `sub`      | `subStatic`                   | ✅           | ✅          | ✅       |
| `neg`      |                               | ✅           | ✅          | ✅       |
| `mul`      | `mulStatic`                   | ✅           | ✅          | ✅       |
| `divFloor` | `divFloorStatic`              | ✅           | ✅          | ✅       |
| `divTrunc` | `divTruncStatic`              | ✅           | ✅          | ✅       |
| `divExact` | `divExactStatic`              | ❎           | ❎          | ❎       |
| `abs`      |                               | ✅           | ✅          | ✅       |
| `max`      | `maxStatic`                   | ✅           | ✅          | ✅       |
| `min`      | `minStatic`                   | ✅           | ✅          | ✅       |
| `ceil`     | `ceilStatic`                  | ✅           | ✅          | ✅       |
| `floor`    | `floorStatic`                 | ✅           | ✅          | ✅       |
| `furthest` | `furthestStatic`              | ✅           | ✅          | ✅       |
| `closest`  | `closestStatic`               | ✅           | ✅          | ✅       |
| `ord`      | `isEqual`, `isMore`, `isLess` | ✅           | ✅          | ✅       |



## 📃 License

MIT License

Copyright (c) 2025 Dok8tavo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
