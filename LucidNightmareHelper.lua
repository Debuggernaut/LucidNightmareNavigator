-- Lucid Nightmare Helper
-- by Vildiesel EU - Well of Eternity
-- modified by Wonderpants of Thrall to
--  track your location more intelligently

local addonName, addon = ...
local ng

local player_icon = "interface\\worldmap\\WorldMapArrow"

local containerW, containerH = 50000, 50000
local buttonW, buttonH = 18, 18

-- This 1-indexing is madness
--
--
-- THIS IS LUA!!!!!!!!!
--
local north = 1
local east = 2
local south = 3
local west = 4

local direction_strings = {"North","East","South","West"}
local color_strings = {"Yellow","Blue","Red","Green","Purple"}

local yellow = 1
local blue = 2
local red = 3
local green = 4
local purple = 5

local pool = {}
local map = {}
local rooms = {}
local current_room

local mf, scrollframe, container, playerframe = nil

local last_dir, last_room_number

local wall_buttons = {}
local guidance_buttons = {}

-- Quality Discount Function Pointers:
local navigateKludge
local resetVisitedKludge

-- Help navigate to unexplored territory
local navtarget = 11

local poirooms = {}

--local doors = {{{-1378, 680},{-1300,710}}, -- north
--               {{-1440, 600},{-1410,660}}, -- east
--               {{-1520, 680},{-1460,710}}, -- south
--               {{-1460, 740},{-1410,800}}} -- west

local function getOppositeDir(dir)
	if dir == north then return south
	elseif dir == east then return west
	elseif dir == south then return north
	else return east end
end

local function detectDir(x, y)
	if y > -1410 then
		return north
	elseif y < -1440 then
		return south
	elseif x < 660 then
		return east
	elseif x > 720 then
		return west
	end
end

local function centerCam(x, y)
	scrollframe:SetHorizontalScroll(x - 250 + buttonW / 2)
	scrollframe:SetVerticalScroll(y - 250 + buttonH / 2)
end

local function getUnusedButton()
	if #pool > 0 then
		return tremove(pool, 1)
	else
		local btn = ng:New(addonName, "Frame", nil, container)
		btn:SetSize(buttonW, buttonH)
		btn.text = btn:CreateFontString()
		btn.text:SetFont("Fonts\\FRIZQT__.TTF", 8)
		btn.text:SetAllPoints()
		btn.text:SetText("")
		return btn
	end
end

local function createButton(r)
	local btn = getUnusedButton()
	btn:SetPoint("TOPLEFT", container, "TOPLEFT", r.x, -r.y)
	btn:SetBackdropColor(1, 1, 1, 1)
	btn:SetBackdropBorderColor(0, 0, 0, 0) 
	btn:Show()
	r.button = btn
end

local function resetColor(r, c, t)
	for k,v in pairs(rooms) do
		if v ~= r and v.POI_c == c and v.POI_t == t then
			if t == "rune" then
				v.button:SetBackdropColor(1, 1, 1, 1)
			else
				v.button:SetBackdropBorderColor(0, 0, 0, 0)
			end
			v.POI_c = nil
		end
	end
end

local function setRoomNumber(r)
	--last_room_number = last_room_number + 1
	if r.index < 100 then
		r.button.text:SetTextHeight(10)
	else
		r.button.text:SetTextHeight(8)
	end
	r.button.text:SetText("|cff000000"..r.index.."|r")
	--r.number = last_room_number
end

local function recolorRoom(r)
	--resetColor(r, r.POI_c, r.POI_t)

	local func = r.POI_t == "rune" and r.button.SetBackdropColor or r.button.SetBackdropBorderColor

	if r.POI_c == yellow then
		func(r.button, 1, 1, 0, 1)
	elseif r.POI_c == blue then
		func(r.button, 0, 0.6, 1, 1)
	elseif r.POI_c == green then
		func(r.button, 0, 1, 0, 1)
	elseif r.POI_c == purple then
		func(r.button, 1, 0, 1, 1)
	elseif r.POI_c == red then
		func(r.button, 1, 0, 0, 1)
	else -- clear
		r.button:SetBackdropColor(1, 1, 1, 1) 
		r.button:SetBackdropBorderColor(0, 0, 0, 0) 
	end
