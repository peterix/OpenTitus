pub fn subto0(number: *u8) void {
    if (number.* > 0) {
        number.* -= 1;
    }
}
