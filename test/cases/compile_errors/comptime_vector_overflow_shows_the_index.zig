comptime {
    var a: @Vector(4, u8) = [_]u8{ 1, 2, 255, 4 };
    var b: @Vector(4, u8) = [_]u8{ 5, 6, 1, 8 };
    var x = a + b;
    _ = .{ &a, &b, &x };
}

// error
//
// :4:15: error: overflow of integer type 'u8' with value '256'
// :4:15: note: when computing vector element at index '2'