end

local function newRoom()
	local r = {}
	r.neighbors = {}
	r.walls = {false, false, false, false}
	--print("Making a new room")
	--print ("r.walls[2]: ", r.walls[2])
	r.visited = false --used for graph traversals
	r.index = #rooms+1
	r.poi_index=0
	rooms[r.index] = r
	return r
end

local function getRotation(dir)
	if dir == west then
		return 90
	elseif dir == south then
		return 180
	elseif dir == east then
		return 270
	elseif dir == north then
		return 0
	end
end

local function updateWallButtonText()
	for i=1,4 do
		if (current_room == nil or not current_room.walls[i]) then
			wall_buttons[i]:SetText("No "..direction_strings[i].." Wall")
		else
			wall_buttons[i]:SetText("Wall to the "..direction_strings[i])
		end
	end
end

local function setCurrentRoom(r)
	current_room = r
	centerCam(r.x, r.y)
	playerframe:SetParent(r.button)
	playerframe:SetAllPoints()
	playerframe.tex:SetRotation(math.rad(getRotation(last_dir or north)))
	
	updateWallButtonText()
end

local function addRoom(dir)

	local r = newRoom()
	current_room.neighbors[dir] = r

	r.neighbors[getOppositeDir(dir)] = current_room

	local dx, dy = 0, 0

	if dir == north then
		dy = -buttonH - 5
	elseif dir == east then
		dx = buttonW + 5
	elseif dir == south then
		dy = buttonH + 5
	elseif dir == west then
		dx = -buttonW - 5
	end

	local offsetX, offsetY = dx, dy
	while true do
		local found

		-- Keep from drawing rooms on top of each other on the map
		for k,v in pairs(rooms) do
			if v.x == current_room.x + offsetX and v.y == current_room.y + offsetY then
				offsetX = offsetX + dx
				offsetY = offsetY + dy
				found = true
			end
		end

		if not found then
			break
		end
	end

	r.x = current_room.x + offsetX
	r.y = current_room.y + offsetY

	createButton(r)

	setRoomNumber(r)

	return r
end

