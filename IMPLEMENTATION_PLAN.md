# Reliable Map Implementation Plan
## LucidNightmareNavigator — Backtracking-Based Fix

---

## Problem Summary

`update()` runs every frame. When a large position delta is detected it calls
`addRoom(dir)` or follows `current_room.neighbors[dir]`, immediately committing
that edge permanently. Two mechanics produce bad edges:

1. **Teleport Trap** — the player enters a room and is secretly moved to a
   random location. The addon creates a real bidirectional link that is
   structurally wrong.
2. **Edge wrapping** — exiting a maze edge wraps the player to a different row
   or column with an offset. The addon creates a duplicate subgraph instead of
   recognising the already-known destination.

Both failures share the same root cause: **there is no validation step before
an edge is committed, and no mechanism to undo a bad commit later**.

---

## Approach

**Entry Direction Validation + Move History Rollback**

Two signals are already computable from existing code:

- `detectDir(lx, ly)` — which door the player *exited* (computed at movement
  detection time, already available as `last_dir`)
- `detectDir(x, y)` — which door the player *arrived near* (computable one
  settle-period after the transition)

For every legal transition — normal, wrap, or NIC pass-through — a player who
exits going **North** must arrive near the **South** door of the destination.
This invariant holds for all room types because every room in The Endless Halls
uses the same physical floor plan.

The **teleport trap is the only mechanic that breaks this invariant**.

A `move_history` stack records every committed `{from, dir, to}` triple so that
when a bad transition is detected, the corrupted edge can be located and removed
surgically rather than resetting the whole map.

---

## Step-by-Step Plan

---

### ✅ Step 1 — Add state variables (top of file, near existing globals)

**File:** `LucidNightmareNavigator.lua`  
**Location:** after `local last_dir, last_room_number` (~line 44)

Add:

```lua
local move_history = {}          -- stack of {from, dir, to, is_new_room}
local pending_validation = false -- true while waiting for player to settle
local pending_exit_dir = nil     -- the dir used for the pending transition
local settle_ticks = 0           -- countdown to landing confirmation
local SETTLE_TICKS = 3           -- frames to wait after a transition
```

**Why:** `settle_ticks` is needed because `UnitPosition` returns values mid-fade
that do not correspond to any real room position. 3 frames is sufficient to
outlast the screen-fade animation.

---

### ✅ Step 2 — Add `validateEntry(entryDir, exitDir)` helper

**File:** `LucidNightmareNavigator.lua`  
**Location:** after `getOppositeDir()` (~line 67)

```lua
-- Returns true if landing near entryDir is consistent with having
-- exited via exitDir.  A player going North always arrives at the
-- South door, East → West door, etc.
-- Returns nil if detectDir returned nil (player is in room center,
-- can't tell — treat as valid to avoid false positives).
local function validateEntry(entryDir, exitDir)
    if entryDir == nil then return true end
    return entryDir == getOppositeDir(exitDir)
end
```

---

### ✅ Step 3 — Add `rollbackLastTransition()`

**File:** `LucidNightmareNavigator.lua`  
**Location:** after `validateEntry()`, before `centerCam()`

```lua
local function rollbackLastTransition()
    if #move_history == 0 then return end

    local move = table.remove(move_history)  -- pop the bad step

    -- Sever the edge in both directions
    move.from.neighbors[move.dir] = nil
    move.to.neighbors[getOppositeDir(move.dir)] = nil

    -- If the destination room was freshly created by this step and
    -- has no other connections, recycle it
    if move.is_new_room then
        local hasOtherNeighbors = false
        for i = 1, 4 do
            if move.to.neighbors[i] ~= nil then
                hasOtherNeighbors = true
                break
            end
        end
        if not hasOtherNeighbors then
            move.to.button:Hide()
            pool[#pool + 1] = move.to.button
            rooms[move.to.index] = nil
        end
    end

    -- Return the player to the room they came from
    setCurrentRoom(move.from)

    print("WARNING: Teleport trap detected!  The "
          .. direction_strings[move.dir]
          .. " exit from room " .. move.from.index
          .. " has been marked as a wall.")

    move.from.walls[move.dir] = true
    recolorRoom(move.from)
    updateWallButtonText()
end
```

**Why `is_new_room`:** if the destination was a previously known room (edge
wrap hitting a known node), we should not recycle it — only sever the bad edge.

---

### ✅ Step 4 — Modify `addRoom()` to tag new rooms

**File:** `LucidNightmareNavigator.lua`  
**Location:** existing `addRoom()` function (~line 285)

Change the return statement to also return a flag:

```lua
local function addRoom(dir)
    local r = newRoom()
    current_room.neighbors[dir] = r
    r.neighbors[getOppositeDir(dir)] = current_room
    setRoomXY(current_room, dir, r)
    createButton(r)
    setRoomNumber(r)
    return r, true   -- second return value: is_new_room = true
end
```

Existing callers that ignore the second return value are unaffected.

---

### ✅ Step 5 — Rewrite `update()` with two-phase validation

**File:** `LucidNightmareNavigator.lua`  
**Location:** existing `update()` function (~line 329)

Replace the current body:

