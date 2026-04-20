The Endless Halls is a cruel, uncompromising maze, designed to confuse and disorient at every turn. You start in a nondescript room with foggy exits in the four cardinal directions (N/E/S/W), though some are blocked by rubble. Going in one of these exits will fade the screen to black, then fade back in with you in the connected room.

The goal of the maze is to find 5 colors of orbs (red/blue/green/yellow/purple), and deliver them (carried one at a time) to the 5 matching colors of runes. However, several mechanics make this much more difficult than it may sound.

The maze is arranged on an 8x8 grid of rooms. Each cell has between one and four exits. However, if it would have 4 exits, it’s actually not a single room, but two two-way rooms that occupy the same space, but don’t intersect. These Non-Intersecting Cross rooms are the first major source of confusing discontinuity, and also cannot contain any Orbs or Runes.

The second main source of disorientation is the edges. They loop around, but not directly. Instead, exiting one end of the maze will send you to the other side of the maze, with an additional offset. This makes it very difficult to tell what room you will end up in if you cross the edge of the map. You can, however, reliably backtrack from your new position to your previous position. Many players made frequent use of this backtracking to reliably navigate the maze without getting lost.

In addition, there is one final wrench thrown into the gears: the Teleportation Trap. Within the maze, a single room is the Teleportation Trap. When you enter this room, you are instead secretly teleported to a random room in the maze. Once you’ve identified the Teleportation Trap room, avoid it at all costs!

Once you’ve dropped the fifth orb off at its matching rune, the next exit you travel through will takes you to a golden room with the next Inconspicuous Note.
---

## What This Addon Does

Lucid Nightmare Navigator automatically maps The Endless Halls as you explore it. You never need to draw anything by hand — just walk around and the addon builds the map for you in real time.

On top of the map, it gives you turn-by-turn directions to wherever you need to go next: the nearest unexplored room, a specific orb, or a specific rune. Use the wall buttons at the top of the addon window to mark any blocked exits, and the directions will route around them automatically.

You can also save and reload your map at any time using the export/import text box in the bottom-left corner of the window, so you don't lose progress if something goes wrong.

---

## Recent Improvements

### Teleport Trap No Longer Corrupts Your Map
Previously, walking into the Teleportation Trap room would silently break the map — the addon would record a false connection to wherever you landed, sending you on wild goose chases with no way to recover short of erasing everything and starting over.

The addon now detects when you've been teleported. Every time you move between rooms it checks whether you arrived at the door you should have based on the direction you left from. If those don't match, it knows something went wrong, undoes the bad connection, and flags the trap room automatically. Your map stays clean and your directions stay trustworthy.

### Directions Now Update When You Toggle a Wall
If you marked a direction as blocked and then re-ran navigation, the directions shown on screen could still point you through the wall you just toggled. The addon now immediately recalculates and reprints directions whenever you change a wall setting, so what you see is always up to date.

### Faster Navigation on Large Maps
The pathfinding that powers the turn-by-turn directions has been rewritten to be significantly more efficient. In the previous version, finding a route required copying the entire path walked so far for every room visited — meaning the work grew rapidly as the map got larger. The new version tracks paths using a lightweight parent-pointer structure and only assembles the final directions once the destination is found. On a fully explored 8×8 maze the difference is substantial, and the addon should feel noticeably snappier when recalculating routes.
