const audio = @import("audio/audio.zig");
const input = @import("input.zig");

pub const GameEvent = enum {
    Event_HitEnemy,
    Event_HitPlayer,
    Event_PlayerHeadImpact,
    Event_PlayerPickup,
    Event_PlayerPickupEnemy,
    Event_PlayerThrow,
    Event_PlayerJump,
    Event_BallBounce,
    Event_PlayerCollectWaypoint,
    Event_PlayerCollectBonus,
    Event_PlayerCollectLamp,
};

pub fn triggerEvent(event: GameEvent) void {
    audio.triggerEvent(event);
    input.triggerEvent(event);
}