```lua
local ly, lx = 0, 0
local function update()
    local y, x = UnitPosition("player")

    -- Phase 2: validate a pending transition once the player has settled
    if pending_validation then
        if settle_ticks > 0 then
            settle_ticks = settle_ticks - 1
        else
            pending_validation = false
            local entryDir = detectDir(x, y)
            if not validateEntry(entryDir, pending_exit_dir) then
                rollbackLastTransition()
            end
            pending_exit_dir = nil
        end
        lx = x
        ly = y
        return
    end

    -- Phase 1: detect a room transition
    if math.abs(x - lx) > 70 or math.abs(y - ly) > 70 then
        local dir = detectDir(lx, ly)
        if dir then
            last_dir = dir

            local existing = current_room.neighbors[dir]
            local next_room, is_new_room

            if existing ~= nil then
                -- Check for back-link contradiction before following
                local backLink = existing.neighbors[getOppositeDir(dir)]
                if backLink ~= nil and backLink ~= current_room then
                    -- Graph contradiction: existing edge points to a
                    -- different room — this is a known symptom of a
                    -- previously undetected trap in the history.
                    -- Scan move_history to find and remove the bad step.
                    for i = #move_history, 1, -1 do
                        local h = move_history[i]
                        if h.to == existing then
                            table.remove(move_history, i)
                            h.from.neighbors[h.dir] = nil
                            h.to.neighbors[getOppositeDir(h.dir)] = nil
                            print("WARNING: Back-link contradiction on room "
                                  .. existing.index
                                  .. " — removing corrupted edge from history.")
                            break
                        end
                    end
                    -- Re-evaluate: existing is now potentially stale
                    existing = current_room.neighbors[dir]
                end

                next_room, is_new_room = existing, false
            end

            if next_room == nil then
                next_room, is_new_room = addRoom(dir)
            end

            -- Record this step before committing
            table.insert(move_history, {
                from        = current_room,
                dir         = dir,
                to          = next_room,
                is_new_room = is_new_room,
            })

            setCurrentRoom(next_room)
            navigateKludge()

            -- Start settle countdown for entry validation
            pending_validation = true
            pending_exit_dir   = dir
            settle_ticks       = SETTLE_TICKS
        end
    end

    lx = x
    ly = y
end
```

---

### ✅ Step 6 — Add NIC room disambiguation

**File:** `LucidNightmareNavigator.lua`  
**Location:** inside `rollbackLastTransition()`, before the `print` statement

Non-Intersecting Cross rooms also produce an entry-direction mismatch because
the NIC partner passes the player through to the exit on the same side they
entered. Unlike the trap, this is **consistent and repeatable** — the same
direction from the same room always mismatches.

Track mismatch counts per room per direction:

```lua
-- In rollbackLastTransition(), before severing the edge:
local room = move.from
local dir  = move.dir
if room.mismatch_count == nil then room.mismatch_count = {} end
room.mismatch_count[dir] = (room.mismatch_count[dir] or 0) + 1

if room.mismatch_count[dir] >= 2 then
    -- Same room, same direction, mismatch twice → NIC room, not a trap.
    -- Re-attach the edge and mark the room as a known NIC.
    room.neighbors[dir] = move.to
    move.to.neighbors[getOppositeDir(dir)] = room
    room.is_nic = true
    print("Room " .. room.index .. " identified as a Non-Intersecting Cross room.")
    setCurrentRoom(move.to)
    return
end
```

This goes at the **top** of `rollbackLastTransition()`, before any severing,
so the second traversal of a NIC direction re-confirms instead of removing.

---

### ✅ Step 7 — Limit move history size

**File:** `LucidNightmareNavigator.lua`  
**Location:** inside `update()`, after `table.insert(move_history, ...)`

The maze has at most 64 rooms. A history longer than 128 steps cannot
contribute new information (every room has been visited at least twice).
Cap it to prevent unbounded memory growth:

```lua
local MAX_HISTORY = 128
if #move_history > MAX_HISTORY then
    table.remove(move_history, 1)
end
```

---

### ✅ Step 8 — Clear history on map reset

**File:** `LucidNightmareNavigator.lua`  
**Location:** inside `EraseRooms()` (~line 301)

```lua
-- Add at the end of EraseRooms():
wipe(move_history)
pending_validation = false
pending_exit_dir   = nil
settle_ticks       = 0
```

---

### Step 9 — Persist history across import/export (optional, Phase 2)

The current `dumpMap()` / `importMap()` format does not include the move
history. This is acceptable for Phase 1 — the history is short-lived runtime
state. After import, the player is in a known room and history restarts clean.

If a future version needs to survive a reload mid-exploration, add
`move_history` serialisation to `dumpMap()` using the existing CSV format.

---

## Testing Checklist

| Scenario | Expected behaviour |
|---|---|
| Normal N/E/S/W transition | History entry added, no rollback |
| Enter a new unexplored room | Room created, `is_new_room = true` |
| Enter teleport trap | Entry mismatch after settle → edge severed, room recycled if new, player returned to prior room, wall marked |
| Enter NIC room (first time) | Entry mismatch → rollback (mismatch_count = 1) |
| Enter NIC room (second time) | Entry mismatch → NIC identified, edge re-confirmed |
| Edge wrap to known room | Back-link check catches contradiction → bad history step found and removed |
| Map reset | `move_history` wiped, state variables reset |
| Import map | History starts fresh from import position |

---

## Files Changed

| File | Change |
|---|---|
| `LucidNightmareNavigator.lua` | Steps 1–8 above; no other files modified |

---

## What Is NOT Changed

- `deDuplicateMap()` — still invoked manually via POI click; the new system
  reduces the need for it but does not remove it
- `hitTheTrap()` — still available as a manual override button
- `navigateToTarget()` / `navigateToUnexplored()` — BFS logic untouched
- All NyxGUI library files — no changes
- Serialisation format — backwards compatible
