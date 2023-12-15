#include "globals.h"

uint8_t RESETLEVEL_FLAG;
bool GAMEOVER_FLAG; //triggers a game over
uint8_t BAR_FLAG; //timer for health bar
bool X_FLAG; //true if left or right key is pressed
bool Y_FLAG; //true if up or down key is pressed
uint8_t CHOC_FLAG; //headache timer
uint8_t action; //player sprite array
uint8_t KICK_FLAG; //hit/burn timer
bool GRANDBRULE_FLAG; //If set, player will be "burned" when hit (fireballs)
bool LADDER_FLAG; //True if in a ladder
bool PRIER_FLAG; //True if player is forced into kneestanding because of low ceiling
uint8_t SAUT_FLAG; //6 if free fall or in the middle of a jump, decremented if on solid surface. Must be 0 to initiate a jump.
uint8_t LAST_ORDER; //Last action (kneestand + jump = silent walk)
uint8_t FURTIF_FLAG; //Silent walk timer
bool DROP_FLAG; //True if an object is throwed forward
bool DROPREADY_FLAG;
bool CARRY_FLAG; //true if carrying something (add 16 to player sprite)
bool POSEREADY_FLAG;
uint8_t ACTION_TIMER; //Frames since last action change
//TITUS_sprite sprite; //Player sprite
//TITUS_sprite sprite2; //Secondary player sprite (throwed objects, "hit" when object hits an enemy, smoke when object hits the floor)
uint8_t INVULNERABLE_FLAG; //When non-zero, boss is invulnerable
uint8_t TAPISFLY_FLAG; //When non-zero, the flying carpet is flying
uint8_t CROSS_FLAG; //When non-zero, fall through certain floors (after key down)
uint8_t GRAVITY_FLAG; //When zero, skip object gravity function
uint8_t FUME_FLAG; //Smoke when object hits the floor
const uint8_t *keystate; //Keyboard state
uint8_t YFALL;
bool POCKET_FLAG;
bool PERMUT_FLAG; //If false, there are no animated tiles on the screen?
uint8_t loop_cycle; //Increased every loop in game loop
uint8_t tile_anim; //Current tile animation (0-1-2), changed every 4th game loop cycle
uint8_t BITMAP_X; //Screen offset (X) in tiles
// uint8_t BITMAP_XM; //Point to the left tile in the tile screen (0 to 19)
uint8_t BITMAP_Y; //Screen offset (Y) in tiles
// uint8_t BITMAP_YM; //Point to the top tile in the tile screen (0 to 11)
bool g_scroll_x; //If true, the screen will scroll in X
int16_t g_scroll_x_target; //If scrolling: scroll until player is in this tile (X)
int16_t g_scroll_px_offset;
int16_t XLIMIT; //The engine will not scroll past this tile before the player have crossed the line (X)
bool g_scroll_y; //If true, the screen will scroll in Y
uint8_t g_scroll_y_target; //If scrolling: scroll until player is in this tile (Y)
uint8_t ALTITUDE_ZERO; //The engine will not scroll below this tile before the player have gone below (Y)
uint16_t IMAGE_COUNTER; //Increased every loop in game loop (0 to 0x0FFF)
int8_t SENSX; //1: walk right, 0: stand still, -1: walk left, triggers the ACTION_TIMER if it changes
uint8_t SAUT_COUNT; //Incremented from 0 to 3 when accelerating while jumping, stop acceleration upwards if >= 3
bool NOSCROLL_FLAG;
bool NEWLEVEL_FLAG; //Finish a level
uint8_t BIGNMI_NBR; //Number of bosses that needs to be killed to finish
uint8_t TAUPE_FLAG; //Used for enemies walking and popping up
uint8_t TAPISWAIT_FLAG; //Flying carpet state
uint8_t SEECHOC_FLAG; //Counter when hit
uint8_t BIGNMI_POWER; //Lives of the boss
bool boss_alive; //True if the boss is alive
uint8_t AUDIOMODE;

bool GODMODE; //If true, the player will not interfere with the enemies
bool NOCLIP; //If true, the player will move noclip
bool DISPLAYLOOPTIME; //If true, display loop time in milliseconds

SPRITE sprites[256];

SPRITEDATA spritedata[256];

uint16_t level_code[16];
