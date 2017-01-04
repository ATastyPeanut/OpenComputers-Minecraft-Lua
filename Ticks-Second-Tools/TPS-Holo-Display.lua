--Written by A_Tasty_Peanut
--Config Options########################################################################
--hologram options
local hologramScale = 3 --the size of holo
local rotation = false  --Should the hologram rotate
local rotationRate = 3 --How Fast the sign will rotate

--Colors are decimal representation of HEX value
local colorA=16777215 --TPS Words default 16777215 is white
local colorB=65280 --Color of TPS number  
local colorC=65793 --Black Backdrop (allows for double sided sign)
local ColorAdjust = true  --Do you want TPS number to change color based on value?

local timeConstant = 2 --how long it waits per measure cycle

--######################################################################################

local com = require "component"
local fs = require "filesystem"
local keyboard = require "keyboard"
local holo = com.hologram

--Intialaization for Hologram projector
local rawHoloTxtBase = ""
local f = io.open("TPSBaseRaw", "r")
rawHoloTxtBase = f:read("*all")
f:close()
holo.clear()
holo.setScale(hologramScale)
holo.setTranslation(0,0.2,0)
holo.setPaletteColor(1, colorA)
holo.setPaletteColor(2, colorB)
holo.setPaletteColor(3, colorC)
holo.setRotation(0,0,0,0)
holo.setRaw(rawHoloTxtBase)
if rotation == true then
holo.setRotationSpeed(rotationRate,0,1,0)
else
holo.setRotationSpeed(0,0,1,0)
end

--all* glyphs follow standard minecraft text pixels (*the decimal is a lil diffrent)
--all* glyphs are 7char High by 5char Wide (*the decumal is 7char High by 4char Wide)
local glyphsMath = {
["0"]=[[
 XXX 
X   X
X  XX
X X X
XX  X
X   X
 XXX 
]],
["1"]=[[
  X  
 XX  
  X  
  X  
  X  
  X  
XXXXX
]],
["2"]=[[
 XXX 
X   X
    X
  XX 
 X   
X   X
XXXXX
]],
["3"]=[[
 XXX 
X   X
    X
  XX 
    X
X   X
 XXX 
]],
["4"]=[[
   XX
  X X
 X  X
X   X
XXXXX
    X
    X
]],
["5"]=[[
XXXXX
X    
XXXX 
    X
    X
X   X
 XXX 
]],
["6"]=[[
  XX 
 X   
X    
XXXX 
X   X
X   X
 XXX 
]],
["7"]=[[
XXXXX
X   X
    X
   X 
  X  
  X  
  X  
]],
["8"]=[[
 XXX 
X   X
X   X
 XXX 
X   X
X   X
 XXX 
]],
["9"]=[[
 XXX 
X   X
X   X
 XXXX
    X
   X 
 XX  
]],
["."]=[[
    
    
    
    
    
    
 X  
]],
}

local function time() --returns realworld unix time stamp in miliseconds
local f = io.open("/tmp/timeFile","w")
f:write("test")
f:close()
return(fs.lastModified("/tmp/timeFile"))
end

local function cvtToGlyp(txtNum)
	local timeTxt = ""
	for row = 1, 7 do  --text code taken from https://github.com/OpenPrograms/Sangar-Programs/blob/master/holo-text.lua
					   --Simplified a decent bit tho since it doesn't need to do as much
		for col = 1, 5 do
			local singleChar = string.sub(txtNum, col, col)
			local glyph = glyphsMath[singleChar]
			local s = 0
			for _ = 2, row do
				s = string.find(glyph, "\n", s + 1, true)
				if not s then
					break
				end
			end
			if s then
				local line = string.sub(glyph, s + 1, (string.find(glyph, "\n", s + 1, true) or 0) - 1)
				timeTxt = timeTxt .. line .. " "
			end
		end
		timeTxt = timeTxt .. "\n"
	end
return(timeTxt)
end

