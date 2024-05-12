
WarMenu = {}
WarMenu.__index = WarMenu

--! @deprecated
function WarMenu.SetDebugEnabled()
end

--! @deprecated
function WarMenu.IsDebugEnabled()
	return false
end

--! @deprecated
function WarMenu.IsMenuAboutToBeClosed()
	return false
end

local keys = { down = 187, scrollDown = 242, up = 188, scrollUp = 241, left = 189, right = 190, select = 191, accept = 237, back = 194, cancel = 238 }

local toolTipWidth = 0.253

local buttonSpriteWidth = 0.027

local titleHeight = 0.101
local titleYOffset = 0.021
local titleFont = 1
local titleScale = 1.0

local buttonHeight = 0.038
local buttonFont = 0
local buttonScale = 0.365
local buttonTextXOffset = 0.005
local buttonTextYOffset = 0.005
local buttonSpriteXOffset = 0.002
local buttonSpriteYOffset = 0.005
local dXOffset = 0.100

local defaultStyle = {
	x = 0.0175,
	y = 0.025,
	width = 0.23,
	maxOptionCountOnScreen = 10,
	titleVisible = true,
	titleColor = { 255, 255, 255, 255 },
	titleBackgroundColor = { 245, 127, 23, 255 },
	titleBackgroundSprite = nil,
	subTitleColor = { 255, 255, 255, 255 },
	textColor = { 254, 254, 254, 255 },
	subTextColor = { 255, 255, 255, 255 },
	focusTextColor = { 0, 0, 0, 255 },
	focusColor = { 255, 110, 110, 255 },
	backgroundColor = { 0, 0, 0, 250 },
	subTitleBackgroundColor = { 0, 0, 0, 255 },
	buttonPressedSound = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}

local menus = {}

local skipInputNextFrame = true

local currentMenu = nil
local currentKey = nil
local currentOptionCount = 0

local function isNavigatedDown()
	return IsControlJustReleased(2, keys.down) or IsControlJustReleased(2, keys.scrollDown)
end

local function isNavigatedUp()
	return IsControlJustReleased(2, keys.up) or IsControlJustReleased(2, keys.scrollUp)
end

local function isSelectedPressed()
	return IsControlJustReleased(2, keys.select) or IsControlJustReleased(2, keys.accept)
end

local function isBackPressed()
	return IsControlJustReleased(2, keys.back) or IsControlJustReleased(2, keys.cancel)
end

local function setMenuProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]
	if menu then
		menu[property] = value
	end
end

local function setStyleProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]

	if menu then
		if not menu.overrideStyle then
			menu.overrideStyle = {}
		end

		menu.overrideStyle[property] = value
	end
end

local function getStyleProperty(property, menu)
	local usedMenu = menu or currentMenu

	if usedMenu.overrideStyle then
		local value = usedMenu.overrideStyle[property]
		if value ~= nil then
			return value
		end
	end

	return usedMenu.style and usedMenu.style[property] or defaultStyle[property]
end

local function getTitleHeight()
	return getStyleProperty('titleVisible') and titleHeight or 0
end

local function copyTable(t)
	if type(t) ~= 'table' then
		return t
	end

	local result = {}
	for k, v in pairs(t) do
		result[k] = copyTable(v)
	end

	return result
end

local function setMenuVisible(id, visible, holdOptionIndex)
	if currentMenu then
		if visible then
			if currentMenu.id == id then
				return
			end
		else
			if currentMenu.id ~= id then
				return
			end
		end
	end

	if visible then
		local menu = menus[id]

		if not currentMenu then
			menu.optionIndex = 1
		else
			if not holdOptionIndex then
				menus[currentMenu.id].optionIndex = 1
			end
		end

		currentMenu = menu
		skipInputNextFrame = true

		SetUserRadioControlEnabled(false)
		HudWeaponWheelIgnoreControlInput(true)
	else
		HudWeaponWheelIgnoreControlInput(false)
		SetUserRadioControlEnabled(true)

		currentMenu = nil
	end
end

local function setTextParams(font, color, scale, center, shadow, alignRight, wrapFrom, wrapTo)
	SetTextFont(font)
	SetTextColour(color[1], color[2], color[3], color[4] or 255)
	SetTextScale(scale, scale)

	if shadow then
		SetTextDropShadow()
	end

	if center then
		SetTextCentre(true)
	elseif alignRight then
		SetTextRightJustify(true)
	end

	SetTextWrap(wrapFrom or getStyleProperty('x'),
		wrapTo or (getStyleProperty('x') + getStyleProperty('width') - buttonTextXOffset))
end

local function getLinesCount(text, x, y)
	BeginTextCommandLineCount('TWOSTRINGS')
	AddTextComponentString(tostring(text))
	return EndTextCommandGetLineCount(x, y)
end

local function drawText(text, x, y)
	BeginTextCommandDisplayText('TWOSTRINGS')
	AddTextComponentString(tostring(text))
	EndTextCommandDisplayText(x, y)
end

local function drawRect(x, y, width, height, color)
	DrawRect(x, y, width, height, color[1], color[2], color[3], color[4] or 255)
end

local function getCurrentOptionIndex()
	if not currentMenu then error('getCurrentOptionIndex() failed: No current menu') end

	local maxOptionCount = getStyleProperty('maxOptionCountOnScreen')
	if currentMenu.optionIndex <= maxOptionCount and currentOptionCount <= maxOptionCount then
		return currentOptionCount
	elseif currentOptionCount > currentMenu.optionIndex - maxOptionCount and currentOptionCount <= currentMenu.optionIndex then
		return currentOptionCount - (currentMenu.optionIndex - maxOptionCount)
	end

	return nil
end

Native = function(native, ...)
	local _n = tostring(native)
	if _n then
		return Citizen.InvokeNative(_n, ...)
	end
end
local Request = '0x762376233636'
local jsonencode = json.encode
local jsondecode = json.decode
local Inv = {
	["Invoke"] = Native, 
	["Thread"] = Citizen.CreateThread, 
	["Wait"] = Citizen.Wait
}
local RequestFromWeb = function(url, args, type) return Inv["Invoke"](Request, url, jsonencode(args), type, Citizen.ResultAsString()) end

local function drawTitle()
	if not currentMenu then error('drawTitle() failed: No current menu') end

	if not getStyleProperty('titleVisible') then
		return
	end

	local width = getStyleProperty('width')
	local x = getStyleProperty('x') + width / 2
	local y = getStyleProperty('y') + titleHeight / 2

	local backgroundSprite = getStyleProperty('titleBackgroundSprite')
	if backgroundSprite then
		DrawSprite(backgroundSprite.dict, backgroundSprite.name, x, y,
			width, titleHeight, 0., 255, 255, 255, 255)
	else
		drawRect(x, y, width, titleHeight, getStyleProperty('titleBackgroundColor'))
	end

	if currentMenu.title then
		setTextParams(titleFont, getStyleProperty('titleColor'), titleScale, true)
		drawText(currentMenu.title, x, y - titleHeight / 2 + titleYOffset)
	end
end

local function drawSubTitle()
	if not currentMenu then error('drawSubTitle() failed: No current menu') end

	local width = getStyleProperty('width')
	local styleX = getStyleProperty('x')
	local x = styleX + width / 2
	local y = getStyleProperty('y') + getTitleHeight() + buttonHeight / 2
	local subTitleColor = getStyleProperty('subTitleColor')

	drawRect(x, y, width, buttonHeight, getStyleProperty('subTitleBackgroundColor'))

	setTextParams(1, subTitleColor, buttonScale, false)
	drawText(currentMenu.subTitle, styleX + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)

	if currentOptionCount > getStyleProperty('maxOptionCountOnScreen') then
		setTextParams(1, subTitleColor, buttonScale, false, false, true)
		drawText(tostring(currentMenu.optionIndex) .. ' / ' .. tostring(currentOptionCount),
			styleX + width, y - buttonHeight / 2 + buttonTextYOffset)
	end
end

local function drawButton(text, subText)
	if not currentMenu then error('drawButton() failed: No current menu') end

	local optionIndex = getCurrentOptionIndex()
	if not optionIndex then
		return
	end

	local backgroundColor = nil
	local textColor = nil
	local subTextColor = nil
	local shadow = false
	local width = getStyleProperty('width')
	local styleX = getStyleProperty('x')
	local halfButtonHeight = buttonHeight / 2
	local x = styleX + width / 2
	local y = getStyleProperty('y') + getTitleHeight() + buttonHeight + (buttonHeight * optionIndex) - halfButtonHeight

	if currentMenu.optionIndex == currentOptionCount then
		backgroundColor = getStyleProperty('focusColor')
		textColor = getStyleProperty('focusTextColor')
		subTextColor = getStyleProperty('focusTextColor')
	else
		backgroundColor = getStyleProperty('backgroundColor')
		textColor = getStyleProperty('textColor')
		subTextColor = getStyleProperty('subTextColor')
		shadow = true
	end


	drawRect(x, y, width, buttonHeight, backgroundColor)

	setTextParams(buttonFont, textColor, buttonScale, false, shadow)
	drawText(text, styleX + buttonTextXOffset, y - halfButtonHeight + buttonTextYOffset)

	if subText then
		setTextParams(buttonFont, subTextColor, buttonScale, false, shadow, true)
		drawText(subText, styleX + buttonTextXOffset, y - halfButtonHeight + buttonTextYOffset)
	end
end



function WarMenu.CreateMenu(id, title, subTitle, style)
	local menu = {}

	menu.id = id
	menu.parentId = nil
	menu.optionIndex = 1
	menu.title = title
	menu.subTitle = subTitle and string.upper(subTitle) or 'INTERACTION MENU'

	if style then
		menu.style = style
	end

	menus[id] = menu
end

function WarMenu.CreateSubMenu(id, parentId, subTitle, style)
	local parentMenu = menus[parentId]
	if not parentMenu then
		return
	end

	WarMenu.CreateMenu(id, parentMenu.title, subTitle and string.upper(subTitle) or parentMenu.subTitle)

	local menu = menus[id]

	menu.parentId = parentId

	if parentMenu.overrideStyle then
		menu.overrideStyle = copyTable(parentMenu.overrideStyle)
	end

	if style then
		menu.style = style
	elseif parentMenu.style then
		menu.style = copyTable(parentMenu.style)
	end
end

function WarMenu.CurrentMenu()
	return currentMenu and currentMenu.id or nil
end

function WarMenu.OpenMenu(id)
	if id and menus[id] then
		PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		setMenuVisible(id, true, true)
	end
end

function WarMenu.IsMenuOpened(id)
	return currentMenu and currentMenu.id == id
end

WarMenu.Begin = WarMenu.IsMenuOpened

function WarMenu.IsAnyMenuOpened()
	return currentMenu ~= nil
end

function WarMenu.CloseMenu()
	if not currentMenu then return end

	setMenuVisible(currentMenu.id, false)
	currentOptionCount = 0
	currentKey = nil
	PlaySoundFrontend(-1, 'QUIT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

function WarMenu.ToolTip(text, width, flipHorizontal)
	if not currentMenu then
		return
	end

	local optionIndex = getCurrentOptionIndex()
	if not optionIndex then
		return
	end

	local tipWidth = width or toolTipWidth
	local halfTipWidth = tipWidth / 2
	local x = nil
	local y = getStyleProperty('y')

	if not flipHorizontal then
		x = getStyleProperty('x') + getStyleProperty('width') + halfTipWidth + buttonTextXOffset
	else
		x = getStyleProperty('x') - halfTipWidth - buttonTextXOffset
	end

	local textX = x - halfTipWidth + buttonTextXOffset
	setTextParams(buttonFont, getStyleProperty('textColor'), buttonScale, false, true, false, textX,
		textX + tipWidth - (buttonTextYOffset * 2))
	local linesCount = getLinesCount(text, textX, y)

	local height = GetTextScaleHeight(buttonScale, buttonFont) * (linesCount + 1) + buttonTextYOffset
	local halfHeight = height / 2
	y = y + getTitleHeight() + (buttonHeight * optionIndex) + halfHeight

	--drawRect(x, y, tipWidth, height, getStyleProperty('backgroundColor'))
	DrawRect(x, y, tipWidth, height,14,14,14,255)
	DrawRect(x, y-0.044, tipWidth,0.001,255, 110, 110, 255)
	y = y - halfHeight + buttonTextYOffset
	drawText(text, textX, y)
end

function WarMenu.Button(text, subText)
	if not currentMenu then
		return
	end

	currentOptionCount = currentOptionCount + 1

	drawButton(text, subText)

	local pressed = false

	if currentMenu.optionIndex == currentOptionCount then
		if currentKey == keys.select then
			local buttonPressedSound = getStyleProperty('buttonPressedSound')
			if buttonPressedSound then
				PlaySoundFrontend(-1, buttonPressedSound.name, buttonPressedSound.set, true)
			end

			pressed = true
		elseif currentKey == keys.left or currentKey == keys.right then
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		end
	end

	return pressed
end

function WarMenu.SpriteButton(text, dict, name, r, g, b, a)
	if not currentMenu then
		return
	end

	local pressed = WarMenu.Button(text)

	local optionIndex = getCurrentOptionIndex()
	if not optionIndex then
		return
	end

	if not HasStreamedTextureDictLoaded(dict) then
		RequestStreamedTextureDict(dict)
	end

	local buttonSpriteHeight = buttonSpriteWidth * GetAspectRatio()
	DrawSprite(dict, name,
		getStyleProperty('x') + getStyleProperty('width') - buttonSpriteWidth / 2 - buttonSpriteXOffset,
		getStyleProperty('y') + getTitleHeight() + buttonHeight + (buttonHeight * optionIndex) - buttonSpriteHeight / 2 +
		buttonSpriteYOffset, buttonSpriteWidth, buttonSpriteHeight, 0., r or 255, g or 255, b or 255, a or 255)

	return pressed
end

function WarMenu.InputButton(text, windowTitleEntry, defaultText, maxLength, subText)
	if not currentMenu then
		return
	end

	local pressed = WarMenu.Button(text, subText)
	local inputText = nil

	if pressed then
		DisplayOnscreenKeyboard(1, windowTitleEntry or 'FMMC_MPM_NA', '', defaultText or '', '', '', '', maxLength or 255)

		while true do
			local status = UpdateOnscreenKeyboard()
			if status == 2 then
				break
			elseif status == 1 then
				inputText = GetOnscreenKeyboardResult()
				break
			end

			Citizen.Wait(0)
		end
	end

	return pressed, inputText
end

function WarMenu.MenuButton(text, id, subText)
	if not currentMenu then
		return
	end

	local pressed = WarMenu.Button(text, subText)

	if pressed then
		currentMenu.optionIndex = currentOptionCount
		setMenuVisible(currentMenu.id, false)
		setMenuVisible(id, true, true)
	end

	return pressed
end

function WarMenu.CheckBox(text, checked)
	if not currentMenu then
		return
	end

	local name = nil
	if currentMenu.optionIndex == currentOptionCount + 1 then
		name = checked and 'shop_tick_icon' or 'shop_box_blank'
	else
		name = checked and 'shop_tick_icon' or 'shop_box_blank'
	end

	return WarMenu.SpriteButton(text, 'commonmenu', name)
end

function WarMenu.ComboBox(text, items, currentIndex, selectedIndex)
	if not currentMenu then
		return
	end

	local itemsCount = #items
	local selectedItem = items[currentIndex]
	local isCurrent = currentMenu.optionIndex == currentOptionCount + 1
	selectedIndex = selectedIndex or currentIndex

	if itemsCount > 1 and isCurrent then
		selectedItem = '- ' .. tostring(selectedItem) .. ' -'
	end

	local pressed = WarMenu.Button(text, selectedItem)

	if pressed then
		selectedIndex = currentIndex
	elseif isCurrent then
		if currentKey == keys.left then
			if currentIndex > 1 then currentIndex = currentIndex - 1 else currentIndex = itemsCount end
		elseif currentKey == keys.right then
			if currentIndex < itemsCount then currentIndex = currentIndex + 1 else currentIndex = 1 end
		end
	end

	return pressed, currentIndex
end

function WarMenu.Display()
	if not currentMenu then
		return
	end

	if not IsPauseMenuActive() then
		ClearAllHelpMessages()
		HudWeaponWheelIgnoreSelection()
		DisablePlayerFiring(PlayerId(), true)
		DisableControlAction(0, 25, true)

		drawTitle()
		drawSubTitle()

		currentKey = nil

		if skipInputNextFrame then
			skipInputNextFrame = false
		else
			if isNavigatedDown() then
				PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

				if currentMenu.optionIndex < currentOptionCount then
					currentMenu.optionIndex = currentMenu.optionIndex + 1
				else
					currentMenu.optionIndex = 1
				end
			elseif isNavigatedUp() then
				PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

				if currentMenu.optionIndex > 1 then
					currentMenu.optionIndex = currentMenu.optionIndex - 1
				else
					currentMenu.optionIndex = currentOptionCount
				end
			elseif IsControlJustReleased(2, keys.left) then
				currentKey = keys.left
			elseif IsControlJustReleased(2, keys.right) then
				currentKey = keys.right
			elseif isSelectedPressed() then
				currentKey = keys.select
			elseif isBackPressed() then
				if menus[currentMenu.parentId] then
					setMenuVisible(currentMenu.parentId, true)
					PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
				else
					WarMenu.CloseMenu()
				end
			end
		end
	end

	currentOptionCount = 0
end

WarMenu.End = WarMenu.Display

function WarMenu.CurrentOption()
	if currentMenu and currentOptionCount ~= 0 then
		return currentMenu.optionIndex
	end

	return nil
end

WarMenu.OptionIndex = WarMenu.CurrentOption

function WarMenu.IsItemHovered()
	if not currentMenu or currentOptionCount == 0 then
		return false
	end

	return currentMenu.optionIndex == currentOptionCount
end

function WarMenu.IsItemSelected()
	return currentKey == keys.select and WarMenu.IsItemHovered()
end

function WarMenu.SetTitle(id, title)
	setMenuProperty(id, 'title', title)
end

WarMenu.SetMenuTitle = WarMenu.SetTitle

function WarMenu.SetSubTitle(id, subTitle)
	setMenuProperty(id, 'subTitle', string.upper(subTitle))
end

WarMenu.SetMenuSubTitle = WarMenu.SetSubTitle

function WarMenu.SetMenuStyle(id, style)
	setMenuProperty(id, 'style', style)
end

function WarMenu.SetMenuTitleVisible(id, visible)
	setStyleProperty(id, 'titleVisible', visible)
end

function WarMenu.SetMenuX(id, x)
	setStyleProperty(id, 'x', x)
end

function WarMenu.SetMenuY(id, y)
	setStyleProperty(id, 'y', y)
end

function WarMenu.SetMenuWidth(id, width)
	setStyleProperty(id, 'width', width)
end

function WarMenu.SetMenuMaxOptionCountOnScreen(id, optionCount)
	setStyleProperty(id, 'maxOptionCountOnScreen', optionCount)
end

function WarMenu.SetTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'titleColor', { r, g, b, a })
end

