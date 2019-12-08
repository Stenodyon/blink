const std = @import("std");

pub fn print_matrix(mat: *[16]f32) void {
    var y: usize = 0;
    while (y < 4) : (y += 1) {
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            const index = x + y * 4;
            std.debug.warn("{}\t", mat[index]);
        }
        std.debug.warn("\n");
    }
}

pub fn multiply(dest: *[16]f32, a: *[16]f32, b: *[16]f32) void {
    var y: usize = 0;
    while (y < 4) : (y += 1) {
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            var sum: f32 = 0;
            var i: usize = 0;
            while (i < 4) : (i += 1) {
                const a_index = i + y * 4;
                const b_index = x + i * 4;
                sum += a[a_index] * b[b_index];
            }
            const index = x + y * 4;
            dest[index] = sum;
        }
    }
}

pub fn apply(matrix: *[16]f32, vec: *[4]f32) void {
    var out: [4]f32 = undefined;

    var coord: usize = 0;
    while (coord < 4) : (coord += 1) {
        var i: usize = 0;
        out[coord] = 0;
        while (i < 4) : (i += 1) {
            const index = i + coord * 4;
            out[coord] += matrix[index] * vec[i];
        }
    }

    for (out) |value, i| vec[i] = value;
}

pub fn inverse(dest: *[16]f32, src: *[16]f32) bool {
    var tmp: [16]f32 = undefined;

    tmp[0] = src[5] * src[10] * src[15] -
        src[5] * src[11] * src[14] -
        src[9] * src[6] * src[15] +
        src[9] * src[7] * src[14] +
        src[13] * src[6] * src[11] -
        src[13] * src[7] * src[10];

    tmp[4] = -src[4] * src[10] * src[15] +
        src[4] * src[11] * src[14] +
        src[8] * src[6] * src[15] -
        src[8] * src[7] * src[14] -
        src[12] * src[6] * src[11] +
        src[12] * src[7] * src[10];

    tmp[8] = src[4] * src[9] * src[15] -
        src[4] * src[11] * src[13] -
        src[8] * src[5] * src[15] +
        src[8] * src[7] * src[13] +
        src[12] * src[5] * src[11] -
        src[12] * src[7] * src[9];

    tmp[12] = -src[4] * src[9] * src[14] +
        src[4] * src[10] * src[13] +
        src[8] * src[5] * src[14] -
        src[8] * src[6] * src[13] -
        src[12] * src[5] * src[10] +
        src[12] * src[6] * src[9];

    tmp[1] = -src[1] * src[10] * src[15] +
        src[1] * src[11] * src[14] +
        src[9] * src[2] * src[15] -
        src[9] * src[3] * src[14] -
        src[13] * src[2] * src[11] +
        src[13] * src[3] * src[10];

    tmp[5] = src[0] * src[10] * src[15] -
        src[0] * src[11] * src[14] -
        src[8] * src[2] * src[15] +
        src[8] * src[3] * src[14] +
        src[12] * src[2] * src[11] -
        src[12] * src[3] * src[10];

    tmp[9] = -src[0] * src[9] * src[15] +
        src[0] * src[11] * src[13] +
        src[8] * src[1] * src[15] -
        src[8] * src[3] * src[13] -
        src[12] * src[1] * src[11] +
        src[12] * src[3] * src[9];

    tmp[13] = src[0] * src[9] * src[14] -
        src[0] * src[10] * src[13] -
        src[8] * src[1] * src[14] +
        src[8] * src[2] * src[13] +
        src[12] * src[1] * src[10] -
        src[12] * src[2] * src[9];

    tmp[2] = src[1] * src[6] * src[15] -
        src[1] * src[7] * src[14] -
        src[5] * src[2] * src[15] +
        src[5] * src[3] * src[14] +
        src[13] * src[2] * src[7] -
        src[13] * src[3] * src[6];

    tmp[6] = -src[0] * src[6] * src[15] +
        src[0] * src[7] * src[14] +
        src[4] * src[2] * src[15] -
        src[4] * src[3] * src[14] -
        src[12] * src[2] * src[7] +
        src[12] * src[3] * src[6];

    tmp[10] = src[0] * src[5] * src[15] -
        src[0] * src[7] * src[13] -
        src[4] * src[1] * src[15] +
        src[4] * src[3] * src[13] +
        src[12] * src[1] * src[7] -
        src[12] * src[3] * src[5];

    tmp[14] = -src[0] * src[5] * src[14] +
        src[0] * src[6] * src[13] +
        src[4] * src[1] * src[14] -
        src[4] * src[2] * src[13] -
        src[12] * src[1] * src[6] +
        src[12] * src[2] * src[5];

    tmp[3] = -src[1] * src[6] * src[11] +
        src[1] * src[7] * src[10] +
        src[5] * src[2] * src[11] -
        src[5] * src[3] * src[10] -
        src[9] * src[2] * src[7] +
        src[9] * src[3] * src[6];

    tmp[7] = src[0] * src[6] * src[11] -
        src[0] * src[7] * src[10] -
        src[4] * src[2] * src[11] +
        src[4] * src[3] * src[10] +
        src[8] * src[2] * src[7] -
        src[8] * src[3] * src[6];

    tmp[11] = -src[0] * src[5] * src[11] +
        src[0] * src[7] * src[9] +
        src[4] * src[1] * src[11] -
        src[4] * src[3] * src[9] -
        src[8] * src[1] * src[7] +
        src[8] * src[3] * src[5];

    tmp[15] = src[0] * src[5] * src[10] -
        src[0] * src[6] * src[9] -
        src[4] * src[1] * src[10] +
        src[4] * src[2] * src[9] +
        src[8] * src[1] * src[6] -
        src[8] * src[2] * src[5];

    var det = src[0] * tmp[0] +
        src[1] * tmp[4] +
        src[2] * tmp[8] +
        src[3] * tmp[12];

    if (det == 0)
        return false;

    det = 1.0 / det;
    for (tmp) |value, i| dest[i] = value * det;

    return true;
}

pub fn copy(dest: *[16]f32, src: *[16]f32) void {
    for (src) |value, i| dest[i] = value;
}

pub fn identity(matrix: *[16]f32) void {
    for (matrix) |*value| value.* = 0;
    matrix[0] = 1;
    matrix[5] = 1;
    matrix[10] = 1;
    matrix[15] = 1;
}

pub fn scale(matrix: *[16]f32, x: f32, y: f32, z: f32) void {
    var tmp: [16]f32 = undefined;
    identity(&tmp);
    tmp[0] *= x;
    tmp[5] *= y;
    tmp[10] *= z;

    var tmp_dest: [16]f32 = undefined;
    multiply(&tmp_dest, &tmp, matrix);
    copy(matrix, &tmp_dest);
}

pub fn translate(matrix: *[16]f32, x: f32, y: f32, z: f32) void {
    var tmp: [16]f32 = undefined;
    identity(&tmp);
    tmp[3] += x;
    tmp[7] += y;
    tmp[11] += z;

    var tmp_dest: [16]f32 = undefined;
    multiply(&tmp_dest, &tmp, matrix);
    copy(matrix, &tmp_dest);
}
