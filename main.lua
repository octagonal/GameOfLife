function love.load()
	audioDir = "audio/"
	stepCurrent = 0
	tileSize = 50
	gamePaused = true
	maxRatio = 0
	minRatio = 1
	maxCells = tileSize*tileSize
	currentCells = 0
	drawSize = love.window.getWidth() / tileSize
	colorRange = 255
	colorMult = colorRange / tileSize
	mapCollection = { 
		{ drawSeed() }
		,{ drawSeed() }
		,{ drawSeed() }
		,{ drawSeed() }
		,{ drawSeed() }
	}

	userInput = {}

	love.graphics.setBackgroundColor(0,0,0,0)

	pitchMin = 1
	pitchMax = 5

	soundSine = love.audio.newSource( audioDir .. "Square_wave_1000.ogg", "static")
	soundSine:play()
	soundSine:setLooping(true)
	soundSine:setPitch(1)
end

function love.mousepressed(x,y,button)
	local userCol = math.ceil(x/drawSize)
	local userRow = math.ceil(y/drawSize)
	table.insert( userInput, { ["x"] = userCol, ["y"] = userRow } )
	--[[
	Cells activated in userInput are held in this table until redrawCells() is called,
	so userInput will usually only hold a single value unless the GOL is set in manual
	mode
	--]]
end

function drawSeed(threshold)
	local threshold = threshold or 0.9
	local seedMap = {}
	for i=1,tileSize do
		seedMap[i] = {}
		for j=1,tileSize do
			seedMap[i][j] = {}
			if math.random() > threshold then
				seedMap[i][j]["state"] = 1
				seedMap[i][j]["lifeCycles"] = 1
			else
				seedMap[i][j]["state"] = 0
				seedMap[i][j]["lifeCycles"] = 0
			end
		end
	end
	return seedMap
end

function love.update(dt)
	for i,grid in ipairs(mapCollection) do
		mapCollection[i][1] = redrawCells(mapCollection[i][1])
	end
	userInput = {}
end

function love.draw()
	for i=table.getn(mapCollection),1,-1 do
		drawGrid(
		mapCollection[i][1] 
		,i*((colorRange/5*4)/table.getn(mapCollection))
		)
	end
	screenShotWrapper("forGit")
end

function screenShotWrapper(baseName)
	local filename = ""
	if stepCurrent >= 10 and stepCurrent < 100 then
		filename = baseName .. "_0" 
	elseif stepCurrent < 10 then
		filename = baseName .. "_00"
	elseif stepCurrent >= 100 then
		filename = baseName .. "_"
	end
	filename = filename .. stepCurrent .. ".png"
	screenshot = love.graphics.newScreenshot()
	screenshot:encode(filename)
	stepCurrent = stepCurrent + 1
end

function drawGrid(inputMap, alpha, satur, light)
	currentCells = 0
	local alpha = alpha or 200
	local satur = satur or 200
	local light = light or 150
	for i,cellToAdd in ipairs(userInput) do
		love.graphics.setColor(HSL(255, 255, 255, 255 ))
		love.graphics.rectangle("fill", (cellToAdd["x"]-1) * drawSize , (cellToAdd["y"]-1) * drawSize , drawSize, drawSize )
	end
	for i,line in ipairs(inputMap) do
		for y,cell in ipairs(inputMap[i]) do
			if cell["state"] == 1 then
				currentCells = currentCells + 1
				love.graphics.setColor(HSL(cell["lifeCycles"] , satur, light, alpha ))
				love.graphics.rectangle("fill", (y-1) * drawSize , (i-1 ) * drawSize , drawSize , drawSize)
			else
				love.graphics.setColor(10, 10, 10, 200)
				love.graphics.rectangle("line", (y-1) * drawSize , (i-1 ) * drawSize , drawSize, drawSize )
			end
		end
	end 
	if(currentCells / maxCells) > maxRatio then
		maxRatio = currentCells / maxCells
		--print("New maximum => " .. math.floor(maxRatio * 1000)/10)
	elseif (currentCells / maxCells) < minRatio then
		minRatio = currentCells / maxCells
		--print("New minimum => " .. math.floor(minRatio * 1000)/10)
	end
	--print("Pitch => " .. ( math.floor((currentCells / maxCells) * 1000) / 10 ))

	soundSine:setPitch( (currentCells / maxCells) * 100 )