local function getColor(tps) --Uses HSV to decide color
	local H, rP, gP, bP, X = tps*12-120, 0, 0, 0, 0
	--H is hue should range from 0 to 120
	if H<0 then H=0 end --forces greater then 0 but if things get wonky lets Hue go above 120 and turn blue
	X = (1-math.abs((H/60)%2-1))
	if H<60 then
		rP = 1
		gP = X
		bP = 0
	elseif H<120 then
		rP = X
		gP = 1
		bP = 0	
	elseif H<180 then
		rP = 0
		gP = 1
		bP = X	
	elseif H<240 then
		rP = 0
		gP = X
		bP = 1	
	elseif H<300 then
		rP = X
		gP = 0
		bP = 1
	else
		rP = 1
		gP = 0
		bP = X
	end
	return(math.floor((rP)*255)*65536+math.floor((gP)*255)*256+math.floor((bP)*255))
end

local function holoset(x,y,z,value,rawString)
	--nesting for setRaw() is x z y
	--holograms are 48x32x48 X-Y-Z
	--for x=11 z=17 y=31
	--then location in sting is 
	--loc = (x-1)*48*32	+ (z-1)*32 + y
	return(string.sub(rawString,1,(x-1)*1536+(z-1)*32+y-1)..tostring(value)..string.sub(rawString,(x-1)*1536+(z-1)*32+y+1))
end

local function writeToHolo(text, avgTPS)
	local timeGlyph = cvtToGlyp(text)
	local bm = {}
	
	for token in timeGlyph:gmatch("([^\r\n]*)") do
		if token ~= "" then
			table.insert(bm, token)
		end
	end
	local zDepth = 26
	local xStart = 10 --Space from left boundry 
	local yStart = 5  --Space from bottom boundry
	local xFront = 0
	local xBack = 0
	local rawString = rawHoloTxtBase --starts fresh with no TPS numbers on rawString
	if ColorAdjust==true then holo.setPaletteColor(2,getColor(avgTPS)) end
	for i=1, 28 do --Each number is 5 wide, and the decimal is 4 wide. Between each character is an additional space.  With 4 numbers, One decimal and 4 padds thats a length of 28
				   --Reads from left to right
		xFront = xStart + i --writes forward (so it decides which x colum it should be writing to)
		xBack = 48-xStart - i --writes backward (so it decides which x colum it should be writing to)
		for j=1, 7 do  --reads from bottom to top
			local y = yStart + j
			if bm[8-j]:sub(i, i) ~= " " then
				rawString = holoset(xFront, y, zDepth, 2,rawString)
				rawString = holoset(xBack, y, zDepth-3, 2,rawString)
			end
		end
	end
	holo.setRaw(rawString) --uses setRaw so that you dont get a flickering effect from the hologram as it redraws it pixel by pixel
						   --Also makes drawing on holograms faster since it does less API calls, depends on complexity of scence but can speed up by 200%
end

local realTimeOld = 0
local realTimeNew = 0
local realTimeDiff = 0

local TPS = {}
local avgTPS = 0
for tSlot=1,10 do
	TPS[tSlot]=0
end

print("To exit hold down Ctrl + W\n")
for i=1, math.huge do
	for tSlot = 1, 10 do --main averaging loop that measures individual TPS and puts it into a cycling table location
		realTimeOld = time()
		os.sleep(timeConstant) --waits for an estimated ammount game seconds
		realTimeNew = time()

		realTimeDiff = realTimeNew-realTimeOld
		
		TPS[tSlot] = 20000*timeConstant/realTimeDiff
		avgTPS = (TPS[1]+TPS[2]+TPS[3]+TPS[4]+TPS[5]+TPS[6]+TPS[7]+TPS[8]+TPS[9]+TPS[10])/10
		--print("Server is running at\n"..tostring(TPS[tSlot]).." TPS\nAveraged Value is\n"..tostring(avgTPS).." TPS")
		writeToHolo(string.sub(tostring(avgTPS)..".000",1,5),avgTPS) --The .000 is needed because sometimes tps is exactly 20 and writeToHolo() is expecting 5 characters, not 2
		
		if keyboard.isKeyDown(keyboard.keys.w) and keyboard.isControlDown() then
			print("Exiting...")
			holo.clear()
			os.exit()
		end
		
	end
end