local function EraseRooms()
	for k,v in pairs(rooms) do
		v.button:Hide()
		pool[#pool + 1] = v.button
	end

	wipe(rooms)
	wipe(map)
	wipe(poirooms)

	last_dir = north
end

local function ResetMap()
	EraseRooms()

	map[1] = newRoom()

	map[1].x = containerW / 2
	map[1].y = containerH / 2

	last_room_number = 0
	createButton(map[1])
	setRoomNumber(map[1])

	setCurrentRoom(map[1])
end

local ly, lx = 0, 0
local function update()
	local y, x = UnitPosition("player")

	if math.abs(x - lx) > 70 or math.abs(y - ly) > 70 then
		local dir = detectDir(lx, ly)
		if dir then
			last_dir = dir
			--print("-> Movement detected!  dir = ", dir, ", Neighbors: ", current_room.neighbors[dir])
			setCurrentRoom(current_room.neighbors[dir] or addRoom(dir))
			navigateKludge()
		end
	end

	lx = x
	ly = y
end

local default_theme = {
				   l0_color      = "000000ff",
				   l0_border     = "191919FF",
				   l0_texture    = "Interface\\Buttons\\GreyscaleRamp64",
				   l3_color      = "999999FF",
				   l3_border     = "000000FF",
				   l3_texture    = "Interface\\Buttons\\WHITE8X8",
				   l3_texture    = "spells\\ICETEXTURE_MAGE",
				   thumb         = "19B219FF",
				   highlight     = "00FFffFF",
	              -- fonts
				   f_label_name   = "Fonts\\FRIZQT__.ttf",
				   f_label_h      = 11,
				   f_label_flags  = "",
				   f_label_color  = "FFFFFFFF",
				   f_button_name  = "Fonts\\FRIZQT__.ttf",
				   f_button_h     = 11,
				   f_button_flags = "",
				   f_button_color = "FFFFFFFF",
				  }
			  
local function luaSucksQueueInit(crappyLuaQueue, minIndex, maxIndex)
	minIndex = 1
	maxIndex = 0
	
	return minIndex, maxIndex
end

local function luaSucksQueuePush(crappyLuaQueue, minIndex, maxIndex, newVal)
	crappyLuaQueue[maxIndex+1] = newVal
	return minIndex, maxIndex+1
end

local function luaSucksQueuePop(crappyLuaQueue, minIndex, maxIndex)
	if (minIndex > maxIndex) then
		return minIndex, maxIndex, nil
	end
	
	local newMin = minIndex + 1
	return newMin, maxIndex, crappyLuaQueue[minIndex]
end

--Returns true if empty
local function luaSucksQueueEmpty(crappyLuaQueue, minIndex, maxIndex)
	if (minIndex > maxIndex) then
		return true
	end
	
	return false
end

local function deDuplicateMap(orig, dupe)
	-- User has reached a second copy of the original room, spider out from this copy of the room and the original and erase duplicate rooms

	if (orig == dupe) then
		return
	end

	local roomQueue = {}
	local rq1 = 1
	local rq2 = 1
	
	local dupeQueue = {}
	local dq1 = 1
	local dq2 = 1
	
	rq1, rq2 = luaSucksQueueInit(roomQueue, rq1, rq2)
	dq1, dq2 = luaSucksQueueInit(dupeQueue, dq1, dq2)
	
	resetVisitedKludge()
	
	-- PERFORMANCE WARNING!!! This Lua table is actually
	-- some sort of bloated associative array, NOT a normal queue
	rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, orig)
	dq1, dq2 = luaSucksQueuePush(dupeQueue, dq1, dq2, dupe)

	while (not luaSucksQueueEmpty(roomQueue, rq1, rq2)) do
		local cur
		local dcur
		rq1, rq2, cur = luaSucksQueuePop(roomQueue, rq1, rq2)
		dq1, dq2, dcur = luaSucksQueuePop(dupeQueue, dq1, dq2)

		if (not cur.visited) then
			cur.visited = true

			for i=1,4 do				
				local n = cur.neighbors[i]
				local n2 = nil
				if (dcur ~= nil) then
					n2 = dcur.neighbors[i]
				end
				if (n == nil) then
					if (n2 ~= nil) then
					print ("Moving "..n2.index..", attaching to "..cur.index.." instead of "..dcur.index)
						cur.neighbors[i] = n2
						n2.neighbors[getOppositeDir(i)] = cur
						
						rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, n2)
						dq1, dq2 = luaSucksQueuePush(dupeQueue, dq1, dq2, nil)
					end
				else
					--if (n2 ~= nil) then
					--huh, I guess there's nothing special we need to do when
					-- queueing up rooms for de-duplication?
					--end
					rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, n)
					dq1, dq2 = luaSucksQueuePush(dupeQueue, dq1, dq2, n2)
				end
			end
			
			if (dcur ~= nil) then
				print ("Wiping out "..dcur.index..", dupe of "..cur.index)
				-- Wipe out all references to the duplicate room, and recycle
				-- its button:
				if (dcur.poi_index ~= 0) then
					cur.poi_index = dcur.poi_index
					poirooms[cur.poi_index] = cur
				end
				wipe(dcur.neighbors)
				wipe(dcur.walls)
				rooms[dcur.index] = nil
				dcur.button:Hide()
				pool[#pool + 1] = dcur.button
			end
		end
	end
	
	print ("Done de-duplicating map!")
	if (current_room == dupe) then
		current_room = orig
		setCurrentRoom(current_room)
	end
end

local poi_warned = 0
local function setPOIClick(self)
	
	if (poirooms[self.poi_index] == current_room) then
		return
	end
	
	--TODO: Warning popup before de-duplicating the map
	
	if (poirooms[self.poi_index] ~= nil and poi_warned ~= self.poi_index) then
		print ("WOAH WOAH WOAH, this point of interest was already defined as room "..poirooms[self.poi_index].index.."!  Click again to confirm a loop in the map and de-duplicate nodes")
		poi_warned = self.poi_index
		return
	end
	
	poi_warned = 0
	
	if (poirooms[self.poi_index] ~= nil) then
		deDuplicateMap(poirooms[self.poi_index], current_room)
	else
		if (poirooms[current_room.poi_index] ~= nil) then
			poirooms[current_room.poi_index] = nil
		end
		poirooms[self.poi_index] = current_room
		current_room.poi_index = self.poi_index
		
		current_room.POI_t = self.t
		current_room.POI_c = self.c
		recolorRoom(current_room)
	end
end

local function updateNavButtonText()
	for i=1,11 do
		local btn = guidance_buttons[i]
		
		local text = ""
		
		if (i == 11) then
			text = "Unexplored Territory"
		elseif (i > 0 and i < 6) then
			text = color_strings[i].." Rune"
		elseif (i > 5 and i < 11) then
			text = color_strings[i-5].." Orb"
		end
		
		if (i == navtarget) then
			text = "["..text.."]"
		end
		
		btn:SetText(text)
	end
end

eb = {}

function importMap()

	print("WARNING!  You must load the map from the same room as you were when you saved the map")
		
	EraseRooms()
	
	local t = eb:GetText()
	print("Loading this map:")
	print(t)

	raywashere = t
	local l = string.len(t)
	
	print("Length:",l)
	local i = 1
	while (i <= l) do
		--Lua seems to strip newlines out of the string when I read
		-- it, just end rooms with a "-" token to work around it
		local l1,l2 = string.find(t,"-",i,true)
		if (l2 == nil) then
			l2 = l
		end
		local line = string.sub(t,i,l2-1)
		i = l2
		--print (line)
		
		local substrings = {}
		local j=1
		local linelength = string.len(line)
		while (j <= linelength) do 
			local t1,t2 = string.find(line,",",j,true)
			if (t1 == nil) then
				t2 = l+1
			end
			local token = string.sub(line,j,t2-1)
			j = t2
						
			substrings[#substrings+1] = token
			
			j = j+1
		end
		
		last_room_number = #rooms
		
		local room = {}
		room.index = tonumber(substrings[1])
		if (room.index ~= nil) then 
			room.poi_index = tonumber(substrings[2])
			room.neighbor_indices = {}
			for neighbor=1,4 do
				room.neighbor_indices[neighbor] = tonumber(substrings[2+neighbor])
			end
			room.walls = {false, false, false, false}
			for wall=1,4 do
				room.walls[wall] = (substrings[6+wall]=="W")
			end
			room.visited=false
			room.neighbors={}
			
			rooms[room.index] = room
			
			room.x = tonumber(substrings[11])
			room.y = tonumber(substrings[12])
			
			if (substrings[13]=="current") then
				print ("Current room is ",room.index)
				current_room = room
			end
		else
			print("Ignoring line '"..line.."'")
		end
		
		i = i + 1
		
	end
	
	
	for k,v in pairs(rooms) do
		for neighbor=1,4 do
			local nIndex = v.neighbor_indices[neighbor]
			
			if (v.neighbor_indices[neighbor] ~= nil) then 
				if (rooms[nIndex] == nil) then
					print("Error, room ", v.index, " indicates it's neighbors with room ",nIndex,",which was not found")
				else
					v.neighbors[neighbor] = rooms[nIndex]
				end
			end
		end
		
		if (v.poi_index > 5) then
			v.POI_c = v.poi_index - 5
			v.POI_t = "orb"
			poirooms[v.poi_index] = v
		elseif (v.poi_index > 0) then
			v.POI_c = v.poi_index
			v.POI_t = "rune"
			poirooms[v.poi_index] = v
		end

		createButton(v)
		recolorRoom(v)
		setRoomNumber(v)
		
		if (v == current_room) then
			setCurrentRoom(v)
		end
	end
	
	
end

function dumpMap()

	local serialized = "index,poi,north_neighbor,east_neighbor,south_neighbor,west_neighbor,n_wall,e_wall,s_wall,w_wall,x,y,current,-\n"
	
	local dirLetters = {"N","E","S","W"}
	for k,v in pairs(rooms) do
		serialized=serialized..v.index..","..v.poi_index
		
		local neighborString = ""
		local wallString = ""
		
		local serializedNeighbors = ""
		local serializedWalls = ""
		for i=1,4 do
			if (v.walls[i]) then
				serializedWalls=serializedWalls..",W"
				wallString = wallString..dirLetters[i]..":W,"
			else
				serializedWalls=serializedWalls..", "
				wallString = wallString..dirLetters[i]..": ,"
			end
			if (v.neighbors[i] == nil) then
				serializedNeighbors=serializedNeighbors..", "
				neighborString = neighborString..dirLetters[i]..":X,"
			else
				serializedNeighbors=serializedNeighbors..","..v.neighbors[i].index
				neighborString = neighborString..dirLetters[i]..":"..v.neighbors[i].index..","
			end
		end
		
		serialized=serialized..serializedNeighbors..serializedWalls
		serialized=serialized..","..v.x..","..v.y..","
		
		local curString = ""
		if (current_room == v) then
			serialized=serialized.."current,"
			curString = " (YOU ARE HERE) "
		else
			serialized=serialized..","
		end
		
		serialized=serialized.."-\n"
		
		
		print("Room "..(k)..curString.." POI: ",v.poi_index," N:[",neighborString,"] W:[",wallString,"]")
	end
	eb:SetText(serialized)
end

local function resetVisited()
	for k,v in pairs(rooms) do
		v.visited = false
	end
end

local function outputGuidance(directions)
	local steps = (table.getn(directions)-1)
	
	local navString = ""
	
	if (navtarget == 11) then
		if (steps ~= 1) then
			print ("Hello, user!  I have detected an unexplored room ",steps," steps from here!")
		else
			navString = navString.."Unexplored room: "
		end
	else
		if (steps ~= 1) then
			local destStr = ""
			
			if (navtarget > 5) then
				destStr = color_strings[navtarget - 5]
				destStr = destStr.." Orb"
			elseif (navtarget > 0) then
				destStr = color_strings[navtarget]
				destStr = destStr.." Rune"
			end
			
			print ("Hello, user!  I have detected your destination ("..destStr..") ",steps," steps from here!")
		end
	end
	
	--directions[1] is always "0" due to a lazy design decision
	for i=2,4 do
		if (directions[i] == nil) then
			navString = navString.."You will have arrived at your destination!"
			break
		end
		navString = navString.."Go "..direction_strings[directions[i]]..", then "
		
		if (i == 4) then 
			navString = navString.."..."
		end
	end
	
	print(navString)
end

local function navigateToUnexplored()
	
	-- perform a depth-first traversal until you encounter an unexplored room
	-- and then print out directions to it for the user
	local roomstack = {}
	local roomstacksize = 0
	local directionsStack = {}
	
	resetVisited()
	
	-- PERFORMANCE WARNING!!! This Lua table is actually
	-- some sort of bloated associative array, NOT a normal stack
	table.insert(roomstack, current_room)
	roomstacksize = roomstacksize + 1
	
	-- Directions: 0 is the starting point,
	-- after that it's an array of directions taken to get
	-- to the current room
	local tempDirections = {0}
	table.insert(directionsStack, tempDirections)
	
	while (roomstacksize > 0) do

		local cur = table.remove(roomstack)
		roomstacksize = roomstacksize - 1
		cur.visited = true
		
		local tempDirections = table.remove(directionsStack)
		
		for i=1,4 do
			if (not cur.walls[i]) then
			
				local newDirections = {}
				for k,v in pairs(tempDirections) do
					newDirections[k] = v
				end
				newDirections[#newDirections+1] = i
				
				local n = cur.neighbors[i]
				if (n == nil) then
					outputGuidance(newDirections)
					return
				else
					if (not n.visited) then							
						table.insert(roomstack, n)
						roomstacksize = roomstacksize + 1
						table.insert(directionsStack, newDirections)
					end
				end
			end
		end
	end
	
	print ("Hmm, that's odd, according to this you have no unexplored territory.. maybe try navigating to some other point of interest and check the wall settings on your way ")
end

-- Navigates to global "navtarget"
local function navigateToTarget(targetRoom, startingRoom)

	if (targetRoom == nil or startingRoom == nil) then
		return
	end
	
	-- NOTE: It would be much faster in this case to simultaneously
	-- spider out from both targetRoom and startingRoom at the same
	-- time, then return the directions for where they meet
	-- I don't feel like bothering to chew through all that coding,
	-- though, so I'm going to take the extra half-assed approach
	-- and just do a normal breadth-first traversal starting at 
	-- startingRoom, without even bothering to cache the results or
	-- anything (: D

	local directionsQueue = {}
	
	resetVisited()
		
	local roomQueue = {}
	local rq1 = 1
	local rq2 = 1
	
	local targetQueue = {}
	local dq1 = 1
	local dq2 = 1
	
	rq1, rq2 = luaSucksQueueInit(roomQueue, rq1, rq2)
	dq1, dq2 = luaSucksQueueInit(directionsQueue, dq1, dq2)
	
	resetVisitedKludge()
	
	local tempDirections = {0}
	
	rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, startingRoom)
	dq1, dq2 = luaSucksQueuePush(directionsQueue, dq1, dq2, tempDirections)

	while (not luaSucksQueueEmpty(roomQueue, rq1, rq2)) do
		local cur
		dq1, dq2, tempDirections = luaSucksQueuePop(directionsQueue, dq1, dq2)
		rq1, rq2, cur = luaSucksQueuePop(roomQueue, rq1, rq2)

		if (not cur.visited) then
			cur.visited = true

			for i=1,4 do		
				local newDirections = {}
				
				local n = cur.neighbors[i]
				local n2 = nil
				if (n ~= nil) then
					for k,v in pairs(tempDirections) do
						newDirections[k] = v
					end
					newDirections[#newDirections+1] = i

					if (n == targetRoom) then
						--Found it!
						outputGuidance(newDirections)
						return
					end

					rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, n)
					dq1, dq2 = luaSucksQueuePush(directionsQueue, dq1, dq2, newDirections)
				end
			end
		end
	end
end

local function navigate()
	-- Navigates to the nearest unexplored territory, or
	-- a particular point of interest, based on global "navtarget"
	
	if (navtarget ~= 11) then
		navigateToTarget(poirooms[navtarget], current_room)
	else
		navigateToUnexplored()
	end
end

local function setGuidanceClick(self)

	if (self.target == 11) then
		navtarget = 11
		updateNavButtonText()
		navigate()
		return
	end
	
	if (poirooms[self.target] == nil) then
		print("That target has not been discovered yet.  Navigating to the nearest unexplored territory")
		navtarget = 11
		updateNavButtonText()
		navigate()
		return
	else
		navtarget = self.target
		updateNavButtonText()
		navigate()
		return
	end
end

local function setWallClick(self)
	current_room.walls[self.dir] = not current_room.walls[self.dir]
	recolorRoom(current_room)
	updateWallButtonText()
end
   
local function initialize()

	navigateKludge = navigate
	resetVisitedKludge = resetVisited
	
	if mf then 
		mf:SetShown(not mf:IsShown())
		return
	end

	ng = NyxGUI("1.0")
	ng:Initialize(addonName, nil, "main", default_theme)

	mf = ng:New(addonName, "Frame", nil, UIParent)
	ng:SetFrameMovable(mf, true)
	mf:SetPoint("CENTER")
	mf:SetSize(700, 500)

	scrollframe = CreateFrame("ScrollFrame", nil, mf)
	scrollframe:SetAllPoints()

	container = CreateFrame("Frame", nil, scrollframe)
	container:SetSize(containerW, containerH)
	scrollframe:SetScrollChild(container)

	playerframe = CreateFrame("Frame")
	playerframe:SetAllPoints()
	playerframe.tex = playerframe:CreateTexture()
	playerframe.tex:SetAllPoints()
	playerframe.tex:SetTexture(player_icon)

	-- This reset map button should no longer be necessary
	-- local reset = ng:New(addonName, "Button", nil, mf)
	-- reset:SetPoint("BOTTOM", mf, "BOTTOM", -50, 10)
	-- reset:SetScript("OnClick", ResetMap)
	-- reset:SetText("Reset map")

	for i = 1,5 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 10, -20 * i)
		btn:SetSize(90, 18)
		btn.t = "rune"
		btn.c = i
		btn.poi_index = i
		btn:SetScript("OnClick", setPOIClick)
		btn:SetText(color_strings[i].." Rune")
		btn:SetFrameLevel(5)

		btn = ng:New(addonName, "Button", nil, mf)
		btn:SetSize(90, 18)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 110, -20 * i)
		btn.t = "orb"
		btn.c = i
		btn.poi_index = i+5
		btn:SetScript("OnClick", setPOIClick)
		btn:SetText(color_strings[i].." Orb")
		btn:SetFrameLevel(5)

		-- automatic waypoints maybe in future
	end

	-- Buttons to add/remove walls
	for i = 1,4 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn.dir = i
		btn:SetScript("OnClick", setWallClick)
		wall_buttons[i] = btn
		btn:SetFrameLevel(5)
		btn.highlight:SetBlendMode("DISABLE")
	end
	updateWallButtonText()
	
	wall_buttons[1]:SetPoint("TOPLEFT", mf, "TOPLEFT", 300, -20)
	wall_buttons[1]:SetSize(100, 18)
	wall_buttons[2]:SetPoint("TOPLEFT", mf, "TOPLEFT", 350, -40)
	wall_buttons[2]:SetSize(100, 18)
	wall_buttons[4]:SetPoint("TOPLEFT", mf, "TOPLEFT", 250, -40)
	wall_buttons[4]:SetSize(100, 18)
	wall_buttons[3]:SetPoint("TOPLEFT", mf, "TOPLEFT", 300, -60)
	wall_buttons[3]:SetSize(100, 18)
	
	--TODO: Figure out how to make a normal text label instead of a button
	local btn = ng:New(addonName, "Button", nil, mf)
	btn:SetSize(130,25)
	btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 530, -20 )
	btn:SetText("Navigation Target:")
	btn:SetFrameLevel(5)
	
	for i=1,11 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn.target = i
		btn:SetScript("OnClick", setGuidanceClick)
		guidance_buttons[i] = btn
		
		btn:SetSize(90, 18)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 550, -20 * i - 30)
		
		if (i == 11) then
			btn:SetSize(130,25)
			btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 530, -20 * i - 30)
		end
		
		guidance_buttons[i] = btn
	end
	updateNavButtonText()

	local btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 55, -20 * 6)
	btn:SetSize(90, 18)
	--btn.t = "rune"
	btn.c = 6
	btn:SetScript("OnClick", setPOIClick)
	btn:SetText("Clear Color")
	
	btn:Disable()
	
	eb = ng:New(addonName, "Editbox", nil, mf)
	eb:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 20, 20)
	eb:SetSize(110, 18)
	eb:SetText("CTRL+A, CTRL+C")
	
	btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 140, 30)
	btn:SetSize(130, 18)
	btn:SetScript("OnClick", dumpMap)
	btn:SetText("Export Map to Box")
	
	btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 140, 10)
	btn:SetSize(130, 18)
	btn:SetScript("OnClick", importMap)
	btn:SetText("Import Map From Box")

	ResetMap()

	ly, lx = UnitPosition("player")

	mf:SetScript("OnUpdate", update)

	local hide = ng:New(addonName, "Button", nil, mf)
	hide:SetPoint("BOTTOM", mf, "BOTTOM", 50, 10)
	hide:SetScript("OnClick", function() mf:Hide() end)
	hide:SetText(CLOSE)
	
	--LucidNightmareHelperTooltip:SetOwner(_G["UIParent"],"ANCHOR_NONE")
	
	print ("Welcome to the Lucid Nightmare Maze Helper by Vildiesel and Wonderpants!")
	print ("-------------")
	print ("Don't bother checking the map too carefully, because the maze is three-dimensional and it doesn't appear that every room is actually perfectly square (or the connections between them are different lengths in actual space, anyway).  This means that if you try to carefully graph everything out, you'll end up with strange overlaps, loops, and places where things don't meet up.")
	print("The addon is going to watch you and build a map in memory, but since it can't see runes, orbs, or walls, you're going to have to help it out by clicking the buttons to indicate which walls are passable and which have rubble, and which rooms have orbs/runes.")
	print("Please don't pick up any runes or put them in any orbs until you've found all the runes and orbs with the addon's help.  If you get lost, the addon will guide you to the nearest unexplored path or you can ask it for directions to the nearest node/rune")
end

-- slash command
SLASH_LUCIDNIGHTMAREHELPER1 = "/lucid"
SLASH_LUCIDNIGHTMAREHELPER2 = "/ln"
SLASH_LUCIDNIGHTMAREHELPER3 = "/lnh"
SlashCmdList["LUCIDNIGHTMAREHELPER"] = initialize
