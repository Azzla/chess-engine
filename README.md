A fully compliant, playable chess engine written in Lua and rendered with the Love2D game framework.  Features a multi-threaded AI opponent with alpha-beta + quiescence search algorithms.

To play against the engine, download the latest release build and run the exectuable.

To make changes and test them yourself, you must have [Love2D](https://love2d.org/) installed on your computer. Then you have a few options:
- Zip the repository, rename the extension to `<name>.love`, and drag it on top of `love.exe`.
- Open the repository in any Lua-compliant text editor, set up a build-script for use with love, and run the build/compile hotkey.


## Completed Goals
- Bug-free legal move generation: Passes all Perfts up to a depth of 5-ply from [this](http://www.rocechess.ch/perft.html) testing suite.
- Optimized move generation: Various speed increases have been achieved via table-lookups, init-time move info storage, array indexing over looping, removing `table.insert`, etc.  More optimization is always possible but its good enough for the time being.
- Playable AI opponent: Opponent can find good moves in most positions and generally avoids bad moves. I've noticed a bug where the search thread hangs and it never returns the best move, but it seems to occur rarely.

## TODO Goals
- Transposition table: The engine is wasting a lot of time evaluating positions that it's likely seen already from a different move order - this can avoided by storing evaluations in the so-called "transposition table".  Should result in a massive speedup and allow the engine to see much farther depths in endgame positions, for example.
- Bitboards: LuaJIT comes packaged with two libraries, FFI and BitOp.  FFI allows us to access unsigned 64-bit integer types from C and BitOp allows us to run classical bitwise operations on them.  This means I can potentially represent the board with uint_64s instead of arrays of Lua numbers.  Running bitwise operations on these data types is extremely fast and memory-efficient, and will likely grant several orders of magnitude of speedup in search depths of the same ply.
- Animations: It's a little jarring how the enemy just plays moves and they teleport instantly.  It'd look nicer if the pieces slid towards their new positions with a visual animation.