end

function love.keypressed(key)
	if key == "up" then
		for i,grid in ipairs(mapCollection) do
			mapCollection[i][1] = drawSeed()
		end
	end
	if key == "down" then
		for i,grid in ipairs(mapCollection) do
			mapCollection[i][1] = redrawCells(mapCollection[i][1])
		end
	end
end

function redrawCells(input)
	local tempMap = {}
	noneLeft = true
	for i,cellToAdd in ipairs(userInput) do
		input[cellToAdd["y"]][cellToAdd["x"]]["state"] = 1
		input[cellToAdd["y"]][cellToAdd["x"]]["lifeCycles"] = 1
	end
	for i,line in ipairs(input) do
		tempMap[i] = {}
		for j,cell in ipairs(input[i]) do
			tempMap[i][j] = {}
			currentlyAlive = false
			if input[i][j]["state"] == 1 then
				currentlyAlive = true
				noneLeft = false
			end
			neighbours = neighbourCount(input,i,j) 
			if stateAlive(currentlyAlive,neighbours) == true then
				tempMap[i][j]["state"] = 1
				tempMap[i][j]["lifeCycles"] = input[i][j]["lifeCycles"] + 1
			else
				tempMap[i][j]["state"] = 0
				tempMap[i][j]["lifeCycles"] = 0
			end
			if tempMap[i][j]["lifeCycles"] > 255 then
				tempMap[i][j]["lifeCycles"] = 255
			end
		end 
	end
	if noneLeft then
		drawSeed()
	end
	return tempMap
end

function neighbourCount(inputmap,i,y)
	local cellNeighbhours = 0
	for x=-1,1 do for z=-1,1 do
		if isInBounds(i-x) and isInBounds(y-z) then
			if inputmap[i-x][y-z]["state"] == 1 and ((x ~= 0) or (z ~= 0)) then
				cellNeighbhours = cellNeighbhours + 1
			end
		else 
			local yToroidal = toroidalBoundsPadding(y-z)
			local iToroidal = toroidalBoundsPadding(i-x)
			if inputmap[iToroidal][yToroidal]["state"] == 1 then
				cellNeighbhours = cellNeighbhours + 1
			end
		end
	end end
	return cellNeighbhours
end

function toroidalBoundsPadding(n)
	if (n <= 0) then
		return(tileSize-n)
	elseif (n > tileSize) then
		return(n-tileSize)
	end
	return n -- Other coordinate was out of bounds, return input
end

function isInBounds(n)
	if (n > 0) and (n <= tileSize ) then
		return true
	end
	return false
end

function stateAlive(currentlyAlive,cellNeighbhours)
	if currentlyAlive then
		if cellNeighbhours < 2 then
			return false
		elseif cellNeighbhours == 2 or cellNeighbhours == 3 then
			return true
		elseif cellNeighbhours > 3 then
			return false
		end
	elseif cellNeighbhours == 3 then
		return true
	end
end

function HSL(h, s, l, a)
	if s<=0 then return l,l,l,a end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1 then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else r,g,b = c,0,x
	end return (r+m)*255,(g+m)*255,(b+m)*255,a
end

--[[
-1 +1 0 +1 +1 +1
-1 0 **** +1 0
-1 -1 0 -1 +1 -1
--]]

--[[
Any live cell with fewer than two live neighbours dies, as if caused by under-population.
Any live cell with two or three live neighbours lives on to the next generation.
Any live cell with more than three live neighbours dies, as if by overcrowding.
Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
--]]