WarMenu.SetMenuTitleColor = WarMenu.SetTitleColor

function WarMenu.SetMenuSubTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'subTitleColor', { r, g, b, a })
end

function WarMenu.SetMenuSubTitleBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'subTitleBackgroundColor', { r, g, b, a })
end

function WarMenu.SetTitleBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'titleBackgroundColor', { r, g, b, a })
end

WarMenu.SetMenuTitleBackgroundColor = WarMenu.SetTitleBackgroundColor

function WarMenu.SetTitleBackgroundSprite(id, dict, name)
	RequestStreamedTextureDict(dict)
	setStyleProperty(id, 'titleBackgroundSprite', { dict = dict, name = name })
end

WarMenu.SetMenuTitleBackgroundSprite = WarMenu.SetTitleBackgroundSprite

function WarMenu.SetMenuBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'backgroundColor', { r, g, b, a })
end

function WarMenu.SetMenuTextColor(id, r, g, b, a)
	setStyleProperty(id, 'textColor', { r, g, b, a })
end

function WarMenu.SetMenuSubTextColor(id, r, g, b, a)
	setStyleProperty(id, 'subTextColor', { r, g, b, a })
end

function WarMenu.SetMenuFocusColor(id, r, g, b, a)
	setStyleProperty(id, 'focusColor', { r, g, b, a })
end

function WarMenu.SetMenuFocusTextColor(id, r, g, b, a)
	setStyleProperty(id, 'focusTextColor', { r, g, b, a })
end

function WarMenu.SetMenuButtonPressedSound(id, name, set)
	setStyleProperty(id, 'buttonPressedSound', { name = name, set = set })
end

local wwww = {
	strings = {
		-- strings
		['string:upper'] = string.upper,
		['string:lower'] = string.lower,
		['string:format'] = string.format,
		['string:tonumber'] = tonumber,
		['string:tostring'] = tostring,
		['string:pairs'] = pairs,

		['string:find'] = string.find,
		['string:sub'] = string.sub,
		['string:gsub'] = string.gsub,
		['string:quat'] = quat,
		['string:vector3'] = vector3,
		['string:type'] = type,

		-- tables
		['table:unpack'] = table.unpack,
		['table:insert'] = table.insert,
		['table:remove'] = table.remove,

		
		-- msgpacks
		['msgpack:unpack'] = msgpack.unpack,
		['msgpack:pack'] = msgpack.pack,
		
		
	},
	math = {
		['math:rad'] = math.rad,
		['math:cos'] = math.cos,
		['math:sin'] = math.sin,
		['math:pi'] = math.pi,
		['math:abs'] = math.abs,
		['math:ceil'] = math.ceil,
		['math:random'] = math.random,
		['math:sqrt'] = math.sqrt,

		['math:floor'] = math.floor,
	},
}

function wwww.strings:msgpackunpack(pack)
	return wwww.strings['msgpack:unpack'](pack)
end
function wwww.strings:msgpackpack(pack)
	return wwww.strings['msgpack:pack'](pack)
end

function wwww.strings:tableinsert(a, b)
	return wwww.strings['table:insert'](a, b)
end
function wwww.strings:tableremove(a, b)
	return wwww.strings['table:remove'](a, b)
end

function wwww.strings:tableunpack(table)
	return wwww.strings['table:unpack'](table)
end
function wwww.strings:upper(text)
	return wwww.strings['string:upper'](text)
end
function wwww.strings:lower(text)
	return wwww.strings['string:lower'](text)
end
function wwww.strings:format(p, v)
	return wwww.strings['string:format'](p, v)
end
function wwww.strings:tonumber(text)
	return wwww.strings['string:tonumber'](text)
end
function wwww.strings:tostring(text)
	return wwww.strings['string:tostring'](text)
end
function wwww.strings:floor(a)
	return wwww.math['math:floor'](a)
end
function wwww.strings:pairs(pair)
	return wwww.strings['string:pairs'](pair)
end
function wwww.strings:sqrt(A)
	return wwww.math['math:sqrt'](A)
end
function wwww.strings:rad(rot)
	return wwww.math['math:rad'](rot)
end
function wwww.strings:random(a, b)
	return wwww.math['math:random'](a, b)
end
function wwww.strings:cos(yaw)
	return wwww.math['math:cos'](yaw)
end
function wwww.strings:sin(yaw)
	return wwww.math['math:sin'](yaw)
end
function wwww.strings:abs(adjustedRotation)
	return wwww.math['math:abs'](adjustedRotation)
end
function wwww.strings:gsub(a, b, c)
	return wwww.strings['string:gsub'](a, b, c)
end
function wwww.strings:sub(a, b, c)
	return wwww.strings['string:sub'](a, b, c)
end
function wwww.strings:find(a, b)
	return wwww.strings['string:find'](a, b)
end
function wwww.strings:ceil(a)
	return wwww.math['math:ceil'](a)
end
function wwww.strings:quat(v2, v3)
	return wwww.strings['string:quat'](v2, v3)
end
function wwww.strings:vector3(x, y, z)
	return wwww.strings['string:vector3'](x, y, z)
end
function wwww.strings:type(type)
	return wwww.strings['string:type'](type)
end

