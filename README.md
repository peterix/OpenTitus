# OpenTitus

[![Build & Test](https://github.com/peterix/OpenTitus/actions/workflows/test_on_push.yml/badge.svg?branch=master&event=push)](https://github.com/peterix/OpenTitus/actions/workflows/test_on_push.yml)

![Game title screen](/docs/title.jpg)

A port of the game engine behind the DOS versions of Titus the Fox and Moktar.

OpenTitus is released under the Gnu GPL version 3 or (at your option) any later version of the license, and it is released "as is"; without any warranty.

This is a fork that aims to modernize the codebase, clean everything up, fix bugs, and make the game playable on modern systems with large 4K screens.

## Building:
You need:
* [zig 0.14.0](https://ziglang.org/download/#release-0.14.0)
* SDL 2 and SDL_mixer libraries available and usable for development

This should get things built and ready for testing/use:
```
zig build
```

## Running:
You need the original game files to make use of OpenTitus. OpenTitus parses the original files. It works with both Titus the Fox and Moktar.

* Build and install into the `bin` folder according to the build instructions.
* Place original game files in `bin/moktar` and/or `bin/titus` folders.
* Run `opentitus` inside `bin/titus` folder or `openmoktar` in `bin/moktar` folder.

Please do not upload the original game files to the git server, as they are proprietary!

If you can find some bugs or differences between OpenTitus and the original games, feel free to contact us!

Enjoy!
