<div align="center">

# OpenTitus

![Game title screen](/docs/title.jpg)

A modernized version of the game engine behind the DOS versions of Titus the Fox and Moktar.

The aim is to clean up the codebase, fix bugs, and make the game playable on modern systems. The difficulty or design decisions of the original are not sacred. If there's a way to make the game more playable or enjoyable, then let it be so.

For the authentic (brutal) experience, the game can be played in DOSBox.

[![Build & Test](https://github.com/peterix/OpenTitus/actions/workflows/test_on_push.yml/badge.svg?branch=master&event=push)](https://github.com/peterix/OpenTitus/actions/workflows/test_on_push.yml)

---

</div>

## License
OpenTitus is released under the Gnu GPL version 3 or (at your option) any later version of the license, and it is released "as is"; without any warranty.

## Building:
You need:
* [zig 0.15.1](https://ziglang.org/download/#release-0.15.1)

This should get things built and ready for testing/use:
```
zig build
```

## Running:
You need the original game files to make use of OpenTitus. OpenTitus parses the original files. It works with both Titus the Fox and Moktar.

* Build and install using `make release`. The files go into `zig-out`.
* Place the original game files in `zig-out/MOKTAR` and/or `zig-out/TITUS` folders.
* Run `opentitus` inside the `zig-out` folder.

You can get the game files from:

* Your old floppy disks!
* Steam
    * https://store.steampowered.com/app/711230/Titus_the_Fox/
* GOG:
    * https://www.gog.com/en/game/titus_the_fox_to_marrakech_and_back
* Epic Games:
    * https://store.epicgames.com/sv/p/titus-the-fox-150ecc

Please do not upload the original game files to the git server, as they are proprietary!

Enjoy!
