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
 rooms = {}
local current_room
local mf, scrollframe, container, playerframe
local last_dir, last_room_number

local wall_buttons = {}
guidance_buttons = {}

-- Help navigate to unexplored territory
local navtarget = 11

local poirooms = {}

raywashere = "Hello world!"

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
	last_room_number = last_room_number + 1
	if last_room_number < 100 then
		r.button.text:SetTextHeight(10)
	else
		r.button.text:SetTextHeight(8)
	end
	r.button.text:SetText("|cff000000"..last_room_number.."|r")
	r.number = last_room_number
end

local function recolorRoom(r)
	resetColor(r, r.POI_c, r.POI_t)

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
	rooms[#rooms + 1] = r
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

local function setCurrentRoom(r)
	current_room = r
	centerCam(r.x, r.y)
	playerframe:SetParent(r.button)
	playerframe:SetAllPoints()
	playerframe.tex:SetRotation(math.rad(getRotation(last_dir or north))) 
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

local function ResetMap()
	for k,v in pairs(rooms) do
		v.button:Hide()
		pool[#pool + 1] = v.button
	end

	wipe(rooms)
	wipe(map)

	last_dir = north

	map[1] = newRoom()

	map[1].x = containerW / 2
	map[1].y = containerH / 2

	last_room_number = -1
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
			setCurrentRoom(current_room.neighbors[dir] or addRoom(dir))
		end
	end

	lx = x
	ly = y
end

local default_theme = {
				   l0_color      = "000000ff",
				   l0_border     = "191919E6",
				   l0_texture    = "Interface\\Buttons\\GreyscaleRamp64",
				   l3_color      = "999999cc",
				   l3_border     = "000000aa",
				   l3_texture    = "Interface\\Buttons\\WHITE8X8",
				   l3_texture    = "spells\\ICETEXTURE_MAGE",
				   thumb         = "19B219FF",
				   highlight     = "00FFff33",
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


local function setPOIClick(self)
	current_room.POI_t = self.t
	current_room.POI_c = self.c
	recolorRoom(current_room)
end

local function updateNavButtonText()
	for i=1,11 do
		local btn = guidance_buttons[i]
		
		local text = ""
		
		if (i == 11) then
			text = "Unexplored Territory"
		elseif (i > 0 and i < 6) then 
			--sorry, too lazy to look up >= operator in lua -WP
			text = color_strings[i].." Orb"
		elseif (i > 5 and i < 11) then
			text = color_strings[i-5].." Rune"
		end
		
		if (i == navtarget) then
			text = "["..text.."]"
		end
		
		btn:SetText(text)
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

local function setWallClick(self)
	current_room.walls[self.dir] = not current_room.walls[self.dir]
	recolorRoom(current_room)
	updateWallButtonText()
end
   
local function initialize()

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

	local reset = ng:New(addonName, "Button", nil, mf)
	reset:SetPoint("BOTTOM", mf, "BOTTOM", -50, 10)
	reset:SetScript("OnClick", ResetMap)
	reset:SetText("Reset map")

	for i = 1,5 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 10, -20 * i)
		btn:SetSize(90, 18)
		btn.t = "rune"
		btn.c = i
		btn:SetScript("OnClick", setPOIClick)
		btn:SetText(color_strings[i].." Rune")

		btn = ng:New(addonName, "Button", nil, mf)
		btn:SetSize(90, 18)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 110, -20 * i)
		btn.t = "orb"
		btn.c = i
		btn:SetScript("OnClick", setPOIClick)
		btn:SetText(color_strings[i].." Orb")

		-- automatic waypoints maybe in future
	end

	-- Buttons to add/remove walls
	for i = 1,4 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn.dir = i
		btn:SetScript("OnClick", setWallClick)
		wall_buttons[i] = btn
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

	ResetMap()

	ly, lx = UnitPosition("player")

	mf:SetScript("OnUpdate", update)

	local hide = ng:New(addonName, "Button", nil, mf)
	hide:SetPoint("BOTTOM", mf, "BOTTOM", 50, 10)
	hide:SetScript("OnClick", function() mf:Hide() end)
	hide:SetText(CLOSE)
	
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
