const audio = @import("audio/audio.zig");
const input = @import("input.zig");

pub const GameEvent = enum {
    None,
    HitEnemy,
    HitPlayer,
    PlayerHeadImpact,
    PlayerPickup,
    PlayerPickupEnemy,
    PlayerThrow,
    PlayerJump,
    BallBounce,
    PlayerCollectWaypoint,
    PlayerCollectBonus,
    PlayerCollectLamp,
    Options_TestRumble,
};

pub fn triggerEvent(event: GameEvent) void {
    audio.triggerEvent(event);
    input.triggerEvent(event);
}