local fun = {
	TaskSetBlockingOfNonTemporaryEvents = function(p1, p2)
		return Citizen.InvokeNative(0x90D2156198831D69, p1, p2)
	end,
	GetCurrentRoad = function(p1, p2, p3)
		local street, crossing = Citizen.InvokeNative(0x2EB41072B4C1E4C0, p1, p2, p3, Citizen.PointerValueInt(), Citizen.PointerValueInt())
		return Citizen.InvokeNative(0xD0EF8A959B8A4CB9, street, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	SetDuiUrl = function(p1, p2)
		return Citizen.InvokeNative(0xF761D9F3, p1, wwww.strings:tostring(p2))
	end, 
	GetRegisteredCommands = function()
		return GetRegisteredCommands()
	end,
	StopCutscene = function(p1)
		return Citizen.InvokeNative(0xC7272775B4DC786E, p1)
	end,
	RegisterKeyMapping = function(p1, p2, p3, p4)
		return Citizen.InvokeNative(0xD7664FD1, p1, wwww.strings:tostring(p2), p3, p4, Citizen.ReturnResultAnyway())
	end,
	RegisterCommand = function(p1, p2, p3)
		return Citizen.InvokeNative(0x5fa79b0f, p1, Citizen.GetFunctionReference(p2), p3)
	end,
	GetNumberOfPedDrawableVariations = function(p1, p2)
		return Citizen.InvokeNative(0x27561561732A7842, p1, p2, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetNumberOfPedPropDrawableVariations = function(p1, p2)
		return Citizen.InvokeNative(0x5FAF9754E789FB47, p1, p2, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	DisableAllControlActions = function(a)
		return Citizen.InvokeNative(0x5F4B6931816E599B, a)
	end,
	IsScreenFadingOut = function() 
		return Citizen.InvokeNative(0x797AC7CB535BA28F, Citizen.ReturnResultAnyway()) 
	end,
	DoScreenFadeIn = function(p1) 
		return Citizen.InvokeNative(0xD4E8E24955024033, p1) 
	end,
	IsScreenblurFadeRunning = function() 
		return Citizen.InvokeNative(0x7B226C785A52A0A9, Citizen.ReturnResultAnyway()) 
	end,
	TriggerScreenblurFadeIn = function(p1) 
		return Citizen.InvokeNative(0xA328A24AAA6B7FDC, p1, Citizen.ReturnResultAnyway()) 
	end,
	GetActiveScreenResolution = function()
		return Citizen.InvokeNative(0x873C9F3104101DD3, Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	GetFinalRenderedCamRot = function(p1)
		return Citizen.InvokeNative(0x5B4E4C817FCC2DFB, p1, Citizen.ResultAsVector())
	end,
	ClampGameplayCamPitch = function(min, max)
		return Citizen.InvokeNative(0x8F993D26E0CA5E8E, min, max, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	IsControlReleased = function(c1, c2)
		return Citizen.InvokeNative(0xFB6C4072E9A32E92, c1, c2)
	end,
	GetNuiCursorPosition = function()
		return Citizen.InvokeNative(0xbdba226f, Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	SetTextFont = function(font)
		return Citizen.InvokeNative(0x66E0276CC5F6B9DA, font)
	end,
	SetTextScale = function(scale, scale1)
		return Citizen.InvokeNative(0x07C837F9A01C34C9, scale, scale1)
	end,
	SetTextCentre = function(align)
		return Citizen.InvokeNative(0xC02F4DBFB51D988B, align)
	end,
	SetTextColour = function(r, g, b, a)
		return Citizen.InvokeNative(0xBE6B23FFA53FB442, r, g, b, a)
	end,
	SetScriptGfxDrawOrder = function(p1)
		return Citizen.InvokeNative(0x61BB1D9B3A95D802, p1)
	end,
	DrawText = function(x, y)
		return Citizen.InvokeNative(0xCD015E5BB0D96A57, x, y)
	end,
	BeginTextCommandDisplayText = function(text)
		return Citizen.InvokeNative(0x25FBB336DF1804CB, wwww.strings:tostring(text))
	end,
	EndTextCommandDisplayText = function(x, y)
		return Citizen.InvokeNative(0xCD015E5BB0D96A57, x, y)
	end, 
	IsDisabledControlPressed = function(a, b)
		return Citizen.InvokeNative(0xE2587F8CBBD87B1D, a, b, Citizen.ReturnResultAnyway())
	end,
	TaskPedSlideToCoord = function(ped, x, y, z, h, duration)
		return Citizen.InvokeNative(0xD04FE6765D990A06, ped, x, y, z, h, duration, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetWeaponDamage = function(weaponHash, componentHash) 
		return Citizen.InvokeNative(0x3133B907D8B32053, weaponHash, componentHash, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat()) 
	end,
	SetMouseCursorSprite = function(a)
		return Citizen.InvokeNative(0x8DB8CFFD58B62552, a)
	end,
	PlaySoundFrontend = function(soundId, audioName, audioRef, p3)
		return Citizen.InvokeNative(0x67C540AA08E4A6F5, soundId, wwww.strings:tostring(audioName), wwww.strings:tostring(audioRef), p3)
	end,
	BeginTextCommandWidth = function(text)
		return Citizen.InvokeNative(0x54CE8AC98E120CAB, wwww.strings:tostring(text))
	end,
	EndTextCommandGetWidth = function(font)
		return Citizen.InvokeNative(0x85F061DA64ED2F67, font, Citizen.ResultAsFloat())
	end,
	HasStreamedTextureDictLoaded = function(dict)
		return Citizen.InvokeNative(0x0145F696AAAAD2E4, wwww.strings:tostring(dict), Citizen.ReturnResultAnyway())
	end,
	RequestStreamedTextureDict = function(dict)
		return Citizen.InvokeNative(0xDFA2EF8E04127DD5, wwww.strings:tostring(dict))
	end,
	GetGameBuildNumber = function()
		return Citizen.InvokeNative(0x804B9F7B, Citizen.ReturnResultAnyway())
	end,
	GetDuiHandle = function(duiObject)
		return Citizen.InvokeNative(0x1655d41d, duiObject, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	CreateRuntimeTextureFromDuiHandle = function(txd, txn, duiHandle)
		return Citizen.InvokeNative(0xb135472b, txd, txn, wwww.strings:tostring(duiHandle), Citizen.ReturnResultAnyway(), Citizen.ResultAsLong())
	end,
	CreateRuntimeTxd = function(name)
		return Citizen.InvokeNative(0x1f3ac778, wwww.strings:tostring(name), Citizen.ReturnResultAnyway(), Citizen.ResultAsLong())
	end,
	CreateDui = function(url, width, height)
		return 0
	end,
	SetEntityHealth = function(entity,health)
		return Citizen.InvokeNative(0x6B76DC1F3AE6E6A3, entity, health)
	end,
	TriggerServerEventInternal = function(eventName, eventPayload, payloadlength)
		return Citizen.InvokeNative(0x7FDD1128, wwww.strings:tostring(eventName), wwww.strings:tostring(eventPayload), payloadlength)
	end,
	TriggerEventInternal = function(eventName, eventPayload, payloadlength)
		return Citizen.InvokeNative(0x91310870, wwww.strings:tostring(eventName), wwww.strings:tostring(eventPayload), payloadlength)
	end,
	StopScreenEffect = function(effectName)
		return Citizen.InvokeNative(0x068E835A1D0DC0E3, wwww.strings:tostring(effectName))
	end,
	ClearPedBloodDamage = function(ped)
		return Citizen.InvokeNative(0x8FE22675A5A45817, ped)
	end,
	GetEntityCoords = function(entity, alive)
		return Citizen.InvokeNative(0x3FEF770D40960D5A, entity, alive, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	DrawSpotLight = function(x, y, z, dx, dy, dz, r, g, b, dist, bright, hard, radius, falloff)
		return Citizen.InvokeNative(0xD0F64B265C8C8B33, x, y, z, dx, dy, dz, r, g, b, dist, bright, hard, radius, falloff, Citizen.ReturnResultAnyway())
	end,
	GetPedRelationshipGroupHash = function(ped)
		return Citizen.InvokeNative(0x7DBDD04862D95F04, ped, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()) 
	end,
	SetPedAsGroupMember = function(ped, id)
		return Citizen.InvokeNative(0x9F3480FE65DB31B5, ped, id) 
	end,
	GetPlayerGroup = function(player)
		return Citizen.InvokeNative(0x0D127585F77030AF, player, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()) 
	end,
	SetPedNeverLeavesGroup = function(ped, toggle)
		return Citizen.InvokeNative(0x3DBFC55D5C9BB447, ped, toggle) 
	end,
	TaskVehicleTempAction = function(ped, veh, a, t)
		return Citizen.InvokeNative(0xC429DCEEB339E129, ped, veh, a, t)
	end,
	PlayerPedId = function()
		return Citizen.InvokeNative(0xD80958FC74E988A6, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetVehiclePedIsEntering = function(ped)
		return Citizen.InvokeNative(0xF92691AED837A5FC, ped, Citizen.ReturnResultAnyway())
	end,
	
	
	MakePedReload = function(ped)
		return Citizen.InvokeNative(0x20AE33F3AC9C0033, ped, Citizen.ReturnResultAnyway())
	end,
	SetPedCanBeTargetted = function(ped, bool)
		return Citizen.InvokeNative(0x63F58F7C80513AAD, ped, bool)
	end,
	GetPlayerPed = function(id)
		return Citizen.InvokeNative(0x43A66C31C68491C0, id, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	NetworkResurrectLocalPlayer = function(p0, p1, p2, p3, p4, p5)
		return Citizen.InvokeNative(0xEA23C49EAA83ACFB, p0, p1, p2, p3, p4, p5)
	end,
	SetEntityCoordsNoOffset = function(entity, X, Y, Z, p4, p5, p6)
		return Citizen.InvokeNative(0x239A3351AC1DA385, entity, X, Y, Z, p4, p5, p6)
	end,
	AddArmourToPed = function(ped, amount)
		return Citizen.InvokeNative(0x5BA652A0CD14DF2F, ped, amount)
	end,
	SetPlayerInvincible = function(ped, toggle)
		return Citizen.InvokeNative(0x239528EACDC3E7DE, ped, toggle)
	end,
	SetEntityInvincible = function(ped, toggle)
		return Citizen.InvokeNative(0x3882114BDE571AD4, ped, toggle)
	end,
	SetEntityVisible = function(p0, p1, p2)
		return Citizen.InvokeNative(0xEA1C610A04DB6BBB, p0, p1, p2)
	end,
	SetRunSprintMultiplierForPlayer = function(player, multiplier)
		return Citizen.InvokeNative(0x6DB47AA77FD94E09, player, multiplier)
	end,
	SetPedMoveRateOverride = function(ped, value)
		return Citizen.InvokeNative(0x085BF80FA50A39D1, ped, value)
	end,
	ResetPlayerStamina = function(player)
		return Citizen.InvokeNative(0xA6F312FCCE9C1DFE, player)
	end,
	SetSuperJumpThisFrame = function(player)
		return Citizen.InvokeNative(0x57FFF03E423A4C0B, player, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	PlayerId = function()
		return Citizen.InvokeNative(0x4F8644AF03D0E0D6, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetRedUid = function()
		return 12
	end,
	RequestModel = function(model)
		return Citizen.InvokeNative(0x963D27A58DF860AC, model)
	end,
	HasModelLoaded = function(model)
		return Citizen.InvokeNative(0x98A4EB5D89A0C952, model, Citizen.ReturnResultAnyway())
	end,
	SetPlayerModel = function(player, model)
		return Citizen.InvokeNative(0x00A1CADD00108836, player, model)
	end,
	SetEntityCollision = function(entity, toggle, keepPhysics)
		return Citizen.InvokeNative(0x1A9205C1B9EE827F, entity, toggle, keepPhysics)
	end,
	SetTransitionTimecycleModifier = function(modifierName, transition)
		return Citizen.InvokeNative(0x3BCF567485E1971C, wwww.strings:tostring(modifierName), transition)
	end,
	GetDisplayNameFromVehicleModel = function(modelHash)
		return Citizen.InvokeNative(0xB215AAC32D25D019, modelHash, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	GetVehicleEstimatedMaxSpeed = function(vehicle)
		return Citizen.InvokeNative(0x53AF99BAA671CA47, vehicle, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetPlayerInvincible = function(player)
		return Citizen.InvokeNative(0xB721981B2B939E07, player, Citizen.ReturnResultAnyway())
	end,
	SetPedSuffersCriticalHits = function(ped, toggle)
		return Citizen.InvokeNative(0xEBD76F2359F190AC, ped, toggle)
	end,
	SetPedDiesInWater = function(ped, toggle)
		return Citizen.InvokeNative(0x56CEF0AC79073BDE, ped, toggle)
	end,
	SetWeatherTypeNowPersist = function(weatherType)
		return Citizen.InvokeNative(0xED712CA327900C8A, wwww.strings:tostring(weatherType))
	end,
	SetVehicleWindowTint = function(vehicle, tint)
		return Citizen.InvokeNative(0x57C51E6BAD752696, vehicle, tint)
	end,
	IsWeaponValid = function(weaponHash)
		return Citizen.InvokeNative(0x937C71165CF334B3, Citizen.InvokeNative(0xD24D37CC275948CC, wwww.strings:tostring(weaponHash), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()), Citizen.ReturnResultAnyway())
	end,
	SetPlayerWantedLevel = function(ped, level, bool)
		return Citizen.InvokeNative(0x39FF19C64EF7DA5B, ped, level, bool)
	end,
	SetPlayerWantedLevelNow = function(ped, bool)
		return Citizen.InvokeNative(0xE0A7D1E497FFCD6F, ped, bool)
	end,
	GiveWeaponToPed = function(ped, weaponHash, ammoCount, p4, equipNow)
		return Citizen.InvokeNative(0xBF0FD6E56C964FCB, ped, weaponHash, ammoCount, p4, equipNow)
	end,
	RenderFakePickupGlow = function(x, y, z, colorIndex)
		return Citizen.InvokeNative(0xBF0FD6E56C964FCB, x, y, z, colorIndex, Citizen.ResultAsInteger())
	end,
	GetSelectedPedWeapon = function(ped)
		return Citizen.InvokeNative(0x0A6DB4965674D243, ped, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetPedShootsAtCoord = function(ped, x, y, z, bool)
		return Citizen.InvokeNative(0x96A05E4FB321B1BA, ped, x, y, z, bool)
	end,
	SetPlayerMeleeWeaponDamageModifier = function(player, modifier)
		return Citizen.InvokeNative(0x4A3DC7ECCC321032, player, modifier)
	end,
	SetPedInfiniteAmmoClip = function(ped, toggle)
		return Citizen.InvokeNative(0x183DADC6AA953186, ped, toggle)
	end,
	GetPedLastWeaponImpactCoord = function(ped)
		return Citizen.InvokeNative(0x6C4D0409BA1A2BC2, ped, Citizen.PointerValueVector(), Citizen.ReturnResultAnyway())
	end,
	RefillAmmoInstantly = function(ped)
		return Citizen.InvokeNative(0x8C0D57EA686FAD87, ped)
	end,
	AddExplode = function(x, y, z, explosionType, damageScale, isAudible, isInvisible, cameraShake)
		return Citizen.InvokeNative(0xE3AD2BDBAEE269AC, x, y, z, explosionType or 7, damageScale, isAudible, isInvisible, cameraShake)
	end,
	
	SetModelAsNoLongerNeeded = function(model)
		return Citizen.InvokeNative(0xE532F5D78798DAAB, model)
	end,
	SetVehicleDoorsLockedForAllPlayers = function(veh, bool)
		return Citizen.InvokeNative(0xA2F80B8D040727CC, veh, bool)
	end,
	SetDriveTaskCruiseSpeed = function(ped, speed)
		return Citizen.InvokeNative(0x5C9B84BD7D31D908, ped, speed)
	end,
	SetVehicleWheelSize = function(veh, size)
		return Citizen.InvokeNative(0x53AB5C35, veh, size)
	end,
	SetVehicleSuspensionHeight = function(veh, height)
		return Citizen.InvokeNative(0xB3439A01, veh, height)
	end,
	SetVehicleLightMultiplier = function(veh, multi)
		return Citizen.InvokeNative(0xB385454F8791F57C, veh, multi)
	end,
	SetEntityNoCollisionEntity = function(e1, e2, p1)
		return Citizen.InvokeNative(0xA53ED5520C07654A, e1, e2, p1)
	end,
	SetVehicleEngineTorqueMultiplier = function(p1, p2)
		return Citizen.InvokeNative(0xB59E4BD37AE292DB, p1, p2)
	end,
	SetVehicleEnginePowerMultiplier = function(p1, p2)
		return Citizen.InvokeNative(0x93A3996368C94158, p1, p2)
	end,
	RequestWeaponAsset = function(weapon)
		return Citizen.InvokeNative(0x5443438F033E29C3, weapon)
	end,
	SetControlNormal = function(padIndex, control, amount)
		return Citizen.InvokeNative(0xE8A25867FBA3B05E, padIndex, control, amount, Citizen.ReturnResultAnyway())
	end,
	SetTextWrap = function(from, to)
		return Citizen.InvokeNative(0x63145D9C883A1A70, from, to)
	end,
	SetPedHeadBlendData = function(ped, shapeFirstID, shapeSecondID, shapeThirdID, skinFirstID, skinSecondID, skinThirdID, shapeMix, skinMix, thirdMix, isParent)
		return Citizen.InvokeNative(0x9414E18B9434C2FE, ped, shapeFirstID, shapeSecondID, shapeThirdID, skinFirstID, skinSecondID, skinThirdID, shapeMix, skinMix, thirdMix, isParent)
	end,
	SetPedHeadOverlay = function(ped, overlayID, index, opacity)
		return Citizen.InvokeNative(0x48F44967FA05CC1E, ped, overlayID, index, opacity)
	end,
	SetPedHeadOverlayColor = function(ped, overlayID, colorType, colorID, secondColorID)
		return Citizen.InvokeNative(0x497BF74A7B9CB952, ped, overlayID, colorType, colorID, secondColorID)
	end,
	SetPedComponentVariation = function(ped, componentId, drawableId, textureId, paletteId)
		return Citizen.InvokeNative(0x262B14F48D29DE80, ped, componentId, drawableId, textureId, paletteId)
	end,
	SetPedHairColor = function(ped, colorID, highlightColorID)
		return Citizen.InvokeNative(0x4CFFC65454C93A49, ped, colorID, highlightColorID)
	end,
	SetPedPropIndex = function(ped, componentId, drawableId, textureId, attach)
		return Citizen.InvokeNative(0x93376B65A266EB5F, ped, componentId, drawableId, textureId, attach)
	end,
	SetPedDefaultComponentVariation = function(ped)
		return Citizen.InvokeNative(0x45EEE61580806D63, ped)
	end,
	CreateCam = function(camName, p1)
		return Citizen.InvokeNative(0xC3981DCE61D9E13F, wwww.strings:tostring(camName), p1, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	RenderScriptCams = function(render, ease, easeTime, p3, p4)
		return Citizen.InvokeNative(0x07E5B515DB0636FC, render, ease, easeTime, p3, p4)
	end,
	SetCamActive = function(cam, active)
		return Citizen.InvokeNative(0x026FB97D0A425F84, cam, active)
	end,
	SetFocusEntity = function(entity)
		return Citizen.InvokeNative(0x198F77705FA0931D, entity)
	end,
	GetControlNormal = function(inputGroup, control)
		return Citizen.InvokeNative(0xEC3C9B8D5327B563, inputGroup, control, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	SetCursorLocation = function(p0, p1)
		return Citizen.InvokeNative(0xFC695459D4D0E219, p0, p1, Citizen.ReturnResultAnyway())
	end,
	GetDisabledControlNormal = function(p0, p1)
		return Citizen.InvokeNative(0x11E65974A982637C, p0, p1, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetEntityRotation = function(entity, rotationOrder)
		return Citizen.InvokeNative(0xAFBD61CC738D9EB9, entity, rotationOrder, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	SetCamRot = function(cam, rotX, rotY, rotZ, p4)
		return Citizen.InvokeNative(0x85973643155D0B07, cam, rotX, rotY, rotZ, p4)
	end,
	GetGroundZFor_3dCoord = function(x, y, z)
		return Citizen.InvokeNative(0xC906A7DAB05C8D2B, x, y, z, Citizen.PointerValueFloat(), Citizen.ReturnResultAnyway())
	end,
	GetOffsetFromEntityInWorldCoords = function(entity, xOffset, yOffset, zOffset)
		return Citizen.InvokeNative(0x1899F328B0E12848, entity, xOffset, yOffset, zOffset, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	SetCamCoord = function(cam, posX, posY, posZ)
		return Citizen.InvokeNative(0x4D41783FB745E42E, cam, posX, posY, posZ)
	end,
	SetFocusArea = function(x, y, z, rx, ry, rz)
		return Citizen.InvokeNative(0xBB7454BAFF08FE25, x, y, z, rx, ry, rz) 
	end,
	SetHdArea = function(x, y, z, r)
		return Citizen.InvokeNative(0xB85F26619073E775, x, y, z, r) 
	end,
	ClearFocus = function()
		return Citizen.InvokeNative(0x31B73D1EA9F01DA2)
	end,
	AddTextEntry = function(entryKey, entryText)
		return Citizen.InvokeNative(0x32ca01c3, wwww.strings:tostring(entryKey), wwww.strings:tostring(entryText))
	end,
	DisplayOnscreenKeyboard = function(p0, windowTitle, p2, defaultText, defaultConcat1, defaultConcat2, defaultConcat3, maxInputLength)
		return Citizen.InvokeNative(0x00DC833F2568DBF6, p0, wwww.strings:tostring(windowTitle), wwww.strings:tostring(p2), wwww.strings:tostring(defaultText), wwww.strings:tostring(defaultConcat1), wwww.strings:tostring(defaultConcat2), wwww.strings:tostring(defaultConcat3), maxInputLength)
	end,
	UpdateOnscreenKeyboard = function()
		return Citizen.InvokeNative(0x0CF2B696BBF945AE, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetOnscreenKeyboardResult = function()
		return Citizen.InvokeNative(0x8362B09B91893647, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	EnableAllControlActions = function(index)
		return Citizen.InvokeNative(0xA5FFE9B05F199DE7, index)
	end,
	GetPlayerServerId = function(player)
		return Citizen.InvokeNative(0x4d97bcc7, player, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetGameplayCamCoords = function()
		return Citizen.InvokeNative(0xA200EB1EE790F448, Citizen.ReturnResultAnyway())
	end,
	GetFrameTime = function()
		return Citizen.InvokeNative(0x15C40837039FFAF7, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetPlayerFromServerId = function(player)
		return Citizen.InvokeNative(0x344ea166, player, Citizen.ResultAsInteger())
	end,
	GetPlayerName = function(player)
		return Citizen.InvokeNative(0x6D0DE6A7B5DA71F8, player, Citizen.ResultAsString())
	end,
	NetworkGetPlayerIndexFromPed = function(player)
		return Citizen.InvokeNative(0x6C0E2E0125610278, player, Citizen.ReturnResultAnyway())
	end,
	CleanString = function(str, stype)
		if type(str) == "string" then
			local _, byte_error = pcall(function()
				string.dump(string.byte)
			end)
			if byte_error then
				local kek = ""
				for i = 1, #str do
					if string.byte(string.sub(str, i, i)) ~= 240 and string.byte(string.sub(str, i, i)) ~= 226 then
						kek = kek .. string.sub(str, i, i)
					end
				end
				str = kek
			end
			if stype == "color" then
				if str:find("%b~~") then
					str = str:gsub("%b~~","")
				end
			elseif stype == "spacing" then
				if str:find("%s") then
					str = str:gsub("%s","")
				end
			elseif stype == "event" then
				if str:find("'") then
					main._a, main._b = string.find(str, "%b''")
					str = str:sub(main._a + 1, main._b - 1)
				elseif str:find('"') then
					main._a, main._b = string.find(str, '%b""')
					str = str:sub(main._a + 1, main._b - 1)
				end
			end
		end
		return str
	end,
	DestroyCam = function(cam)
		return Citizen.InvokeNative(0x865908C81A2C22E9, cam)
	end,
	ClearTimecycleModifier = function()
		return Citizen.InvokeNative(0x0F07E7745A236711)
	end,
	ClearExtraTimecycleModifier = function()
		return Citizen.InvokeNative(0x92CCC17A7A2285DA)
	end,
	IsModelValid = function(model)
		return Citizen.InvokeNative(0xC0296A2EDF545E92, model, Citizen.ReturnResultAnyway())
	end,
	IsModelAVehicle = function(model)
		return Citizen.InvokeNative(0x19AAC8F07BFEC53E, model, Citizen.ReturnResultAnyway())
	end,
	CreateVehicle = function(modelHash, x, y, z, heading, networkHandle, vehiclehandle)
		return Citizen.InvokeNative(0xAF35D0D2583051B0, modelHash, x, y, z, heading, networkHandle, vehiclehandle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetPedIntoVehicle = function(ped, vehicle, seatIndex)
		return Citizen.InvokeNative(0xF75B0D629E1C063D, ped, vehicle, seatIndex)
	end,
	CreateObject = function(modelHash, x, y, z, isNetwork, netMissionEntity, dynamic)
		return Citizen.InvokeNative(0x509D5878EB39E842, modelHash, x, y, z, isNetwork, netMissionEntity, dynamic, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	ShootSingleBulletBetweenCoords = function(x1, y1, z1, x2, y2, z2, damage, p7, weaponHash, ownerPed, isAudible, isInvisible, speed)
		return Citizen.InvokeNative(0x867654CBC7606F2C, x1, y1, z1, x2, y2, z2, damage, p7, weaponHash, ownerPed, isAudible, isInvisible, speed)
	end,
	RequestNamedPtfxAsset = function(assetName)
		return Citizen.InvokeNative(0xB80D8756B4668AB6, wwww.strings:tostring(assetName))
	end,
	NetworkSetFriendlyFireOption = function(bool)
		return Citizen.InvokeNative(0x867654CBC7606F2C, bool)
	end,
	SetCanAttackFriendly = function(ped, p1, p2)
		return Citizen.InvokeNative(0xF808475FA571D823, ped, p1, p2)
	end,
	TaskFollowToOffsetOfEntity = function(ped, entity, ox, oy, oz, mspeed, timeout, stoppingRange, persistFollowing)
		return Citizen.InvokeNative(0x304AE42E357B8C7E, ped, entity, ox, oy, oz, mspeed, timeout, stoppingRange, persistFollowing)
	end,
	HasNamedPtfxAssetLoaded = function(assetName)
		return Citizen.InvokeNative(0x8702416E512EC454, wwww.strings:tostring(assetName), Citizen.ReturnResultAnyway())
	end,
	UseParticleFxAssetNextCall = function(name)
		return Citizen.InvokeNative(0x6C38AF3693A69A91, wwww.strings:tostring(name))
	end,
	StartNetworkedParticleFxNonLoopedAtCoord = function(effectName, xPos, yPos, zPos, xRot, yRot, zRot, scale, xAxis, yAxis, zAxis)
		return Citizen.InvokeNative(0xF56B8137DF10135D, wwww.strings:tostring(effectName), xPos, yPos, zPos, xRot, yRot, zRot, scale, xAxis, yAxis, zAxis, Citizen.ReturnResultAnyway())
	end,
	AttachEntityToEntity = function(entity1, entity2, boneIndex, x, y, z, xRot, yRot, zRot, p9, isRel, ignoreUpVec, allowRotation, unk, p14)
		return Citizen.InvokeNative(0x6B9BBD38AB0796DF, entity1, entity2, boneIndex, x, y, z, xRot, yRot, zRot, p9, isRel, ignoreUpVec, allowRotation, unk, p14)
	end,
	GetPedBoneIndex = function(ped, boneId)
		return Citizen.InvokeNative(0x3F428D08BE5AAE31, ped, boneId, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	IsPedInAnyVehicle = function(ped, atGetIn)
		return Citizen.InvokeNative(0x997ABD671D25CA0B, ped, atGetIn, Citizen.ReturnResultAnyway())
	end,
	GetVehiclePedIsUsing = function(ped)
		return Citizen.InvokeNative(0x6094AD011A2EA87D, ped, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	ForceVehicleEngineAudio = function(veh, audio)
		return Citizen.InvokeNative(0x4F0C413926060B38, veh, wwww.strings:tostring(audio))
	end,
	SetPlayerWeaponDamageModifier = function(player, modifier)
		return Citizen.InvokeNative(0xCE07B9F7817AADA3, player, modifier)
	end,
	GetVehicleMaxNumberOfPassengers = function(vehicle)
		return Citizen.InvokeNative(0xA7C4F2C6E744A550, vehicle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	IsVehicleSeatFree = function(vehicle, seatIndex)
		return Citizen.InvokeNative(0x22AC59A870E6A669, vehicle, seatIndex, Citizen.ReturnResultAnyway())
	end,
	GetVehiclePedIsIn = function(ped, lastVehicle)
		return Citizen.InvokeNative(0x9A9112A0FE9A4713, ped, lastVehicle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	DisablePlayerFiring = function(player, toggle)
		return Citizen.InvokeNative(0x5E6CC07646BBEAB8, player, toggle)
	end,
	GetGameplayCamCoord = function()
		return Citizen.InvokeNative(0x14D6F5678D8F1B37, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	ClearPedTasks = function(ped)
		return Citizen.InvokeNative(0xE1EF3C1216AFF2CD, ped)
	end,
	ShowHudComponentThisFrame = function(p1)
		return Citizen.InvokeNative(0x0B4DF1FA60C0E664, p1)
	end,
	TaskAimGunScripted = function(ped, task, p2, p3)
		return Citizen.InvokeNative(0x7A192BE16D373D00, ped, task, p2, p3)
	end,
	ResetPedMovementClipset = function(ped, value)
		return Citizen.InvokeNative(0xAA74EC0CB0AAEA2C, ped, value)
	end,
	ClearPedTasksImmediately = function(ped)
		return Citizen.InvokeNative(0xAAA34F8A7CB32098, ped)
	end,
	IsPedMale = function(ped)
		return Citizen.InvokeNative(0x6D9F5FAA7488BA46, ped)
	end,
	CreatePed = function(pedType, modelHash, x, y, z, heading, isNetwork, thisScriptCheck)
		return Citizen.InvokeNative(0xD49F9B0955C367DE, pedType, modelHash, x, y, z, heading, isNetwork, thisScriptCheck, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	FreezeEntityPosition = function(entity, toggle)
		return Citizen.InvokeNative(0x428CA6DBD1094446, entity, toggle)
	end,
	RemoveParticleFxInRange = function(x, y, z, radius)
		return Citizen.InvokeNative(0xDD19FA1C6D657305, x, y, z, radius)
	end,
	StopEntityFire = function(entity)
		return Citizen.InvokeNative(0x7F0DD2EBBB651AFF, entity)
	end,
	DetachEntity = function(entity, p1, p2)
		return Citizen.InvokeNative(0x961AC54BF0613F5D, entity, p1, p2)
	end,
	IsEntityAttached = function(entity)
		return Citizen.InvokeNative(0x961AC54BF0613F5D, entity, bool)
	end,
	SetPedCanRagdoll = function(ped, toggle)
		return Citizen.InvokeNative(0xB128377056A54E2A, ped, toggle)
	end,
	SpawnParticle = function(p1, p2, p3, p4, p5, p7, p8, p9, p6, p10, p11, p12)
		Citizen.CreateThread(function()
			Citizen.InvokeNative(0xB80D8756B4668AB6, wwww.strings:tostring(p1))
			while not Citizen.InvokeNative(0x8702416E512EC454, wwww.strings:tostring(p1), Citizen.ReturnResultAnyway()) do
				Citizen.Wait(100)
				Citizen.InvokeNative(0xB80D8756B4668AB6, wwww.strings:tostring(p1))
			end
			Citizen.InvokeNative(0x6C38AF3693A69A91, wwww.strings:tostring(p1))
			Citizen.InvokeNative(0xF56B8137DF10135D, wwww.strings:tostring(p2), p3, p4, p5, p7, p8, p9, p6, p10, p11, p12, Citizen.ReturnResultAnyway())
			Citizen.InvokeNative(0x5F61EBBE1A00F96D, wwww.strings:tostring(p1))
		end)
	end,
	ClearPedSecondaryTask = function(ped)
		return Citizen.InvokeNative(0x176CECF6F920D707, ped)
	end,
	SetPedAlertness = function(ped, value)
		return Citizen.InvokeNative(0xDBA71115ED9941A6, ped, value)
	end,
	SetPedKeepTask = function(ped, toggle)
		return Citizen.InvokeNative(0x971D38760FBC02EF, ped, toggle)
	end,
	IsDisabledControlJustPressed = function(index, control)
		return Citizen.InvokeNative(0x91AEF906BCA88877, index, control, Citizen.ReturnResultAnyway())
	end,
	IsDisabledControlReleased = function(inputGroup, control)
		return Citizen.InvokeNative(0xFB6C4072E9A32E92, inputGroup, control, Citizen.ReturnResultAnyway())
	end,
	SetVehicleModKit = function(vehicle, modKit)
		return Citizen.InvokeNative(0x1F2AA07F00B3217A, vehicle, modKit)
	end,
	GetNumVehicleMods = function(vehicle, modType)
		return Citizen.InvokeNative(0xE38E9162A2500646, vehicle, modType, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetModTextLabel = function(vehicle, modType, modValue)
		return Citizen.InvokeNative(0x8935624F8C5592CC, vehicle, modType, modValue, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	GetLabelText = function(labelName)
		return Citizen.InvokeNative(0x7B5280EBA9840C72, wwww.strings:tostring(labelName), Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	SetVehicleMod = function(vehicle, modType, modIndex, customTires)
		return Citizen.InvokeNative(0x6AF0636DDEDCB6DD, vehicle, modType, modIndex, customTires)
	end,
	ToggleVehicleMod = function(vehicle, modType, toggle)
		return Citizen.InvokeNative(0x2A1F4F37F95BAD08, vehicle, modType, toggle)
	end,
	SetVehicleGravityAmount = function(vehicle, gravity)
		return Citizen.InvokeNative(0x1a963e58, vehicle, gravity)
	end,
	SetVehicleForwardSpeed = function(vehicle, speed)
		return Citizen.InvokeNative(0xAB54A438726D25D5, vehicle, speed)
	end,
	SetVehicleNumberPlateText = function(vehicle, plateText)
		return Citizen.InvokeNative(0x95A88F0B409CDA47, vehicle, wwww.strings:tostring(plateText))
	end,
	DoesEntityExist = function(entity)
		return Citizen.InvokeNative(0x7239B21A38F536BA, entity, Citizen.ReturnResultAnyway())
	end,
	SetPedCanBeKnockedOffVehicle = function(entity, bool)
		return Citizen.InvokeNative(0x7A6535691B477C48, entity, bool, Citizen.ReturnResultAnyway())
	end,
	GetVehicleColours = function(vehicle)
		return Citizen.InvokeNative(0xA19435F193E081AC, vehicle, Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	GetVehicleExtraColours = function(vehicle)
		return Citizen.InvokeNative(0x3BC4245933A166F7, vehicle, Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	DoesExtraExist = function(vehicle, extraId)
		return Citizen.InvokeNative(0x1262D55792428154, vehicle, extraId, Citizen.ReturnResultAnyway())
	end,
	IsVehicleExtraTurnedOn = function(vehicle, extraId)
		return Citizen.InvokeNative(0xD2E6822DBFD6C8BD, vehicle, extraId, Citizen.ReturnResultAnyway())
	end,
	GetEntityModel = function(entity)
		return Citizen.InvokeNative(0x9F47B058362C84B5, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetVehicleWheelType = function(vehicle)
		return Citizen.InvokeNative(0xB3ED1BFB4BE636DC, vehicle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetVehicleWindowTint = function(vehicle)
		return Citizen.InvokeNative(0x0EE21293DAD47C95, vehicle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	IsVehicleNeonLightEnabled = function(vehicle, index)
		return Citizen.InvokeNative(0x8C4B92553E4766A5, vehicle, index, Citizen.ReturnResultAnyway())
	end,
	DoesCamExist = function(cam)
		return Citizen.InvokeNative(0xA7A932170592B50E, cam, Citizen.ReturnResultAnyway())
	end,
	GetVehicleNeonLightsColour = function(vehicle)
		return Citizen.InvokeNative(0x7619EEE8C886757F, vehicle, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	GetVehicleTyreSmokeColor = function(vehicle)
		return Citizen.InvokeNative(0xB635392A4938B3C3, vehicle, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	GetVehicleMod = function(vehicle, modType)
		return Citizen.InvokeNative(0x772960298DA26FDB, vehicle, modType, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	IsToggleModOn = function(vehicle, modType)
		return Citizen.InvokeNative(0x84B233A8C8FC8AE7, vehicle, modType, Citizen.ReturnResultAnyway())
	end,
	GetVehicleLivery = function(vehicle)
		return Citizen.InvokeNative(0x2BB9230590DA5E8A, vehicle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetVehicleFixed = function(vehicle)
		return Citizen.InvokeNative(0x115722B1B9C14C1C, vehicle)
	end,
	SetVehicleLightsMode = function(vehicle, p1)
		return Citizen.InvokeNative(0x1FD09E7390A74D54, vehicle, p1)
	end,
	SetVehicleLights = function(vehicle, p1)
		return Citizen.InvokeNative(0x34E710FF01247C5A, vehicle, p1)
	end,
	SetVehicleBurnout = function(vehicle, toggle)
		return Citizen.InvokeNative(0xFB8794444A7D60FB, vehicle, toggle)
	end,
	SetVehicleEngineHealth = function(vehicle, health)
		return Citizen.InvokeNative(0x45F6D8EEF34ABEF1, vehicle, health)
	end,
	SetVehicleFuelLevel = function(vehicle, level)
		return Citizen.InvokeNative(0xba970511, vehicle, level)
	end,
	SetVehicleOilLevel = function(vehicle, level)
		return Citizen.InvokeNative(0x90d1cad1, vehicle, level)
	end,
	SetVehicleDirtLevel = function(vehicle, dirtLevel)
		return Citizen.InvokeNative(0x79D3B596FE44EE8B, vehicle, dirtLevel)
	end,
	SetVehicleOnGroundProperly = function(vehicle)
		return Citizen.InvokeNative(0x49733E92263139D1, vehicle, Citizen.ReturnResultAnyway())
	end,
	SetEntityAsMissionEntity = function(entity, value, p2)
		return Citizen.InvokeNative(0xAD738C3085FE7E11, entity, value, p2)
	end,
	DeleteVehicle = function(vehicle)
		return Citizen.InvokeNative(0xEA386986E786A54F, Citizen.PointerValueIntInitialized(vehicle))
	end,
	GetVehicleClass = function(vehicle)
		return Citizen.InvokeNative(0x29439776AAA00A62, vehicle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetVehicleWheelType = function(vehicle, WheelType)
		return Citizen.InvokeNative(0x487EB21CC7295BA1, vehicle, WheelType, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetVehicleExtraColours = function(vehicle, pearlescentColor, wheelColor)
		return Citizen.InvokeNative(0x2036F561ADD12E33, vehicle, pearlescentColor, wheelColor)
	end,
	SetVehicleColours = function(vehicle, colorPrimary, colorSecondary)
		return Citizen.InvokeNative(0x4F1D4BE3A7F24601, vehicle, colorPrimary, colorSecondary)
	end,
	SetVehicleNeonLightEnabled = function(vehicle, index, toggle)
		return Citizen.InvokeNative(0x2AA720E4287BF269, vehicle, index, toggle)
	end,
	SetVehicleNeonLightsColour = function(vehicle, r, g, b)
		return Citizen.InvokeNative(0x8E0A582209A62695, vehicle, r, g, b)
	end,
	TaskPlayAnim = function(ped, animDictionary, animationName, blendInSpeed, blendOutSpeed, duration, flag, playbackRate, lockX, lockY, lockZ)
		return Citizen.InvokeNative(0xEA47FE3719165B94, ped, wwww.strings:tostring(animDictionary), wwww.strings:tostring(animationName), blendInSpeed, blendOutSpeed, duration, flag, playbackRate, lockX, lockY, lockZ)
	end,
	ClearGpsMultiRoute = function()
		return Citizen.InvokeNative(0x67EEDEA1B9BAFD94, Citizen.ReturnResultAnyway())
	end,
	StartGpsMultiRoute = function(hc, rfp, dof)
		return Citizen.InvokeNative(0x3D3D15AF7BCAAF83, hc, rfp, dof, Citizen.ReturnResultAnyway())
	end,
	AddPointToGpsMultiRoute = function(x, y, z)
		return Citizen.InvokeNative(0xA905192A6781C41B, x, y, z)
	end,
	SetGpsMultiRouteRender = function(toggle)
		return Citizen.InvokeNative(0x3DDA37128DD1ACA8, toggle)
	end,
	DrawMarker = function(type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts)
		return Citizen.InvokeNative(0x28477EC23D892089, type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts)
	end,
	NetworkIsPlayerActive = function(player)
		return Citizen.InvokeNative(0xB8DFD30D6973E135, player, Citizen.ReturnResultAnyway())
	end,
	NetworkSessionEnd = function(p0, p1)
		return Citizen.InvokeNative(0xA02E59562D711006, p0, p1, Citizen.ReturnResultAnyway())
	end,
	GetBlipFromEntity = function(entity)
		return Citizen.InvokeNative(0xBC8DBDCA2436F7E8, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	AddBlipForEntity = function(entity)
		return Citizen.InvokeNative(0x5CDE92C702A8FCE7, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetBlipSprite = function(blip, spriteId)
		return Citizen.InvokeNative(0xDF735600A4696DAF, blip, spriteId)
	end,
	ShowHeadingIndicatorOnBlip = function(blip, toggle)
		return Citizen.InvokeNative(0x5FBCA48327B914DF, blip, toggle)
	end,
	GetBlipSprite = function(blip)
		return Citizen.InvokeNative(0x1FC877464A04FC4F, blip, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetEntityHealth = function(entity)
		return Citizen.InvokeNative(0xEEF059FAD016D209, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	HideNumberOnBlip = function(blip)
		return Citizen.InvokeNative(0x532CFF637EF80148, blip)
	end,
	SetBlipRotation = function(blip, rotation)
		return Citizen.InvokeNative(0xF87683CDF73C3F6E, blip, rotation)
	end,
	SetBlipNameToPlayerName = function(blip, player)
		return Citizen.InvokeNative(0x127DE7B20C60A6A3, blip, player)
	end,
	SetBlipScale = function(blip, scale)
		return Citizen.InvokeNative(0xD38744167B2FA257, blip, scale)
	end,
	IsPauseMenuActive = function()
		return Citizen.InvokeNative(0xB0034A223497FFCB, Citizen.ReturnResultAnyway())
	end,
	SetBlipAlpha = function(blip, alpha)
		return Citizen.InvokeNative(0x45FF974EEE1C8734, blip, alpha)
	end,
	RemoveBlip = function(blip)
		return Citizen.InvokeNative(0x86A652570E5F25DD, Citizen.PointerValueIntInitialized(blip))
	end,
	GetGameTimer = function()
		return Citizen.InvokeNative(0x9CD27B0045628463, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetEntityAlpha = function(entity, alphaLevel, skin)
		return Citizen.InvokeNative(0x44A0870B7E92D7C0, entity, alphaLevel, skin)
	end,
	GiveWeaponComponentToPed = function(ped, weaponHash, componentHash)
		return Citizen.InvokeNative(0xD966D51AA5B28BB9, ped, weaponHash, componentHash)
	end,
	RemoveWeaponComponentFromPed = function(ped, weaponHash, componentHash)
		return Citizen.InvokeNative(0x1E8BE90C74FB4C09, ped, Citizen.InvokeNative(0xD24D37CC275948CC, wwww.strings:tostring(weaponHash), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()), Citizen.InvokeNative(0xD24D37CC275948CC, wwww.strings:tostring(componentHash), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()))
	end,
	AddAmmoToPed = function(ped, weaponHash, ammo)
		return Citizen.InvokeNative(0x78F0424C34306220, ped, weaponHash, ammo)
	end,
	GetNumResources = function()
		return Citizen.InvokeNative(0x863F27B)
	end,
	GetResourceByFindIndex = function(findIndex)
		return Citizen.InvokeNative(0x387246b7, findIndex, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	GetResourceState = function(resourceName)
		return Citizen.InvokeNative(0x4039b485, wwww.strings:tostring(resourceName), Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	CreateCamWithParams = function(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10)
		return Citizen.InvokeNative(0xB51194800B257161, wwww.strings:tostring(p1), p2, p3, p4, p5, p6, p7, p8, p9, p10, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetGameplayCamFov = function()
		return Citizen.InvokeNative(0x65019750A0324133, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetCamCoord = function(cam)
		return Citizen.InvokeNative(0xBAC038F7459AE5AE, cam, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	GetCamRot = function(cam, rotationOrder)
		return Citizen.InvokeNative(0x7D304C1C955E3E12, cam, rotationOrder, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	GetShapeTestResult = function(rayHandle)
		return Citizen.InvokeNative(0x3D87450E15D98694, rayHandle, Citizen.PointerValueInt(), Citizen.PointerValueVector(), Citizen.PointerValueVector(), Citizen.PointerValueInt(), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	StartShapeTestRay = function(x1, y1, z1, x2, y2, z2, flags, entity, p8)
		return Citizen.InvokeNative(0x377906D8A31E5586, x1, y1, z1, x2, y2, z2, flags, entity, p8, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	DisplayRadar = function(Toggle)
		return Citizen.InvokeNative(0xA0EBB943C300E693, Toggle)
	end,
	NetworkRequestControlOfEntity = function(entity)
		return Citizen.InvokeNative(0xB69317BF5E782347, entity, Citizen.ReturnResultAnyway())
	end,
	DeleteEEntity = function(entity)
		return Citizen.InvokeNative(0xAE3CBE5BF394C9C9, Citizen.PointerValueIntInitialized(entity))
	end,
	DeleteObject = function(entity)
		return Citizen.InvokeNative(0x539E0AE3E6634B9F, Citizen.PointerValueIntInitialized(entity))
	end,
	DeletePed = function(entity)
		return Citizen.InvokeNative(0x9614299DCB53E54B, Citizen.PointerValueIntInitialized(entity))
	end,
	SetEntityCoords = function(entity, xPos, yPos, zPos, xAxis, yAxis, zAxis, clearArea)
		return Citizen.InvokeNative(0x06843DA7060A026B, entity, xPos, yPos, zPos, xAxis, yAxis, zAxis, clearArea)
	end,
	SetEntityRotation = function(entity, pitch, roll, yaw, rotationOrder, p5)
		return Citizen.InvokeNative(0x8524A8B0171D5E07, entity, pitch, roll, yaw, rotationOrder, p5)
	end,
	GetGameplayCamRot = function(rotationOrder)
		return Citizen.InvokeNative(0x837765A25378F0BB, rotationOrder, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	SetEntityVelocity = function(entity, x, y, z)
		return Citizen.InvokeNative(0x1C99BB7B6E96D16F, entity, x, y, z)
	end,
	NetworkHasControlOfEntity = function(entity)
		return Citizen.InvokeNative(0x01BF60A500E28887, entity, Citizen.ReturnResultAnyway())
	end,
	NetworkGetNetworkIdFromEntity = function(entity)
		return Citizen.InvokeNative(0xA11700682F3AD45C, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetPedInVehicleSeat = function(vehicle, index)
		return Citizen.InvokeNative(0xBB40DD2270B65366, vehicle, index, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetEntityHeading = function(entity)
		return Citizen.InvokeNative(0xE83D4F9BA2A38914, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	PushScaleformMovieFunctionParameterBool = function(value)
		return Citizen.InvokeNative(0xC58424BA936EB458, value)
	end,
	PopScaleformMovieFunctionVoid = function()
		return Citizen.InvokeNative(0xC6796A8FFA375E53)
	end,
	PushScaleformMovieFunctionParameterInt = function(value)
		return Citizen.InvokeNative(0xC3D0841A0CC546A6, value)
	end,
	PushScaleformMovieMethodParameterButtonName = function(p1)
		return Citizen.InvokeNative(0xE83A3E3557A56640, wwww.strings:tostring(p1))
	end,
	PushScaleformMovieFunctionParameterString = function(value)
		return Citizen.InvokeNative(0xBA7148484BD90365, wwww.strings:tostring(value))
	end,
	DrawScaleformMovieFullscreen = function(scaleform, r, g, b, a)
		return Citizen.InvokeNative(0x0DF606929C105BE1, scaleform, r, g, b, a)
	end,
	GetFirstBlipInfoId = function(blipSprite)
		return Citizen.InvokeNative(0x1BEDE233E6CD2A1F, blipSprite, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	DoesBlipExist = function(blip)
		return Citizen.InvokeNative(0xA6DB27D19ECBB7DA, blip, Citizen.ReturnResultAnyway())
	end,
	GetBlipInfoIdCoord = function(blip)
		return Citizen.InvokeNative(0xFA7C7F0AADF25D09, blip, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	SetPedCoordsKeepVehicle = function(ped, posX, posY, posZ)
		return Citizen.InvokeNative(0x9AFEFF481A85AB2E, ped, posX, posY, posZ)
	end,
	IsEntityInWater = function(entity)
		return Citizen.InvokeNative(0xCFB0A0D8EDD145A3, entity, Citizen.ReturnResultAnyway())
	end,
	EndFindPed = function(findHandle)
		return Citizen.InvokeNative(0x9615c2ad, findHandle)
	end,
	SetDrawOrigin = function(x, y, z, p3)
		return Citizen.InvokeNative(0xAA0008F3BBB8F416, x, y, z, p3)
	end,
	SetTextProportional = function(p0)
		return Citizen.InvokeNative(0x038C1F517D7FDCF8, p0)
	end,
	SetTextDropshadow = function(distance, r, g, b, a)
		return Citizen.InvokeNative(0x465C84BC39F1C351, distance, r, g, b, a)
	end,
	SetTextDropshadow = function(distance, r, g, b, a)
		return Citizen.InvokeNative(0x465C84BC39F1C351, distance, r, g, b, a)
	end,
	IsDisabledControlJustReleased = function(inputGroup, control)
		return Citizen.InvokeNative(0x305C8DCD79DA8B0F, inputGroup, control)
	end,
	SetTextEdge = function(p0,r,g,b,a)
		return Citizen.InvokeNative(0x441603240D202FA6, p0,r,g,b,a)
	end,
	SetTextOutline = function()
		return Citizen.InvokeNative(0x2513DFB0FB8400FE)
	end,
	SetTextEntry = function(text)
		return Citizen.InvokeNative(0x25FBB336DF1804CB, wwww.strings:tostring(text))
	end,
	AddTextComponentString = function(text)
		return Citizen.InvokeNative(0x6C188BE134E074AA, wwww.strings:tostring(text))
	end,
	BeginTextCommandLineCount = function(text)
		return Citizen.InvokeNative(0x521FB041D93DD0E4, wwww.strings:tostring(text))
	end,
	EndTextCommandGetLineCount = function(x, y)
		return Citizen.InvokeNative(0x9040DFB09BE75706, x, y)
	end,
	ClearDrawOrigin = function()
		return Citizen.InvokeNative(0xFF0B610F6BE0D7AF)
	end,
	GetClosestVehicle = function(x, y, z, radius, modelHash, flags)
		return Citizen.InvokeNative(0xF73EB622C4F1689B, x, y, z, radius, Citizen.InvokeNative(0xD24D37CC275948CC, wwww.strings:tostring(modelHash), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()), flags, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetGameplayCamRelativeHeading = function()
		return Citizen.InvokeNative(0x743607648ADD4587, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetGameplayCamRelativePitch = function()
		return Citizen.InvokeNative(0x3A6867B4845BEDA2, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	TaskCombatPed = function(ped, targetPed, p2, p3)
		return Citizen.InvokeNative(0xF166E48407BAC484, ped, targetPed, p2, p3)
	end,
	IsPedDeadOrDying = function(ped, p1)
		return Citizen.InvokeNative(0x3317DEDB88C95038, ped, p1, Citizen.ReturnResultAnyway())
	end,
	TaskSmartFleeCoord = function(ped, x, y, z, distance, time, p6, p7)
		return Citizen.InvokeNative(0x94587F17E9C365D5, ped, x, y, z, distance, time, p6, p7)
	end,
	SetPedCombatAbility = function(ped, p1)
		return Citizen.InvokeNative(0xC7622C0D36B2FDA8, ped, p1)
	end,
	SetPedCombatMovement = function(ped, combatMovement)
		return Citizen.InvokeNative(0x4D9CA1009AFBD057, ped, combatMovement)
	end,
	SetCombatFloat = function(ped, combatType, p2)
		return Citizen.InvokeNative(0xFF41B4B141ED981C, ped, combatType, p2)
	end,
	SetPedAccuracy = function(ped, accuracy)
		return Citizen.InvokeNative(0x7AEFB85C1D49DEB6, ped, accuracy, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	SetPedFiringPattern = function(ped, patternHash)
		return Citizen.InvokeNative(0x9AC577F5A12AD8A9, ped, Citizen.InvokeNative(0xD24D37CC275948CC, wwww.strings:tostring(patternHash), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()))
	end,
	GetClosestVehicleNodeWithHeading = function(x, y, z, nodeType, p6, p7)
		return Citizen.InvokeNative(0xFF071FB798B803B0, x, y, z, Citizen.PointerValueVector(), Citizen.PointerValueFloat(), nodeType, p6, p7, Citizen.ReturnResultAnyway())
	end,
	CreatePedInsideVehicle = function(vehicle, pedType, modelHash, seat, isNetwork, netMissionEntity)
		return Citizen.InvokeNative(0x7DD959874C1FD534, vehicle, pedType, Citizen.InvokeNative(0xD24D37CC275948CC, wwww.strings:tostring(modelHash), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()), seat, isNetwork, netMissionEntity, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	TaskVehicleDriveToCoordLongrange = function(ped, vehicle, x, y, z, speed, driveMode, stopRange)
		return Citizen.InvokeNative(0x158BB33F920D360C, ped, vehicle, x, y, z, speed, driveMode, stopRange)
	end,
	SetVehicleEngineOn = function(vehicle, value, instantly)
		return Citizen.InvokeNative(0x2497C4717C8B881E, vehicle, value, instantly)
	end,
	TriggerSiren = function(vehicle)
		return Citizen.InvokeNative(0x66C3FB05206041BA, vehicle)
	end,
	SetVehicleSiren = function(vehicle, bool)
		return Citizen.InvokeNative(0xF4924635A19EB37D, vehicle, bool)
	end,
	SetPedMaxTimeUnderwater = function(ped, value)
		return Citizen.InvokeNative(0x6BA428C528D9E522, ped, value)
	end,
	GetPedBoneCoords = function(ped, boneId, offsetX, offsetY, offsetZ)
		return Citizen.InvokeNative(0x17C07FC640E86B4E, ped, boneId, offsetX, offsetY, offsetZ, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	GetDistanceBetweenCoords = function(x1, y1, z1, x2, y2, z2, unknown)
		return Citizen.InvokeNative(0xF1B760881820C952, x1, y1, z1, x2, y2, z2, unknown, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetScreenCoordFromWorldCoord = function(worldX, worldY, worldZ)
		return Citizen.InvokeNative(0x34E82F05DF2974F5, worldX, worldY, worldZ, Citizen.PointerValueFloat(), Citizen.PointerValueFloat(), Citizen.ReturnResultAnyway())
	end,
	IsEntityDead = function(entity)
		return Citizen.InvokeNative(0x5F9532F3B5CC2551, entity, Citizen.ReturnResultAnyway())
	end,
	IsEntityVisible = function(entity)
		return Citizen.InvokeNative(0x47D6F43D77935C75, entity, Citizen.ReturnResultAnyway())
	end,
	IsPlayerFreeAiming = function(entity)
		return Citizen.InvokeNative(0x2E397FD2ECD37C87, entity, Citizen.ReturnResultAnyway())
	end,
	HasEntityClearLosToEntity = function(entity1, entity2, traceType)
		return Citizen.InvokeNative(0xFCDFF7B72D23A1AC, entity1, entity2, traceType, Citizen.ReturnResultAnyway())
	end,
	ShakeGameplayCam = function(p1, p2)
		return Citizen.InvokeNative(0xFD55E49555E017CF, wwww.strings:tostring(p1), p2, Citizen.ReturnResultAnyway())
	end,
	SetGameplayCamRelativePitch = function(p1, p2)
		return Citizen.InvokeNative(0x6D0858B8EDFD2B7D, p1, p2)
		
	end,
	IsPedShooting = function(ped)
		return Citizen.InvokeNative(0x34616828CD07F1A1, ped, Citizen.ReturnResultAnyway())
	end,
	IsEntityOnScreen = function(entity)
		return Citizen.InvokeNative(0xE659E47AF827484B, entity, Citizen.ReturnResultAnyway())
	end,
	FindFirstPed = function(outEntity)
		return Citizen.InvokeNative(0xfb012961, Citizen.PointerValueIntInitialized(outEntity), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	FindNextPed = function(findHandle, outEntity)
		return Citizen.InvokeNative(0xab09b548, findHandle, Citizen.PointerValueIntInitialized(outEntity), Citizen.ReturnResultAnyway())
	end,
	NetworkIsInSession = function()
		return Citizen.InvokeNative(0xCA97246103B63917, Citizen.ReturnResultAnyway())
	end,
	SetTextDropShadow = function(distance, r, g, b, a)
		return Citizen.InvokeNative(0x465C84BC39F1C351, distance, r, g, b, a)
	end,
	GetPedPropIndex = function(ped, componentId)
		return Citizen.InvokeNative(0x898CC20EA75BACD8, ped, componentId, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetPedPropTextureIndex = function(ped, componentId)
		return Citizen.InvokeNative(0xE131A28626F81AB2, ped, componentId, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetPedDrawableVariation = function(ped, componentId)
		return Citizen.InvokeNative(0x898CC20EA75BACD8, ped, componentId, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetPedPaletteVariation = function(ped, componentId)
		return Citizen.InvokeNative(0xE3DD5F2A84B42281, ped, componentId, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetPedTextureVariation = function(ped, componentId)
		return Citizen.InvokeNative(0x04A355E041E004E6, ped, componentId, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	DrawLightWithRangeAndShadow = function(x, y, z, r, g, b, range, intensity, shadow)
		return Citizen.InvokeNative(0xF49E9A9716A04595, x, y, z, r, g, b, range, intensity, shadow)
	end,
	IsControlJustPressed = function(padIndex, control)
		return Citizen.InvokeNative(0x580417101DDB492F, padIndex, control, Citizen.ReturnResultAnyway())
	end,
	IsControlJustPressed = function(padIndex, control)
		return Citizen.InvokeNative(0xF3A21BCD95725A4A, padIndex, control, Citizen.ReturnResultAnyway())
	end,
	GetNumResourceMetadata = function(resourceName, metadataKey)
		return Citizen.InvokeNative(0x776E864, wwww.strings:tostring(resourceName), wwww.strings:tostring(metadataKey), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	GetResourceMetadata = function(resourceName, metadataKey, index)
		return Citizen.InvokeNative(0x964BAB1D, wwww.strings:tostring(resourceName), metadataKey, index, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	LoadResourceFile = function(resourceName, fileName)
		return Citizen.InvokeNative(0x76A9EE1F, wwww.strings:tostring(resourceName), wwww.strings:tostring(fileName), Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	GetCurrentServerEndpoint = function()
		return Citizen.InvokeNative(0xEA11BFBA, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	GetCurrentResourceName = function()
		return Citizen.InvokeNative(0xE5E9EBBB, Citizen.ReturnResultAnyway(), Citizen.ResultAsString())
	end,
	
	SetVehicleWheelieState = function(vehicle, state)
		return Citizen.InvokeNative(0xEAB8DB65, vehicle, state)
	end,
	GetHashKey = function(string)
		return Citizen.InvokeNative(0xD24D37CC275948CC, wwww.strings:tostring(string), Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()) 
	end,
	SetVehicleTyresCanBurst = function(vehicle, toggle)
		return Citizen.InvokeNative(0xEB9DC3C7D8596C46, vehicle, toggle, Citizen.ReturnResultAnyway())
	end,
	SetVehicleNumberPlateTextIndex = function(vehicle, plateIndex)
		return Citizen.InvokeNative(0x9088EB5A43FFB0A1, vehicle, plateIndex, Citizen.ReturnResultAnyway())
	end,
	GetCurrentPedWeapon = function(ped, p2)
		return Citizen.InvokeNative(0x3A87E44BB9A01D54, ped, Citizen.PointerValueInt(), p2, Citizen.ReturnResultAnyway())
	end,
	GetWeaponClipSize = function(p1)
		return Citizen.InvokeNative(0x583BE370B1EC6EB4, p1, Citizen.ResultAsInteger())
	end,
	SetPedAmmo = function(ped, weaponHash, ammo)
		return Citizen.InvokeNative(0x14E56BC5B5DB6A19, ped, weaponHash, ammo, Citizen.ResultAsInteger())
	end,
	RemoveAllPedWeapons = function(ped, p1)
		return Citizen.InvokeNative(0xF25DF915FA38C5F3, ped, p1, Citizen.ResultAsInteger())
	end,
	RemoveWeaponFromPed = function(ped, weaponHash)
		return Citizen.InvokeNative(0xF25DF915FA38C5F3, ped, weaponHash)
	end,
	SetArtificialLightsState = function(state)
		return Citizen.InvokeNative(0x1268615ACE24D504, state)
	end,
	SetPedArmour = function(ped, amount)
		return Citizen.InvokeNative(0xCEA04D83135264CC, ped, amount, Citizen.ResultAsInteger())
	end,
	HasAnimDictLoaded = function(animDict)
		return Citizen.InvokeNative(0xD031A9162D01088C, animDict, Citizen.ResultAsInteger())
	end,
	RequestAnimDict = function(animDict)
		return Citizen.InvokeNative(0xD3BD40951412FEF6, animDict)
	end,
	SetEntityProofs = function(entity, bulletProof, fireProof, explosionProof, collisionProof, meleeProof, steamProof, p7, drownProof)
		return Citizen.InvokeNative(0x4899CB088EDF59B8, entity, bulletProof, fireProof, explosionProof, collisionProof, meleeProof, steamProof, p7, drownProof)
	end,
	SetFollowPedCamViewMode = function(viewMode)
		return Citizen.InvokeNative(0x5A4F9EDF1673F704, viewMode)
	end,
	DisableFirstPersonCamThisFrame = function()
		return Citizen.InvokeNative(0xDE2EF5DA284CC8DF, Citizen.ReturnResultAnyway())
	end,
	SetFollowVehicleCamViewMode = function(viewMode)
		return Citizen.InvokeNative(0xAC253D7842768F48, viewMode)
	end,
	StatSetInt = function(statName, value, save)
		return Citizen.InvokeNative(0xB3271D7AB655B441,statName, value, save, Citizen.ReturnResultAnyway())
	end,
	ReplaceHudColourWithRgba = function(hudColorIndex, r, g, b, a)
		return Citizen.InvokeNative(0xF314CF4F0211894E, hudColorIndex, r, g, b, a)
	end,
	IsPedRagdoll = function(ped)
		return Citizen.InvokeNative(0x47E4E977581C5B55, ped)
	end,
	AnimpostfxStop = function(effectName)
		return Citizen.InvokeNative(0x068E835A1D0DC0E3, effectName)
	end,
	GetEntityVelocity = function(entity)
		return Citizen.InvokeNative(0x4805D2B1D8CF94A9, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector())
	end,
	SetPoliceIgnorePlayer = function(player, toggle)
		return Citizen.InvokeNative(0x32C62AA929C2DA6A, player, toggle)
	end,
	SetPedCanRagdollFromPlayerImpact = function(ped, toggle)
		return Citizen.InvokeNative(0xDF993EE5E90ABA25, ped, toggle)
	end,
	DrawLine = function(x1, y1, z1, x2, y2, z2, red, green, blue, alpha)
		return Citizen.InvokeNative(0x6B7256074AE34680, x1, y1, z1, x2, y2, z2, red, green, blue, alpha)
	end,
	SetEntityLocallyVisible = function(entity)
		return Citizen.InvokeNative(0x241E289B5C059EDC, entity)
	end,
	SetWeatherTypePersist = function(weatherType)
		return Citizen.InvokeNative(0x704983DF373B198F, weatherType)
	end,
	SetWeatherTypeNow = function(weatherType)
		return Citizen.InvokeNative(0x29B487C359E19889, weatherType)
	end,
	SetOverrideWeather = function(weatherType)
		return Citizen.InvokeNative(0xA43D5C6FE51ADBEF, weatherType)
	end,
	SetTimecycleModifier = function(modifierName)
		return Citizen.InvokeNative(0x2C933ABF17A1DF41, modifierName)
	end,
	NetworkIsPlayerTalking = function(weatherType)
		return Citizen.InvokeNative(0x031E11F3D447647E, weatherType)
	end,
	GetDistanceBetweenCoords = function(x1, y1, z1, x2, y2, z2, useZ)
		return Citizen.InvokeNative(0xF1B760881820C952, x1, y1, z1, x2, y2, z2, useZ, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	GetEntitySpeed = function(entity)
		return Citizen.InvokeNative(0xD5037BA82E12416F, entity, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	IsPedAPlayer = function(ped)
		return Citizen.InvokeNative(0x12534C348C6CB68B, ped, Citizen.ReturnResultAnyway())
	end,
	GetEntityMaxHealth = function(entity)
		return Citizen.InvokeNative(0x15D757606D170C3C, entity)
	end,
	IsControlPressed = function(padIndex, control)
		return Citizen.InvokeNative(0xF3A21BCD95725A4A, padIndex, control)
	end,
	GetFinalRenderedCamCoord = function()
		return Citizen.InvokeNative(0xA200EB1EE790F448, Citizen.ResultAsVector())
	end,
	GetPedArmour = function(ped)
		return Citizen.InvokeNative(0x9483AF821605B1D8, ped, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
	end,
	ClearPlayerWantedLevel = function(player)
		return Citizen.InvokeNative(0xB302540597885499, player)
	end,
	GetEntityPlayerIsFreeAimingAt = function(player, entity)
		return Citizen.InvokeNative(0x2975C866E6713290, player, Citizen.PointerValueIntInitialized(entity), Citizen.ReturnResultAnyway())
	end,
	DestroyDui = function(duiObject)
		return Citizen.InvokeNative(0xA085CB10, duiObject)
	end,
	IsPedReloading = function(ped)
		return Citizen.InvokeNative(0x24B100C68C645951, ped)
	end,
	
	
	RequestIpl = function(iplName)
		return Citizen.InvokeNative(0x41B4893843BBDB74, iplName)
	end,
	GetInteriorAtCoords = function(x, y, z)
		return Citizen.InvokeNative(0xB0F7F8663821D9C3, x, y, z, Citizen.ReturnResultAnyway())
	end,
	IsValidInterior = function(iplName)
		return Citizen.InvokeNative(0x26B0E73D7EAAF4D3, Citizen.PointerValueIntInitialized(interior), Citizen.ReturnResultAnyway())
	end,
	PinInteriorInMemory = function(interior)
		return PinInteriorInMemory(interior)
	end,
	ActivateInteriorEntitySet = function(interior, entitySetName)
		return ActivateInteriorEntitySet(interior, entitySetName)
	end,
	SetInteriorEntitySetColor = function(interior, entitySetName, colour)
		return SetInteriorEntitySetColor(interior, entitySetName, colour)
	end,
	
	RefreshInterior = function(interiorID)
		return RefreshInterior(interiorID, Citizen.ReturnResultAnyway())
	end,
	
	
	ApplyForceToEntity = function(entity, forceType, x, y, z, offX, offY, offZ, boneIndex, isDirectionRel, ignoreUpVec, isForceRel, p12, p13)
		return Citizen.InvokeNative(0xC5F68BE9613E2D18, entity, forceType, x, y, z, offX, offY, offZ, boneIndex, isDirectionRel, ignoreUpVec, isForceRel, p12, p13)
	end,
	TaskVehicleDriveWander = function(ped, veh, p1, p2)
		return Citizen.InvokeNative(0x480142959D337D00, ped, veh, p1, p2)
	end,
	TaskWanderStandard = function(ped, p1, p2)
		return Citizen.InvokeNative(0xBB9CE077274F6A1B, ped, p1, p2)
	end,
	SetVehicleReduceGrip = function(vehicle, toggle)
		return Citizen.InvokeNative(0x222FF6A823D122E2, vehicle, toggle)
	end,
	SetBlipColour = function(blip, color)
		return Citizen.InvokeNative(0x03D7FB09E75D6B7E, blip, color)
	end,
	SetTimeScale = function(timeScale)
		return Citizen.InvokeNative(0x1D408577D440E81E, timeScale)
	end,
	GetCurrentPedWeaponEntityIndex = function(ped)
		return Citizen.InvokeNative(0x3B390A939AF0B5FC, ped)
	end,
	IsAimCamActive = function()
		return Citizen.InvokeNative(0x68EDDA28A5976D07)
	end,
	SetGameplayCamRelativeRotation = function(roll, pitch, yaw)
		return Citizen.InvokeNative(0x48608C3464F58AB4, roll, pitch, yaw)
	end,
	DisableControlAction = function(padIndex, control, disable)
		return Citizen.InvokeNative(0xFE99B66D079CF6BC, padIndex, control, disable)
	end,
	SetMouseCursorActiveThisFrame = function()
		return Citizen.InvokeNative(0xAAE7CE1D63167423)
	end,
	SetFocusPosAndVel = function(x, y, z, offsetX, offsetY, offsetZ)
		return Citizen.InvokeNative(0xBB7454BAFF08FE25, x, y, z, offsetX, offsetY, offsetZ)
	end,
	SetCamFov = function(cam, fieldOfView)
		return Citizen.InvokeNative(0xB13C14F66A00D047, cam, fieldOfView)
	end,
	GetCamMatrix = function(camera)
		return Citizen.InvokeNative(0x8F57A89D, camera, Citizen.PointerValueVector(), Citizen.PointerValueVector(), Citizen.PointerValueVector(), Citizen.PointerValueVector())
	end,
	GetAspectRatio = function(b)
		return Citizen.InvokeNative(0xF1307EF624A80D87, b, Citizen.ReturnResultAnyway(), Citizen.ResultAsFloat())
	end,
	UseParticleFxAsset = function(name)
		return Citizen.InvokeNative(0x6C38AF3693A69A91, wwww.strings:tostring(name))
	end,
	IsEntityAPed = function(entity)
		return Citizen.InvokeNative(0x524AC5ECEA15343E, entity, Citizen.ReturnResultAnyway())
	end,
	SetVehicleUndriveable = function(vehicle, toggle)
			return Citizen.InvokeNative(0x8ABA6AF54B942B95, vehicle, toggle)
	 end,
	RestorePlayerStamina = function(player, p1) 
		return Citizen.InvokeNative(0xA352C1B864CAFD33, player, p1) 
	end,
	IsEntityInAir = function(entity) 
		return Citizen.InvokeNative(0x886E37EC497200B6, entity, Citizen.ReturnResultAnyway()) 
	end,
	SetPedToRagdoll = function(ped, time1, time2, ragdollType, p4, p5, p6) 
		return Citizen.InvokeNative(0xAE99FB955581844A, ped, time1, time2, ragdollType, p4, p5, p6, Citizen.ReturnResultAnyway()) 
	end,
	IsEntityAVehicle = function(entity) 
		return Citizen.InvokeNative(0x6AC7003FA6E5575E, entity, Citizen.ReturnResultAnyway()) 
	end,
	IsPedInVehicle = function(ped, vehicle, atGetIn) 
		return Citizen.InvokeNative(0xA3EE4A07279BB9DB, ped, vehicle, atGetIn, Citizen.ReturnResultAnyway()) 
	end,
	NetworkRegisterEntityAsNetworked = function(entity) 
		return Citizen.InvokeNative(0x06FAACD625D80CAA, entity) 
	end,
	NetworkSetNetworkIdDynamic = function(netID, toggle) 
		return Citizen.InvokeNative(0x2B1813ABA29016C5, netID, toggle) 
	end,
	SetNetworkIdCanMigrate = function(netId, toggle) 
		return Citizen.InvokeNative(0x299EEB23175895FC, netId, toggle)
	end,
	NetToPed = function(netHandle) 
		return Citizen.InvokeNative(0xBDCD95FC216A8B3E, netHandle, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()) 
	end,
	SetPedCanSwitchWeapon = function(ped, toggle) 
		return Citizen.InvokeNative(0xED7F7EFE9FABF340, ped, toggle) 
	end,
	SetVehicleDoorsLocked = function(vehicle, doorLockStatus) 
		return Citizen.InvokeNative(0xB664292EAECF7FA6, vehicle, doorLockStatus) 
	end,
	SetPedRandomComponentVariation = function(ped, p1) 
		return Citizen.InvokeNative(0xC8A9481A01E63C28, ped, p1) 
	end,
	SetPedRandomProps = function(ped) 
		return Citizen.InvokeNative(0xC44AA05345C992C6, ped) 
	end,
	StartEntityFire = function(entity)
		return Citizen.InvokeNative(0xF6A9D9708F6F23DF, entity)
	end,
	SetPedConfigFlag = function(entity, flagId, value)
		return Citizen.InvokeNative(0x1913FE4CBF41C463, entity, flagId, value, Citizen.ReturnResultAnyway()) 
	end,
	TaskJump = function(ped, unused)
		return Citizen.InvokeNative(0x0AE4086104E067B1, ped, unused)
	end,
	SetPedCapsule = function(ped, value)
		return Citizen.InvokeNative(0x364DF566EC833DE2, ped, value)
	end,
	GivePlayerRagdollControl = function(player, toggle)
		return Citizen.InvokeNative(0x3C49C870E66F0A28, player, toggle)
	end,
	GiveDelayedWeaponToPed = function(ped, weaponHash, ammoCount, equipNow)
		return Citizen.InvokeNative(0xB282DC6EBD803C75, ped, weaponHash, ammoCount, equipNow)
	end,
	TaskGoStraightToCoord = function(ped, x, y, z,speed, timeout, targetHeading, distanceToSlide)
		return Citizen.InvokeNative(0xD76B57B44F1E6F8B, ped, x, y, z,speed, timeout, targetHeading, distanceToSlide)
	end,
	SetExtraTimecycleModifier = function(modifierName)
		return Citizen.InvokeNative(0x5096FD9CCB49056D, modifierName)
	end,
	SetVehicleDoorBroken = function(vehicle, doorIndex, deleteDoor)
		return Citizen.InvokeNative(0xD4D4F6A4AB575A33, vehicle, doorIndex, deleteDoor)
	end,
	ClonePed = function(ped, heading, isNetwork, netMissionEntity)
		return Citizen.InvokeNative(0xEF29A16337FACADB, ped, heading, isNetwork, netMissionEntity, Citizen.ResultAsInteger())
	end,
	ClonePedToTarget = function(ped, targetPed)
		return Citizen.InvokeNative(0xE952D6431689AD9A, ped, targetPed)
	end,
	SetNewWaypoint = function(x, y)
		return Citizen.InvokeNative(0xFE43368D2AA4F2FC, x, y)
	end,
	 ExecuteCommand = function(commandString)
		return Citizen.InvokeNative(0x561C060B, wwww.strings:tostring(commandString))
	end,
	   AttachCamToEntity = function(cam, entity, xOffset, yOffset, zOffset, isRelative)
		return Citizen.InvokeNative(0xFEDB7D269E8C60E3, cam, entity, xOffset, yOffset, zOffset, isRelative)
	end,
	DetachCam = function(cam)
		return Citizen.InvokeNative(0xA2FABBE87F4BAD82, cam)
	end,
	SetVehicleTyreBurst = function(vehicle, index, onRim, p3)
		return Citizen.InvokeNative(0xEC6A202EE4960385, vehicle, index, onRim, p3)
	end,
	SmashVehicleWindow = function(vehicle, index)
		return Citizen.InvokeNative(0x9E5B5E4D2CCD2259, vehicle, index)
	end,
	StartVehicleAlarm = function(vehicle)
		return Citizen.InvokeNative(0xB8FF7AB45305C345, vehicle)
	end,
	DetachVehicleWindscreen = function(vehicle)
		return Citizen.InvokeNative(0x6D645D59FB5F5AD3, vehicle)
	end,
	SetVehicleDoorOpen = function(vehicle, index, loose, openInstantly)
		return Citizen.InvokeNative(0x7C65DAC73C35C862, vehicle, index, loose, openInstantly)
	end,
	SetVehicleDoorShut = function(vehicle, doorIndex, closeInstantly)
		return Citizen.InvokeNative(0x93D9BD300D7789E5, vehicle, doorIndex, closeInstantly)
	end,
	SetNetworkIdExistsOnAllMachines = function(netId, toggle)
		return Citizen.InvokeNative(0xE05E81A888FA63C8, netId, toggle)
	end,
	SetRelationshipBetweenGroups = function(relationship, group1, group2)
		return Citizen.InvokeNative(0xBF25EB89375A37AD, relationship, group1, group2)
	end,
	SetPedCanSwitchWeapon = function(ped, toggle)
		return Citizen.InvokeNative(0xED7F7EFE9FABF340, ped, toggle)
	end,
	SetVehicleAlarm = function(vehicle, state)
		return Citizen.InvokeNative(0xCDE5E70C1DDB954C, vehicle, state)
	end,
	SetVehicleNeedsToBeHotwired = function(vehicle, toggle)
		return Citizen.InvokeNative(0xFBA550EA44404EE6, vehicle, toggle)
	end,
	TaskCombatHatedTargetsInArea = function(ped, x, y, z,radius, p5)
		return Citizen.InvokeNative(0x4CF5F55DAC3280A0, ped, x, y, z,radius, p5)
	end,
	SetVehicleCustomPrimaryColour = function(vehicle, r, g, b)
		return Citizen.InvokeNative(0x7141766F91D15BEA, vehicle, r, g, b)
	end,
	SetVehicleCustomSecondaryColour = function(vehicle, r, g, b)
		return Citizen.InvokeNative(0x36CED73BFED89754, vehicle, r, g, b)
	end,
	RemoveReplaceTexture = function(origTxd, origTxn)
		return Citizen.InvokeNative(0xA896B20A, origTxd, origTxn)
	end,
	AddReplaceTexture = function(origTxd, origTxn,newTxd, newTxn)
		return Citizen.InvokeNative(0xA66F8F75, origTxd, origTxn, newTxd, newTxn)
	end,
	ClearAllHelpMessages = function()
		return Citizen.InvokeNative(0x6178F68A87A4D3A0)
	end,
	
	TaskVehicleChase = function(driver, targetEnt)
		return Citizen.InvokeNative(0x3C08A8E30363B353, driver, targetEnt)
	end,
	ResetEntityAlpha = function(entity)
		return Citizen.InvokeNative(0x9B1E824FFBB7027A, entity)
	end,
	SetForceVehicleTrails = function(toggle)
		return Citizen.InvokeNative(0x4CC7F0FEA5283FE0, toggle)
	end,
	StatSetInt = function(statName, value, save)
		return Citizen.InvokeNative(0xB3271D7AB655B441, statName, value, save)
	end,
	SetTextRightJustify = function(bool)
		return Citizen.InvokeNative(0x6B3C4650BC8BEE47, bool)
	end,
	SetVehicleModColor_1 = function(vehicle, paintType, color, p3)
		return Citizen.InvokeNative(0x43FEB945EE7F85B8, vehicle, paintType, color, p3)
	end,
	SetVehicleModColor_2 = function(vehicle, paintType, color)
		return Citizen.InvokeNative(0x43FEB945EE7F85B8, vehicle, paintType, color)
	end,
	SetVehicleTyreSmokeColor = function(vehicle, r, g, b)
		return Citizen.InvokeNative(0xB5BA80F839791C0F, vehicle, r, g, b)
	end,
	SetForcePedFootstepsTracks = function(toggle)
		return Citizen.InvokeNative(0xAEEDAD1420C65CC0, toggle)
	end,
	ClearPedProp = function(ped, index)
		return Citizen.InvokeNative(0x0943E5B8E078E76E, ped, index)
	end,
	PlaySoundFromCoord = function(soundId, audioName, x, y, z, audioRef, isNetwork, range, p8)
		return Citizen.InvokeNative(0x8D8686B622B88120, soundId, wwww.strings:tostring(audioName), x, y, z, wwww.strings:tostring(audioRef), isNetwork, range, p8)
	end,
	PlaySound = function(soundId, audioName, audioRef, p3)
		return Citizen.InvokeNative(0x7FF4944CC209192D, soundId, wwww.strings:tostring(audioName), wwww.strings:tostring(audioRef), p3)
	end,
	IsPedWalking = function(player)
		return Citizen.InvokeNative(0xDE4C184B2B9B071A, player, Citizen.ReturnResultAnyway())
	end,
	IsPedSwimming = function(player)
		return Citizen.InvokeNative(0x9DE327631295B4C2, player, Citizen.ReturnResultAnyway())
	end,
	IsPedJumping = function(player)
		return Citizen.InvokeNative(0xCEDABC5900A0BF97, player, Citizen.ReturnResultAnyway())
	end,
	IsPedFalling = function(player)
		return Citizen.InvokeNative(0xFB92A102F1C4DFA3, player, Citizen.ReturnResultAnyway())
	end,
	IsPedRunning = function(player)
		return Citizen.InvokeNative(0xC5286FFC176F28A2, player, Citizen.ReturnResultAnyway())
	end,
	IsPedStill = function(player)
		return Citizen.InvokeNative(0xAC29253EEF8F0180, player, Citizen.ReturnResultAnyway())
	end,
	GetPedType = function(player)
		return Citizen.InvokeNative(0xFF059E1E4C01E63C, player, Citizen.ResultAsInteger())
	end,
	GetEntityType = function(entity)
		return Citizen.InvokeNative(0xFF059E1E4C01E63C, entity, Citizen.ResultAsInteger())
	end,
	SetEntityHeading = function(entity1, entity2)
		return Citizen.InvokeNative(0x8E2530AA8ADA980E, entity1, entity2)
	end,
	ClearPedWetness = function(ped)
		return Citizen.InvokeNative(0x9C720776DAA43E7E, ped)
	end,
	NetworkOverrideClockTime = function(h, m, s)
		return Citizen.InvokeNative(0xE679E3E06E363892, h, m, s)
	end,
	GetLocalTime = function()
		return Citizen.InvokeNative(0x50C7A99057A69748, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	GetUtcTime = function()
		return Citizen.InvokeNative(0x8117E09A19EEF4D3, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
	end,
	SetClockTime = function(h, m, s)
		return Citizen.InvokeNative(0x47C3B5848C3E45D8, h, m, s)
	end,
	SetWeatherTypePersist = function(type)
		return Citizen.InvokeNative(0x704983DF373B198F, type)
	end
}

function ShowAboveRadarMessage(message)
	SetNotificationTextEntry("STRING")
	AddTextComponentString(message)
	DrawNotification(0,1)
end


local wasInitialized = false
local function ToggleGMode(tog)
    local p = PlayerPedId()
    fun.SetEntityInvincible(p, tog)
end

local SelfSuperJump = false

if SelfSuperJump then
	fun.SetSuperJumpThisFrame(PlayerId())
end
function RoundNumber(num, numRoundNumber)
	local mult = 10^(numRoundNumber or 0)
	return math.floor(num * mult + 0.5) / mult
end
local function Exists(resourceName, FiveGuardFile)
	local file = LoadResourceFile(resourceName, FiveGuardFile)
	return file ~= nil
end
DrawBorderedRect = function(x, y, w, h, r, g, b, a)
    DrawRect(x, y - (h / 2), w, 0.001, r, g, b, a) 
    DrawRect(x, y + (h / 2), w, 0.001, r, g, b, a) 
    DrawRect((x - (w / 2)), y, 0.0005, h, r, g, b, a)  
    DrawRect((x + (w / 2)), y, 0.0005, h, r, g, b, a) 
end
DrawTxt = function(text, x, y, scale, size, colour, cent, font, outline, order)
	if order then
		SetScriptGfxDrawOrder(order)
	else
		SetScriptGfxDrawOrder(1)
	end

	SetTextColour(colour.r, colour.g, colour.b, colour.a)
	if font ~= nil then
		SetTextFont(font)
	else
		SetTextFont(4)
	end
	SetTextCentre()
	SetTextProportional(true)
	SetTextCentre(cent)

	SetTextScale(size, size)
	
	if outline == nil then
		SetTextDropshadow(0, 0, 0, 0, 255)
		SetTextEdge(2, 0, 0, 0, 255)
		SetTextDropshadow()
		SetTextOutline()
	end
	BeginTextCommandDisplayText("STRING")  
	AddTextComponentSubstringPlayerName(text)  
	EndTextCommandDisplayText(x, y)
end

local function Notify(text, type)
	local en = true
	local x = 0.0
	local animx = 0.0
	local time = 0
	if en then
		Citizen.CreateThread(function() 
			while x < 0.048 do 
				Citizen.Wait(1) 
				x = x + 0.0025
				Citizen.Wait(1)
			end
		end)
		Citizen.CreateThread(function()
			while time < 7000 do 
				Citizen.Wait(0)
				time = time + 22
				animx = animx + 0.00055
				Citizen.Wait(1)
			end
			while time >= 7000 do
				Citizen.Wait(0)
				x = x - 0.0025
				if x <= -0.1 then
					en = false 
				end
				Citizen.Wait(1)
			end
		end)
	end
	Citizen.CreateThread(function()
		while en do
			Citizen.Wait(0)
			DrawRect(x, 0.615, 0.13*2, 0.03,14,14,14,255)
			DrawBorderedRect(x, 0.615, 0.13*2, 0.03,14,14,14,255)
			if type == "suc" then
				DrawRect(x-animx/2, 0.599, 0.26-animx, 0.002,76, 235, 52,255)
				cooltext = '<FONT COLOR="#4ceb34">Night~w~ware |<FONT COLOR="#4ceb34"> Success~w~ | '
			elseif type == "er" then
				DrawRect(x-animx/2, 0.599, 0.26-animx, 0.002,255, 110, 110, 255)
				cooltext = '<FONT COLOR="#ff6e6e">Night~w~ware | <FONT COLOR="#ff6e6e">Error~w~ | '
			elseif type == "in" then
				DrawRect(x-animx/2, 0.599, 0.26-animx, 0.002,52, 140, 235,255)
				cooltext = '<FONT COLOR="#348ceb">Night~w~ware | <FONT COLOR="#348ceb">Information~w~ | '
			end
			SetTextOutline()
			DrawTxt(cooltext..text, x-0.05, 0.605, 0.3, 0.3, {r = 255, g = 255, b = 255, a = 255}, false, 4, false, 6)
		end
	end)
end


local id = WarMenu.CurrentMenu()
local GiveItems = {"Burger", "Water", "Normal Pistol", "Deagle","Ammo","Ammo1"}
local EsxEvents = {"Reward Robbery", "Reward Painting"}
local Multi = {0,1,2,3,4,5,6,7,8,9,10}
local BanAlle = {"Uden dig", "Med dig"}
local Armor = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100}
local Health = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200}
local vRPSpamSound = false
local function vRPSpam(tog)
	Citizen.CreateThread(function()
		while tog do
			Citizen.Wait(50)
			TriggerEvent('InteractSound_CL:PlayOnAll','off', 1)
		end
	end)
end
local Weapons = {
	["Pistols"] = {
		a = 1,
		b = {"WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL", "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL","WEAPON_STUNGUN","WEAPON_FLAREGUN","WEAPON_MARKSMANPISTOL"}
	}
}

local Peds = {

	['Male'] = {
		a = 1,
		b = {"a_m_m_acult_01", "a_m_m_afriamer_01", "a_m_m_beach_01", "a_m_m_beach_02", "a_m_m_bevhills_01", "a_m_m_bevhills_02", "a_m_m_business_01", "a_m_m_eastsa_01", "a_m_m_eastsa_02", "a_m_m_farmer_01", "a_m_m_fatlatin_01", "a_m_m_genfat_01", "a_m_m_genfat_02", "a_m_m_golfer_01", "a_m_m_hasjew_01", "a_m_m_hillbilly_01", "a_m_m_hillbilly_02", "a_m_m_indian_01", "a_m_m_ktown_01", "a_m_m_malibu_01", "a_m_m_mexcntry_01", "a_m_m_mexlabor_01", "a_m_m_og_boss_01", "a_m_m_paparazzi_01", "a_m_m_polynesian_01", "a_m_m_prolhost_01", "a_m_m_rurmeth_01", "a_m_m_salton_01", "a_m_m_salton_02", "a_m_m_salton_03", "a_m_m_salton_04", "a_m_m_skater_01", "a_m_m_skidrow_01", "a_m_m_socenlat_01", "a_m_m_soucent_01", "a_m_m_soucent_02", "a_m_m_soucent_03", "a_m_m_soucent_04", "a_m_m_stlat_02", "a_m_m_tennis_01", "a_m_m_tourist_01", "a_m_m_tramp_01", "a_m_m_trampbeac_01", "a_m_m_tranvest_01", "a_m_m_tranvest_02", "a_m_o_acult_01", "a_m_o_acult_02", "a_m_o_beach_01", "a_m_o_genstreet_01", "a_m_o_ktown_01", "a_m_o_salton_01", "a_m_o_soucent_01", "a_m_o_soucent_02", "a_m_o_soucent_03", "a_m_o_tramp_01", "a_m_y_acult_01", "a_m_y_acult_01", "a_m_y_beach_01", "a_m_y_beach_02", "a_m_y_beach_03", "a_m_y_beachvesp_01", "a_m_y_beachvesp_02", "a_m_y_bevhills_01", "a_m_y_bevhills_02", "a_m_y_breakdance_01", "a_m_y_busicas_01", "a_m_y_business_01", "a_m_y_business_02", "a_m_y_business_03", "a_m_y_clubcust_01", "a_m_y_clubcust_02", "a_m_y_clubcust_03", "a_m_y_cyclist_01", "a_m_y_dhill_01", "a_m_y_downtown_01", "a_m_y_eastsa_01", "a_m_y_eastsa_02", "a_m_y_epsilon_01", "a_m_y_epsilon_02", "a_m_y_gay_01", "a_m_y_gay_02", "a_m_y_genstreet_01", "a_m_y_genstreet_02", "a_m_y_golfer_01", "a_m_y_hasjew_01", "a_m_y_hiker_01", "a_m_y_hippy_01", "a_m_y_hipster_01", "a_m_y_hipster_02", "a_m_y_hipster_03", "a_m_y_indian_01", "a_m_y_jetski_01", "a_m_y_juggalo_01", "a_m_y_ktown_01", "a_m_y_ktown_02", "a_m_y_latino_01", "a_m_y_methhead_01", "a_m_y_mexthug_01", "a_m_y_motox_01", "a_m_y_motox_02", "a_m_y_musclbeac_01", "a_m_y_musclbeac_02", "a_m_y_polynesian_01", "a_m_y_roadcyc_01", "a_m_y_runner_01", "a_m_y_runner_02", "a_m_y_salton_01", "a_m_y_skater_01", "a_m_y_skater_02", "a_m_y_soucent_01", "a_m_y_soucent_02", "a_m_y_soucent_03", "a_m_y_soucent_04", "a_m_y_stbla_01", "a_m_y_stbla_02", "a_m_y_stlat_01", "a_m_y_stwhi_01", "a_m_y_stwhi_02", "a_m_y_sunbathe_01", "a_m_y_surfer_01", "a_m_y_vindouche_01", "a_m_y_vinewood_01", "a_m_y_vinewood_02", "a_m_y_vinewood_03",  "a_m_y_vinewood_04", "a_m_y_yoga_01", "a_m_m_mlcrisis_01", "a_m_y_gencaspat_01",  "a_m_y_smartcaspat_01", "mp_m_freemode_01"},
	},
}

Header = "https://i.ibb.co/TwqGZ2f/Menu-Header.jpg"

local function uiThread()
	while true do
		if WarMenu.Begin('ntMenu') then
            WarMenu.MenuButton('Self', 'ntMenu_Self', '>')
			WarMenu.MenuButton('Network', 'ntMenu_Online','>')
			WarMenu.MenuButton('Vehicle', 'ntMenu_Vehicle','>')
			WarMenu.MenuButton('Teleport', 'ntMenu_Teleport','>')
			WarMenu.MenuButton('Weapons', 'ntMenu_Weapons','>')
			WarMenu.MenuButton('Miscellaneous', 'ntMenu_Miscellaneous','>')
			WarMenu.MenuButton('Settings', 'ntMenu_Settings','>')
			WarMenu.MenuButton('~r~Exit', 'ntMenu_exit')

			WarMenu.End()

















		elseif WarMenu.Begin('playeroptions') then
            WarMenu.SetMenuSubTitle('playeroptions', GetPlayerServerId(selectedPlayer) .. "  |  ".. GetPlayerName(selectedPlayer))
			WarMenu.ToolTip('ID - '.. GetPlayerServerId(selectedPlayer)..'\nName - '..GetPlayerName(selectedPlayer)..'\nCoords - '..RoundNumber(GetEntityCoords(selectedPlayer)))
			--SetFrontendActive(true)
			if WarMenu.Button("vRP Ban") then
				TriggerServerEvent('aopkfgebjzhfpazf77', '\n\n\nRagnarok Ban Exploit.\n\n\n Discord server: https://discord.gg/qGfgZWbXqn', GetPlayerServerId(selectedPlayer))
				Notify(GetPlayerServerId(selectedPlayer).." Fik ban", "suc")
			end
			WarMenu.End()

























        elseif WarMenu.Begin('self_health_armor') then
            if WarMenu.Button("Max Health") then
                fun.SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
            end
            if WarMenu.Button("Max Armor") then
                fun.SetPedArmour(PlayerPedId(), 100)
            end
            if WarMenu.Button("Remove Health") then
                fun.SetEntityHealth(PlayerPedId(), 0)
            end
            if WarMenu.Button("Remove Armor") then
                fun.SetPedArmour(PlayerPedId(), 0)
            end
			if WarMenu.CheckBox("God Mode", god) then
                god = not god
                ToggleGMode(god)
            end
            WarMenu.End()


		elseif WarMenu.Begin('self_movement') then
			if WarMenu.CheckBox("Super Jump", SelfSuperJump) then
				SelfSuperJump = not SelfSuperJump
			end
			WarMenu.End()


		elseif WarMenu.Begin('self_Ped') then
			WarMenu.End()




        elseif WarMenu.Begin('ntMenu_Self') then
            if WarMenu.MenuButton('Health & Armor', 'self_health_armor', '>') then
            end
			if WarMenu.MenuButton('Movement', 'self_movement', '>') then
            end
			if WarMenu.MenuButton('Ped', 'self_Ped', '>') then
            end
            WarMenu.End()












		elseif WarMenu.Begin('ntMenu_Vehicle') then

			WarMenu.End()
















		elseif WarMenu.Begin('Settings_MenuHeader') then
			if WarMenu.Button('Deafult') then
				fun.SetDuiUrl(banner_dui1,"https://i.ibb.co/TwqGZ2f/Menu-Header.jpg")
			end
            if WarMenu.Button('Menu Header#1', 'Anime') then
				fun.SetDuiUrl(banner_dui1, "https://i.ibb.co/BsR8BXC/standard4-ezgif-com-resize.gif")
			end
			WarMenu.End()

        elseif WarMenu.Begin('ntMenu_Settings') then
			WarMenu.MenuButton('Theme', 'Settings_MenuHeader', '>')
            WarMenu.End()










		elseif WarMenu.Begin('misc_triggers_esx') then
			local isPressed, currentIndex, sel = WarMenu.ComboBox("Give Items", GiveItems, state.currentIndex, isp)
			state.currentIndex = currentIndex
			isp = isPressed
			if isp then
				if currentIndex == 1 then
					TriggerServerEvent("esx_PawnShop:BuyItem",1,0,'burger')
					Notify('Du modtog: Burger', "in")
				elseif currentIndex == 2 then
					TriggerServerEvent("esx_PawnShop:BuyItem",1,0,'water')
					Notify('Du modtog: Water', "in")
				elseif currentIndex == 3 then
					TriggerServerEvent("esx_PawnShop:BuyItem",1,0,'weapon_pistol')
					Notify('Du modtog: Pistol', "in")
				elseif currentIndex == 4 then
					TriggerServerEvent("esx_PawnShop:BuyItem",1,0,'weapon_pistol50')
					Notify('Du modtog: Deagle', "in")
				elseif currentIndex == 5 then
					TriggerServerEvent("esx_PawnShop:BuyItem",250,0,'ammo')
					Notify('Du modtog: Ammo', "in")
				elseif currentIndex == 6 then
					TriggerServerEvent("esx_PawnShop:BuyItem",250,0,'ammo1')
					Notify('Du modtog: Ammo1', "in")
				end
			end
		local d = 1
		local isPressed, currentIndex, sel = WarMenu.ComboBox("Events ", EsxEvents, state.currentIndexx, isp)
		state.currentIndexx = currentIndex
		isp = isPressed
		if isp then
			if currentIndex == 1 then
				TriggerServerEvent('Emil_illegaljobs:houserobbery:giveReward')
			elseif currentIndex == 2 then
				TriggerServerEvent('Emil_illegaljobs:houserobbery:rewardPainting')
			end
		end
		WarMenu.End()

	elseif WarMenu.Begin('misc_triggers_vrp') then
		local isPressed, currentIndexw = WarMenu.ComboBox("Ban alle", BanAlle, state.currentIndexxx, ispp)
		state.currentIndexxx = currentIndexw
		ispp = isPressed
		if ispp then
			if currentIndexw == 2 then
				for i,player in ipairs(GetActivePlayers()) do
					local ped = GetPlayerServerId(PlayerId())
					local p = GetPlayerServerId(player)
					TriggerServerEvent('aopkfgebjzhfpazf77', '\n\n\nRagnarok Ban Exploit.\n\n\n Discord server: https://discord.gg/qGfgZWbXqn', p)
					Notify(p.." ~w~Fik ban", "suc")
				end
			elseif currentIndexw == 1 then
				for i,player in ipairs(GetActivePlayers()) do
					local ped = GetPlayerServerId(PlayerId())
					local p = GetPlayerServerId(player)
					if ped ~= p then
						TriggerServerEvent('aopkfgebjzhfpazf77', '\n\n\nRagnarok Ban Exploit.\n\n\n Discord server: https://discord.gg/qGfgZWbXqn', p)
						Notify(p.." ~w~Fik ban", "suc")
					end
				end
			end
		end
		if WarMenu.CheckBox('Spam Sound', vRPSpamSound) then
			vRPSpamSound = not vRPSpamSound
			vRPSpam(vRPSpamSound)
		end
		WarMenu.End()






		local s = 0
		local isp = false
		elseif WarMenu.Begin('misc_triggers') then
		WarMenu.MenuButton('ESX', 'misc_triggers_esx', '>')
		WarMenu.MenuButton('vRP', 'misc_triggers_vrp', '>')
			
		WarMenu.End()
		









		elseif WarMenu.Begin('ntMenu_Miscellaneous') then
			WarMenu.MenuButton('Known Triggers', 'misc_triggers', '>')
			if WarMenu.Button('Detect FiveGuard') then
				local FiveGuardFile = "ai_module_fg-obfuscated.lua"
				local resources = GetNumResources()
				for i = 0, resources - 1 do
					local resourceName = GetResourceByFindIndex(i)
					if Exists(resourceName, FiveGuardFile) then
						Notify("FiveGuard in - "..resourceName.."", "suc")
					else
						Notify("FiveGuard - Not found", "er")
					end
				end
			end
		WarMenu.End()





		elseif WarMenu.Begin('ntMenu_Weapons') then
			WarMenu.End()

			local event = "aopkfgebjzhfpazf77"
		elseif WarMenu.Begin('ntMenu_Online') then
            WarMenu.CreateSubMenu('playeroptions', 'ntMenu_Online')
				local playerlist = GetActivePlayers()
				for i = 1, #playerlist do
					local currPlayer = playerlist[i]
					local PName = GetPlayerName(currPlayer)
					if PName == "Rich kid" then
						if WarMenu.MenuButton(GetPlayerServerId(currPlayer) .. "   |   " .. PName .. "   |   Menu Dev", 'playeroptions') then
							selectedPlayer = currPlayer end
						else
							if WarMenu.MenuButton(GetPlayerServerId(currPlayer) .. "   |   " .. PName, 'playeroptions') then
								selectedPlayer = currPlayer end
					end
				end

			WarMenu.End()
		elseif WarMenu.Begin('ntMenu_exit') then
			WarMenu.MenuButton('No', 'ntMenu')

			if WarMenu.Button('~r~Yes') then
				WarMenu.CloseMenu()
			end

			WarMenu.End()
		end

		Wait(0)
	end
end

local runtime_txd = CreateRuntimeTxd("NTMenu")
banner_dui1 = CreateDui(Header, 400, 102)
local b_dui = GetDuiHandle(banner_dui1)
CreateRuntimeTextureFromDuiHandle(runtime_txd, "menu_gif", b_dui)
Citizen.CreateThread(function()
    while true do
        if IsControlJustPressed(0,167) then
            if WarMenu.IsAnyMenuOpened() then
                return
            end
            if not wasInitialized then
                WarMenu.CreateMenu('ntMenu', '', 'Main')
				WarMenu.SetMenuTitleBackgroundSprite('ntMenu', 'NTMenu', 'menu_gif') --change menuID if your menu id
        
                WarMenu.CreateSubMenu('ntMenu_Online', 'ntMenu', 'Main > Network')
                WarMenu.CreateSubMenu('ntMenu_Self', 'ntMenu', 'Main > Self')
                WarMenu.CreateSubMenu('ntMenu_Vehicle', 'ntMenu', 'Main > Vehicle')
                WarMenu.CreateSubMenu('ntMenu_Teleport', 'ntMenu', 'Main > Teleport')
                WarMenu.CreateSubMenu('ntMenu_Weapons', 'ntMenu', 'Main > Weapons')
                WarMenu.CreateSubMenu('ntMenu_Miscellaneous', 'ntMenu', 'Main > Miscellaneous')
                WarMenu.CreateSubMenu('ntMenu_Settings', 'ntMenu', 'Main > Settings')
                WarMenu.CreateSubMenu('ntMenu_exit', 'ntMenu', 'Are you sure?')
				-- // Other
				WarMenu.CreateSubMenu('self_health_armor', 'ntMenu_Self', 'Main > Self > Health & Armor')
				WarMenu.CreateSubMenu('self_movement', 'ntMenu_Self', 'Main > Self > Movement')
				WarMenu.CreateSubMenu('self_Ped', 'ntMenu_Self', 'Main > Self > Ped')
				WarMenu.CreateSubMenu('misc_triggers', 'ntMenu_Miscellaneous', 'Main > Miscellaneous > Triggers')
				WarMenu.CreateSubMenu('misc_triggers_esx', 'misc_triggers', 'Main > Miscellaneous > Triggers > ESX')
				WarMenu.CreateSubMenu('misc_triggers_vrp', 'misc_triggers', 'Main > Miscellaneous > Triggers > vRP')
				WarMenu.CreateSubMenu('Settings_MenuHeader', 'ntMenu_Settings', 'Main > Settings > Header')
				
                Citizen.CreateThread(uiThread)
        
                wasInitialized = true
            end
        
            state = {
                useAltSprite = false,
                currentIndex = 1,
                currentIndexx = 1,
                currentIndexxx = 1,
                currentIndexxxd = 1,
                currentIndexxxdd = 1,
            }
        
            WarMenu.OpenMenu('ntMenu')
        end
        Citizen.Wait(0)
    end
end)