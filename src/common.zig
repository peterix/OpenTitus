/// Align a pixel position to the start of its tile
pub fn alignToTile(position: i16) i16 {
    return position & -16;
}

pub fn subto0(number: *u8) void {
    if (number.* > 0) {
        number.* -= 1;
    }
}
