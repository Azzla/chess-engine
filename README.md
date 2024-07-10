A fully compliant, playable chess engine written in Lua and rendered with the Love2D game framework.

To test the engine yourself, you must have [https://love2d.org/](Love2D) installed on your computer. Then you have a few options:
1 - Zip the repository, rename the extension to `<name>.love`, and drag it on top of `love.exe`.
2 - Open the repository in any Lua-compliant text editor, set up a build-script for use with love, and run the build/compile hotkey.

## GOALS
- Bug-free playable chess games (done). Need to run some official tests to confirm.
- Engine AI that can defeat me in a game of chess.  Not started work on position-evaluation yet.
- Distributable game files for both Windows and MacOS.
- Optimization the move generation.
- Clean up the code.
