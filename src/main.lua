local gameStarted = false
local showDeclaration = false
local declarationTimer = 0

local stats = {
	totalGames = 0,
	highScore = 0,
	highLines = 0,
	highLevel = 0,
}

local bgmTracks = {}
local currentBgmIndex = 1

local gameFont = nil

local game = {}
local screen = {}
local touch = {}
local particles = {}

local sounds = {}
local bgm = nil

local COLS = 10
local ROWS = 20
local BLOCK_SIZE = 15
local DROP_SPEED = 0.8

local shakeDuration = 0
local shakeIntensity = 0

local currentColor = { 1, 1, 1 }
local targetColor = { 1, 1, 1 }
local colorTransition = 0

local gameStartTime = 0
local gameTime = 0

local restartPressCount = 0
local restartPressTimer = 0

local SHAPES = {
	{
		{ 0, 0, 0, 0 },
		{ 1, 1, 1, 1 },
		{ 0, 0, 0, 0 },
		{ 0, 0, 0, 0 },
	},
	{
		{ 1, 1 },
		{ 1, 1 },
	},
	{
		{ 0, 1, 0 },
		{ 1, 1, 1 },
		{ 0, 0, 0 },
	},
	{
		{ 0, 1, 1 },
		{ 1, 1, 0 },
		{ 0, 0, 0 },
	},
	{
		{ 1, 1, 0 },
		{ 0, 1, 1 },
		{ 0, 0, 0 },
	},
	{
		{ 1, 0, 0 },
		{ 1, 1, 1 },
		{ 0, 0, 0 },
	},
	{
		{ 0, 0, 1 },
		{ 1, 1, 1 },
		{ 0, 0, 0 },
	},
}

function love.load()
	math.randomseed(os.time())
	love.math.setRandomSeed(os.time())
	if love.filesystem.getInfo("stats.txt") then
		local content = love.filesystem.read("stats.txt")
		local games, highScore, highLines, highLevel = content:match("(%d+),(%d+),(%d+),(%d+)")
		if games then
			stats.totalGames = tonumber(games)
			stats.highScore = tonumber(highScore)
			stats.highLines = tonumber(highLines)
			stats.highLevel = tonumber(highLevel)
		end
	end

	love.audio.setVolume(1.0)

	if love.audio.setMixWithSystem then
		love.audio.setMixWithSystem(true)
	end

	if love.audio.restart then
		love.audio.restart()
	end

	love.window.setMode(0, 0, {
		fullscreen = true,
		resizable = false,
	})

	screen.width = love.graphics.getWidth()
	screen.height = love.graphics.getHeight()

	screen.isLandscape = screen.width > screen.height

	game.boardWidth = COLS * BLOCK_SIZE
	game.boardHeight = ROWS * BLOCK_SIZE

	game.offsetX = (screen.width - game.boardWidth) / 2
	game.offsetY = (screen.height - game.boardHeight) / 2

	local leftButtonX = game.offsetX - 200
	local rightButtonX = game.offsetX + game.boardWidth + 90
	local centerY = screen.height / 2

	touch.buttons = {
		left = { x = leftButtonX - 40, y = centerY + 40, w = 50, h = 50, label = "<", pressed = false, timer = 0 },
		right = { x = leftButtonX + 30, y = centerY + 40, w = 50, h = 50, label = ">", pressed = false, timer = 0 },
		fastDown = { x = leftButtonX - 5, y = centerY + 110, w = 50, h = 50, label = "⬇", pressed = false, timer = 0 },
		rotate = {
			x = rightButtonX + 20,
			y = centerY + 50,
			w = 50,
			h = 50,
			label = "↻",
			pressed = false,
			timer = 0,
		},
		instant = {
			x = rightButtonX + 90,
			y = centerY + 50,
			w = 120,
			h = 50,
			label = "Instant",
			pressed = false,
			timer = 0,
		},
		restart = { x = screen.width - 155, y = 40, w = 130, h = 50, label = "Restart", pressed = false, timer = 0 },
		pause = { x = 40, y = 40, w = 80, h = 50, label = "Pause", pressed = false, timer = 0 },
		hold = { x = leftButtonX + 120, y = centerY - 50, w = 50, h = 50, label = "", pressed = false, timer = 0 },
	}

	touch.repeatDelay = 0.05
	touch.initialDelay = 0.2

	local fontSize = 18
	local success, customFont = pcall(function()
		return love.graphics.newFont("font.woff", fontSize)
	end)

	if success then
		love.graphics.setFont(customFont)
		gameFont = customFont
		touch.buttonFont = love.graphics.newFont("font.woff", 34)
		touch.smallButtonFont = love.graphics.newFont("font.woff", 24)
		touch.tinyFont = love.graphics.newFont("font.woff", 16)
	end

	local musicFiles =
		{ "1tamara2-metal-1-1207.mp3", "psychronic-16-bit-showdown-381232.mp3", "absounds-16-bit-action-274036.mp3" }
	for _, file in ipairs(musicFiles) do
		local success, music = pcall(function()
			return love.audio.newSource(file, "stream")
		end)
		if success then
			music:setLooping(true)
			music:setVolume(0.8)
			table.insert(bgmTracks, music)
		end
	end

	if #bgmTracks > 0 then
		bgm = bgmTracks[1]
		currentBgmIndex = 1
	end

	loadSounds()
	game:init()

	if bgm then
		bgm:pause()
	end
end

function saveStats()
	local data = string.format("%d,%d,%d,%d", stats.totalGames, stats.highScore, stats.highLines, stats.highLevel)
	love.filesystem.write("stats.txt", data)
end

function updateStats(score, lines, level)
	stats.totalGames = stats.totalGames + 1
	if score > stats.highScore then
		stats.highScore = score
	end
	if lines > stats.highLines then
		stats.highLines = lines
	end
	if level > stats.highLevel then
		stats.highLevel = level
	end
	saveStats()
end

function selectRandomBGM()
	if #bgmTracks <= 1 then
		return
	end
	local newIndex
	repeat
		newIndex = love.math.random(1, #bgmTracks)
	until newIndex ~= currentBgmIndex
	currentBgmIndex = newIndex
	bgm = bgmTracks[currentBgmIndex]
end

function loadSounds()
	local function loadSound(name)
		local success, sound = pcall(function()
			return love.audio.newSource(name .. ".mp3", "static")
		end)
		if success then
			sounds[name] = sound
		end
	end

	loadSound("button")
	loadSound("drop")
	loadSound("clear")
end

function playSound(name)
	if sounds[name] then
		sounds[name]:stop()
		sounds[name]:play()
	end
end

function vibrate(duration)
	duration = duration or 0.05
	if love.system and love.system.vibrate then
		love.system.vibrate(duration)
	end
end

function triggerShake(duration, intensity)
	shakeDuration = duration or 0.3
	shakeIntensity = intensity or 5
end

function randomColor()
	local colors = {
		{ 1, 1, 1 },
		{ 1, 0.3, 0.3 },
		{ 0.3, 1, 0.3 },
		{ 0.3, 0.3, 1 },
		{ 1, 1, 0.3 },
		{ 1, 0.3, 1 },
		{ 0.3, 1, 1 },
		{ 1, 0.6, 0.3 },
	}
	return colors[math.random(#colors)]
end

function updateColor(dt)
	if colorTransition > 0 then
		colorTransition = colorTransition - dt * 2
		if colorTransition < 0 then
			colorTransition = 0
		end

		local t = 1 - colorTransition
		currentColor[1] = currentColor[1] + (targetColor[1] - currentColor[1]) * t
		currentColor[2] = currentColor[2] + (targetColor[2] - currentColor[2]) * t
		currentColor[3] = currentColor[3] + (targetColor[3] - currentColor[3]) * t
	end
end

function createExplosion(row)
	local count = 12 + math.random(6)
	for i = 1, count do
		local particle = {
			x = game.offsetX + math.random(COLS) * BLOCK_SIZE - BLOCK_SIZE / 2,
			y = game.offsetY + (row - 1) * BLOCK_SIZE + BLOCK_SIZE / 2,
			vx = (math.random() - 0.5) * 300,
			vy = (math.random() - 1) * 400 - 100,
			size = math.random(4, 10),
			alpha = 1,
			life = 0.5 + math.random() * 0.3,
			maxLife = 0,
			rotation = math.random() * math.pi * 2,
			rotSpeed = (math.random() - 0.5) * 10,
			color = { currentColor[1], currentColor[2], currentColor[3] },
		}
		particle.maxLife = particle.life
		table.insert(particles, particle)
	end
end

function updateParticles(dt)
	for i = #particles, 1, -1 do
		local p = particles[i]
		p.life = p.life - dt

		if p.life <= 0 then
			table.remove(particles, i)
		else
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt
			p.vy = p.vy + 1000 * dt
			p.rotation = p.rotation + p.rotSpeed * dt
			p.alpha = p.life / p.maxLife
		end
	end
end

function drawParticles()
	for _, p in ipairs(particles) do
		love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.alpha * 0.8)
		love.graphics.push()
		love.graphics.translate(p.x, p.y)
		love.graphics.rotate(p.rotation)
		love.graphics.rectangle("fill", -p.size / 2, -p.size / 2, p.size, p.size)
		love.graphics.pop()
	end
end

function formatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

function generateBag()
	local bag = {}
	for i = 1, #SHAPES do
		bag[i] = SHAPES[i]
	end
	for i = #bag, 2, -1 do
		local j = math.random(i)
		bag[i], bag[j] = bag[j], bag[i]
	end
	return bag
end

function game:init()
	self.board = {}
	for y = 1, ROWS do
		self.board[y] = {}
		for x = 1, COLS do
			self.board[y][x] = 0
		end
	end

	if bgm and bgm:isPlaying() then
		bgm:stop()
	end
	if gameStarted then
		selectRandomBGM()
		if bgm then
			bgm:play()
		end
	end

	particles = {}

	self.score = 0
	self.lines = 0
	self.level = 1
	self.gameOver = false
	self.paused = false

	self.holdPiece = nil
	self.canHold = true

	self.pieceQueue = {}
	local bag = generateBag()
	for _, shape in ipairs(bag) do
		table.insert(self.pieceQueue, shape)
	end
	self.nextPiece = self.pieceQueue[1]

	currentColor = { 1, 1, 1 }
	targetColor = { 1, 1, 1 }
	colorTransition = 0

	gameStartTime = love.timer.getTime()
	gameTime = 0

	self:spawnPiece()
	self.dropTimer = 0
	self.lockDelay = 0.5
	self.lockTimer = 0
	self.lastActionTime = 0
end

function game:spawnPiece()
	if #self.pieceQueue == 0 then
		local bag = generateBag()
		for _, shape in ipairs(bag) do
			table.insert(self.pieceQueue, shape)
		end
	end

	local shapeIndex = self.pieceQueue[1]
	table.remove(self.pieceQueue, 1)

	if #self.pieceQueue < 3 then
		local bag = generateBag()
		for _, shape in ipairs(bag) do
			table.insert(self.pieceQueue, shape)
		end
	end

	self.currentPiece = {
		shape = shapeIndex,
		x = math.floor(COLS / 2) - 1,
		y = 0,
	}

	self.canHold = true
	self.nextPiece = self.pieceQueue[1]

	if self:checkCollision(self.currentPiece.x, self.currentPiece.y, self.currentPiece.shape) then
		self.gameOver = true
		if bgm then
			bgm:stop()
		end
		gameTime = love.timer.getTime() - gameStartTime
		restartPressCount = 0

		updateStats(self.score, self.lines, self.level)
	end
end

function game:checkCollision(px, py, shape)
	for y = 1, #shape do
		for x = 1, #shape[y] do
			if shape[y][x] == 1 then
				local boardX = px + x - 1
				local boardY = py + y - 1

				if boardX < 1 or boardX > COLS or boardY > ROWS then
					return true
				end

				if boardY >= 1 and self.board[boardY][boardX] == 1 then
					return true
				end
			end
		end
	end
	return false
end

function game:lockPiece()
	local shape = self.currentPiece.shape
	for y = 1, #shape do
		for x = 1, #shape[y] do
			if shape[y][x] == 1 then
				local boardY = self.currentPiece.y + y - 1
				local boardX = self.currentPiece.x + x - 1
				if boardY >= 1 then
					self.board[boardY][boardX] = 1
				end
			end
		end
	end

	vibrate(0.08)
	playSound("drop")

	self:clearLines()
	self:spawnPiece()
	self.lockTimer = 0
	self.lastActionTime = 0
end

function game:clearLines()
	local linesCleared = 0
	local clearedRows = {}

	local y = ROWS
	while y >= 1 do
		local complete = true
		for x = 1, COLS do
			if self.board[y][x] == 0 then
				complete = false
				break
			end
		end

		if complete then
			linesCleared = linesCleared + 1
			table.insert(clearedRows, y)

			for moveY = y, 2, -1 do
				for x = 1, COLS do
					self.board[moveY][x] = self.board[moveY - 1][x]
				end
			end
			for x = 1, COLS do
				self.board[1][x] = 0
			end
		else
			y = y - 1
		end
	end

	if linesCleared > 0 then
		playSound("clear")

		for _, row in ipairs(clearedRows) do
			createExplosion(row)
		end

		self.lines = self.lines + linesCleared
		self.score = self.score + (linesCleared * 100 * self.level)

		local newLevel = math.floor(self.lines / 10) + 1
		if newLevel > self.level then
			self.level = newLevel
			targetColor = randomColor()
			colorTransition = 1
		end

		local shakeTime = 0.1 + (linesCleared * 0.1)
		local shakePower = 3 + (linesCleared * 2)
		triggerShake(shakeTime, shakePower)
		vibrate(0.15 + (linesCleared * 0.05))
	end
end

function game:rotatePiece()
	local oldShape = self.currentPiece.shape
	local newShape = {}
	local size = #oldShape

	for y = 1, size do
		newShape[y] = {}
		for x = 1, size do
			newShape[y][x] = oldShape[size - x + 1][y]
		end
	end

	local rotated = false
	if not self:checkCollision(self.currentPiece.x, self.currentPiece.y, newShape) then
		self.currentPiece.shape = newShape
		rotated = true
	elseif not self:checkCollision(self.currentPiece.x - 1, self.currentPiece.y, newShape) then
		self.currentPiece.x = self.currentPiece.x - 1
		self.currentPiece.shape = newShape
		rotated = true
	elseif not self:checkCollision(self.currentPiece.x + 1, self.currentPiece.y, newShape) then
		self.currentPiece.x = self.currentPiece.x + 1
		self.currentPiece.shape = newShape
		rotated = true
	end

	if rotated then
		vibrate(0.03)
		self.lastActionTime = 0
		self.lockTimer = 0
	end
end

function game:hold()
	if self.gameOver or self.paused or not self.currentPiece then
		return
	end
	if not self.canHold then
		return
	end

	local currentShape = self.currentPiece.shape

	if self.holdPiece == nil then
		self.holdPiece = currentShape
		self:spawnPiece()
		self.canHold = false
	else
		self.currentPiece.shape = self.holdPiece
		self.holdPiece = currentShape
		self.currentPiece.x = math.floor(COLS / 2) - 1
		self.currentPiece.y = 0

		if self:checkCollision(self.currentPiece.x, self.currentPiece.y, self.currentPiece.shape) then
			self.gameOver = true
			if bgm then
				bgm:stop()
			end
			gameTime = love.timer.getTime() - gameStartTime
			restartPressCount = 0
			updateStats(self.score, self.lines, self.level)
			return
		end
		self.canHold = false
	end

	self.lastActionTime = 0
	self.lockTimer = 0
	playSound("button")
	vibrate(0.03)
end

function game:movePiece(dx, dy)
	local newX = self.currentPiece.x + dx
	local newY = self.currentPiece.y + dy

	if not self:checkCollision(newX, newY, self.currentPiece.shape) then
		self.currentPiece.x = newX
		self.currentPiece.y = newY
		self.lastActionTime = 0
		self.lockTimer = 0
		return true
	end
	return false
end

function game:fastDown()
	if self:movePiece(0, 1) then
		self.score = self.score + 1
		return true
	end
	return false
end

function game:instant()
	local dropped = false
	local shape = self.currentPiece.shape
	local startY = self.currentPiece.y

	while self:movePiece(0, 1) do
		self.score = self.score + 2
		dropped = true
	end

	if dropped then
		local endY = self.currentPiece.y
		local distance = endY - startY
		local steps = 4

		for step = 1, steps do
			local progress = step / steps
			local yPos = startY + distance * progress

			for y = 1, #shape do
				for x = 1, #shape[y] do
					if shape[y][x] == 1 then
						local col = self.currentPiece.x + x
						local row = yPos + y
						local px = game.offsetX + (col - 2) * BLOCK_SIZE + BLOCK_SIZE / 2
						local py = game.offsetY + (row - 2) * BLOCK_SIZE + BLOCK_SIZE / 2

						local alpha = 0.2 * progress
						local brightness = 0.3 + 0.7 * progress
						local color = {
							currentColor[1] * brightness,
							currentColor[2] * brightness,
							currentColor[3] * brightness,
						}

						local particle = {
							x = px,
							y = py,
							vx = 0,
							vy = 0,
							size = BLOCK_SIZE,
							alpha = alpha,
							life = 0.15,
							maxLife = 0.15,
							rotation = 0,
							rotSpeed = 0,
							color = color,
						}
						particle.maxLife = particle.life
						table.insert(particles, particle)
					end
				end
			end
		end

		vibrate(0.1)
		triggerShake(0.15, 4)
	end

	self:lockPiece()
end

function game:update(dt)
	if self.gameOver or self.paused then
		return
	end

	gameTime = love.timer.getTime() - gameStartTime

	self.lastActionTime = self.lastActionTime + dt

	self.dropTimer = self.dropTimer + dt
	local currentSpeed = math.max(0.05, DROP_SPEED - (self.level - 1) * 0.1)

	if self.dropTimer >= currentSpeed then
		if not self:movePiece(0, 1) then
			if self.lastActionTime >= 0.2 then
				self.lockTimer = self.lockTimer + self.dropTimer
				if self.lockTimer >= self.lockDelay then
					self:lockPiece()
				end
			else
				self.lockTimer = 0
			end
		else
			self.lockTimer = 0
		end
		self.dropTimer = 0
	end
end

function updateTouchButtons(dt)
	if restartPressTimer > 0 then
		restartPressTimer = restartPressTimer - dt
		if restartPressTimer <= 0 then
			restartPressCount = 0
		end
	end

	for name, btn in pairs(touch.buttons) do
		if btn.pressed then
			btn.timer = btn.timer + dt

			local delay = btn.firstPress and touch.initialDelay or touch.repeatDelay

			if btn.timer >= delay then
				btn.timer = 0
				btn.firstPress = false

				if name == "left" then
					if game:movePiece(-1, 0) then
						vibrate(0.02)
					end
				elseif name == "right" then
					if game:movePiece(1, 0) then
						vibrate(0.02)
					end
				elseif name == "rotate" then
					game:rotatePiece()
				elseif name == "instant" then
					game:instant()
				elseif name == "fastDown" then
					game:fastDown()
				elseif name == "pause" then
					game.paused = not game.paused
					playSound("button")
					if game.paused then
						if bgm and bgm:isPlaying() then
							bgm:pause()
						end
					else
						if bgm and not bgm:isPlaying() and not game.gameOver then
							bgm:play()
						end
					end
				elseif name == "restart" then
					if game.gameOver then
						restartPressCount = restartPressCount + 1
						restartPressTimer = 0.5
						if restartPressCount >= 3 then
							restartPressCount = 0
							game:init()
							playSound("button")
							vibrate(0.1)
						end
					else
						restartPressCount = restartPressCount + 1
						restartPressTimer = 0.5
						if restartPressCount >= 3 then
							restartPressCount = 0
							game:init()
							playSound("button")
							vibrate(0.1)
						end
					end
				end
			end
		end
	end
end

function game:draw()
	game.offsetX = (screen.width - game.boardWidth) / 2
	game.offsetY = (screen.height - game.boardHeight) / 2
	local shakeX, shakeY = 0, 0
	if shakeDuration > 0 then
		shakeX = (math.random() - 0.5) * shakeIntensity * 2
		shakeY = (math.random() - 0.5) * shakeIntensity * 2
	end

	touch:draw()

	love.graphics.push()
	love.graphics.translate(shakeX, shakeY)

	love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
	love.graphics.rectangle("line", game.offsetX - 2, game.offsetY - 2, game.boardWidth + 4, game.boardHeight + 4)

	for y = 1, ROWS do
		for x = 1, COLS do
			if self.board[y][x] == 1 then
				local px = game.offsetX + (x - 1) * BLOCK_SIZE
				local py = game.offsetY + (y - 1) * BLOCK_SIZE
				love.graphics.rectangle("fill", px + 1, py + 1, BLOCK_SIZE - 2, BLOCK_SIZE - 2)
			end
		end
	end

	if self.currentPiece then
		love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
		local shape = self.currentPiece.shape
		for y = 1, #shape do
			for x = 1, #shape[y] do
				if shape[y][x] == 1 then
					local px = game.offsetX + (self.currentPiece.x + x - 2) * BLOCK_SIZE
					local py = game.offsetY + (self.currentPiece.y + y - 2) * BLOCK_SIZE
					if py >= game.offsetY then
						love.graphics.rectangle("fill", px + 1, py + 1, BLOCK_SIZE - 2, BLOCK_SIZE - 2)
					end
				end
			end
		end

		love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3], 0.3)
		local ghostY = self.currentPiece.y
		while not self:checkCollision(self.currentPiece.x, ghostY + 1, shape) do
			ghostY = ghostY + 1
		end

		for y = 1, #shape do
			for x = 1, #shape[y] do
				if shape[y][x] == 1 then
					local px = game.offsetX + (self.currentPiece.x + x - 2) * BLOCK_SIZE
					local py = game.offsetY + (ghostY + y - 2) * BLOCK_SIZE
					if py >= game.offsetY then
						love.graphics.rectangle("line", px + 1, py + 1, BLOCK_SIZE - 2, BLOCK_SIZE - 2)
					end
				end
			end
		end
	end

	love.graphics.setColor(currentColor[1] * 0.2, currentColor[2] * 0.2, currentColor[3] * 0.2)
	for x = 0, COLS do
		love.graphics.line(
			game.offsetX + x * BLOCK_SIZE,
			game.offsetY,
			game.offsetX + x * BLOCK_SIZE,
			game.offsetY + game.boardHeight
		)
	end
	for y = 0, ROWS do
		love.graphics.line(
			game.offsetX,
			game.offsetY + y * BLOCK_SIZE,
			game.offsetX + game.boardWidth,
			game.offsetY + y * BLOCK_SIZE
		)
	end

	love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
	love.graphics.print("TIME: " .. formatTime(gameTime), game.offsetX + game.boardWidth + 50, game.offsetY)
	love.graphics.print("SCORE: " .. self.score, game.offsetX + game.boardWidth + 50, game.offsetY + 25)
	love.graphics.print("LINES: " .. self.lines, game.offsetX + game.boardWidth + 50, game.offsetY + 50)
	love.graphics.print("LEVEL: " .. self.level, game.offsetX + game.boardWidth + 50, game.offsetY + 75)

	local holdBtn = touch.buttons.hold
	if holdBtn then
		local oldFont = love.graphics.getFont()
		if touch.tinyFont then
			love.graphics.setFont(touch.tinyFont)
		end

		local text = "HOLD"
		local textW = love.graphics.getFont():getWidth(text)
		local textH = love.graphics.getFont():getHeight()
		local textX = holdBtn.x + (holdBtn.w - textW) / 2
		local textY = holdBtn.y - textH / 2
		local gap = 3

		if self.holdPiece then
			local margin = 4
			local cellSize = (holdBtn.w - 2 * margin) / 4
			local shapeWidth = #self.holdPiece[1]
			local shapeHeight = #self.holdPiece
			local totalWidth = shapeWidth * cellSize
			local totalHeight = shapeHeight * cellSize
			local startX = holdBtn.x + (holdBtn.w - totalWidth) / 2
			local startY = holdBtn.y + (holdBtn.h - totalHeight) / 2
			love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
			for y = 1, shapeHeight do
				for x = 1, shapeWidth do
					if self.holdPiece[y][x] == 1 then
						local px = startX + (x - 1) * cellSize
						local py = startY + (y - 1) * cellSize
						love.graphics.rectangle("fill", px + 1, py + 1, cellSize - 2, cellSize - 2)
					end
				end
			end
		end

		love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
		love.graphics.line(holdBtn.x, holdBtn.y, holdBtn.x, holdBtn.y + holdBtn.h)
		love.graphics.line(holdBtn.x, holdBtn.y + holdBtn.h, holdBtn.x + holdBtn.w, holdBtn.y + holdBtn.h)
		love.graphics.line(holdBtn.x + holdBtn.w, holdBtn.y, holdBtn.x + holdBtn.w, holdBtn.y + holdBtn.h)
		love.graphics.line(holdBtn.x, holdBtn.y, textX - gap, holdBtn.y)
		love.graphics.line(textX + textW + gap, holdBtn.y, holdBtn.x + holdBtn.w, holdBtn.y)

		love.graphics.print(text, textX, textY)

		love.graphics.setFont(oldFont)
	end

	local nextX = holdBtn.x
	local nextY = holdBtn.y - 95
	local nextW = holdBtn.w
	local nextH = holdBtn.h
	love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])

	local oldFont = love.graphics.getFont()
	if touch.tinyFont then
		love.graphics.setFont(touch.tinyFont)
	end
	local nextText = "NEXT"
	local textW = love.graphics.getFont():getWidth(nextText)
	local textH = love.graphics.getFont():getHeight()
	local textX = nextX + (nextW - textW) / 2
	local textY = nextY - textH / 2
	local gap = 3

	love.graphics.line(nextX, nextY, nextX, nextY + nextH)
	love.graphics.line(nextX, nextY + nextH, nextX + nextW, nextY + nextH)
	love.graphics.line(nextX + nextW, nextY, nextX + nextW, nextY + nextH)
	love.graphics.line(nextX, nextY, textX - gap, nextY)
	love.graphics.line(textX + textW + gap, nextY, nextX + nextW, nextY)

	love.graphics.print(nextText, textX, textY)

	if self.nextPiece then
		local margin = 4
		local cellSize = (nextW - 2 * margin) / 4
		local shapeWidth = #self.nextPiece[1]
		local shapeHeight = #self.nextPiece
		local totalWidth = shapeWidth * cellSize
		local totalHeight = shapeHeight * cellSize
		local startX = nextX + (nextW - totalWidth) / 2
		local startY = nextY + (nextH - totalHeight) / 2
		for y = 1, shapeHeight do
			for x = 1, shapeWidth do
				if self.nextPiece[y][x] == 1 then
					local px = startX + (x - 1) * cellSize
					local py = startY + (y - 1) * cellSize
					love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
					love.graphics.rectangle("fill", px + 1, py + 1, cellSize - 2, cellSize - 2)
				end
			end
		end
	end
	love.graphics.setFont(gameFont)

	if self.gameOver then
		love.graphics.setColor(0, 0, 0, 0.9)
		love.graphics.rectangle("fill", 0, 0, screen.width, screen.height)

		love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
		local centerX = screen.width / 2
		local startY = screen.height / 2 - 100

		love.graphics.printf("GAME OVER", 0, startY, screen.width, "center")
		love.graphics.printf("-------------", 0, startY + 25, screen.width, "center")
		love.graphics.printf("Time: " .. formatTime(gameTime), 0, startY + 60, screen.width, "center")
		love.graphics.printf("Score: " .. self.score, 0, startY + 90, screen.width, "center")
		love.graphics.printf("Lines: " .. self.lines, 0, startY + 120, screen.width, "center")
		love.graphics.printf("Level: " .. self.level, 0, startY + 150, screen.width, "center")
		love.graphics.printf("-------------", 0, startY + 185, screen.width, "center")

		if restartPressCount == 0 then
			love.graphics.printf("Tap 3 times to restart", 0, startY + 220, screen.width, "center")
		else
			love.graphics.printf(
				"Tap " .. (3 - restartPressCount) .. " more times",
				0,
				startY + 220,
				screen.width,
				"center"
			)
		end
	end

	if self.paused then
		love.graphics.setColor(0, 0, 0, 0.9)
		love.graphics.rectangle("fill", 0, 0, screen.width, screen.height)
		love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
		love.graphics.printf("PAUSED\n\nTap to Resume", 0, screen.height / 2 - 40, screen.width, "center")
	end

	love.graphics.pop()
end

function touch:draw()
	for name, btn in pairs(self.buttons) do
		if name == "hold" then
			goto continue
		end

		local oldFont = love.graphics.getFont()

		love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
		love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)

		if (name == "instant" or name == "restart" or name == "pause") and touch.smallButtonFont then
			love.graphics.setFont(touch.smallButtonFont)
		elseif touch.buttonFont and btn.label ~= "" then
			love.graphics.setFont(touch.buttonFont)
		end

		if btn.pressed then
			love.graphics.setColor(currentColor[1] * 0.5, currentColor[2] * 0.5, currentColor[3] * 0.5)
		else
			love.graphics.setColor(currentColor[1], currentColor[2], currentColor[3])
		end

		if btn.label and btn.label ~= "" then
			local textW = love.graphics.getFont():getWidth(btn.label)
			local textH = love.graphics.getFont():getHeight()
			love.graphics.print(btn.label, btn.x + (btn.w - textW) / 2, btn.y + (btn.h - textH) / 2)
		end

		love.graphics.setFont(oldFont)

		::continue::
	end
end

function touch:checkButtonPress(x, y)
	for name, btn in pairs(self.buttons) do
		if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
			return name
		end
	end
	return nil
end

local function game_update_fn(dt)
	screen.width = love.graphics.getWidth()
	screen.height = love.graphics.getHeight()

	if shakeDuration > 0 then
		shakeDuration = shakeDuration - dt
		if shakeDuration < 0 then
			shakeDuration = 0
			shakeIntensity = 0
		end
	end

	updateColor(dt)
	updateParticles(dt)
	updateTouchButtons(dt)
	game:update(dt)
end

local function game_draw_fn()
	love.graphics.setBackgroundColor(0, 0, 0)

	if screen.height > screen.width then
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("Please rotate to landscape", 0, screen.height / 2, screen.width, "center")
		return
	end

	game:draw()
	drawParticles()
end

local function game_touchpressed_fn(id, x, y, dx, dy, pressure)
	if screen.height > screen.width then
		return
	end

	if game.gameOver then
		restartPressCount = restartPressCount + 1
		restartPressTimer = 0.5
		if restartPressCount >= 3 then
			restartPressCount = 0
			game:init()
			vibrate(0.1)
		else
			vibrate(0.03)
			playSound("button")
		end
		return
	end

	if game.paused then
		game.paused = false
		if bgm and not bgm:isPlaying() and not game.gameOver then
			bgm:play()
		end
		return
	end

	local button = touch:checkButtonPress(x, y)
	if button then
		local btn = touch.buttons[button]
		btn.pressed = true
		btn.timer = 0
		btn.firstPress = true

		vibrate(0.03)
		playSound("button")

		if button == "left" then
			if game:movePiece(-1, 0) then
				vibrate(0.02)
			end
		elseif button == "right" then
			if game:movePiece(1, 0) then
				vibrate(0.02)
			end
		elseif button == "rotate" then
			game:rotatePiece()
		elseif button == "instant" then
			game:instant()
		elseif button == "fastDown" then
			game:fastDown()
		elseif button == "pause" then
			game.paused = not game.paused
			if game.paused then
				if bgm and bgm:isPlaying() then
					bgm:pause()
				end
			else
				if bgm and not bgm:isPlaying() and not game.gameOver then
					bgm:play()
				end
			end
		elseif button == "restart" then
			restartPressCount = restartPressCount + 1
			restartPressTimer = 0.5
			if restartPressCount >= 3 then
				restartPressCount = 0
				game:init()
				vibrate(0.1)
			end
		elseif button == "hold" then
			game:hold()
		end
	end
end

local function game_touchreleased_fn(id, x, y, dx, dy, pressure)
	for name, btn in pairs(touch.buttons) do
		btn.pressed = false
		btn.timer = 0
		btn.firstPress = false
	end
end

local function game_touchmoved_fn(id, x, y, dx, dy, pressure)
	for name, btn in pairs(touch.buttons) do
		if btn.pressed then
			if x < btn.x or x > btn.x + btn.w or y < btn.y or y > btn.y + btn.h then
				btn.pressed = false
				btn.timer = 0
				btn.firstPress = false
			end
		end
	end
end

function love.update(dt)
	if not gameStarted then
		if showDeclaration then
			declarationTimer = declarationTimer + dt
		end
	else
		game_update_fn(dt)
	end
end

function love.draw()
	if not gameStarted then
		love.graphics.setBackgroundColor(0, 0, 0)

		local centerX = love.graphics.getWidth() / 2
		local centerY = love.graphics.getHeight() / 2

		if love.graphics.getHeight() > love.graphics.getWidth() then
			love.graphics.setColor(1, 1, 1)
			if touch.smallButtonFont then
				love.graphics.setFont(touch.smallButtonFont)
			end
			love.graphics.printf("Please rotate to landscape", 0, centerY, love.graphics.getWidth(), "center")
			return
		end

		love.graphics.setColor(1, 1, 1)
		if touch.buttonFont then
			love.graphics.setFont(touch.buttonFont)
		end
		love.graphics.printf("BAM! BLOCKS", 0, centerY - 150, love.graphics.getWidth(), "center")

		if touch.tinyFont then
			love.graphics.setFont(touch.tinyFont)
		end
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("STATISTICS", 0, centerY - 80, love.graphics.getWidth(), "center")

		local statY = centerY - 50
		love.graphics.printf("Games: " .. stats.totalGames, 0, statY, love.graphics.getWidth(), "center")
		love.graphics.printf("High Score: " .. stats.highScore, 0, statY + 18, love.graphics.getWidth(), "center")
		love.graphics.printf("High Lines: " .. stats.highLines, 0, statY + 36, love.graphics.getWidth(), "center")
		love.graphics.printf("High Level: " .. stats.highLevel, 0, statY + 54, love.graphics.getWidth(), "center")

		if touch.buttonFont then
			love.graphics.setFont(touch.buttonFont)
		end
		love.graphics.rectangle("line", centerX - 100, centerY + 40, 200, 55)
		love.graphics.printf("START", 0, centerY + 50, love.graphics.getWidth(), "center")

		if touch.smallButtonFont then
			love.graphics.setFont(touch.smallButtonFont)
		end
		love.graphics.rectangle("line", centerX - 100, centerY + 110, 200, 40)
		love.graphics.printf("DECLARATION", 0, centerY + 117, love.graphics.getWidth(), "center")

		if showDeclaration then
			love.graphics.setColor(0, 0, 0, 0.95)
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

			love.graphics.setColor(1, 1, 1)
			if touch.buttonFont then
				love.graphics.setFont(touch.buttonFont)
			end
			love.graphics.printf("DECLARATION", 0, 50, love.graphics.getWidth(), "center")

			if touch.tinyFont then
				love.graphics.setFont(touch.tinyFont)
			end
			love.graphics.printf(
				[[Falling blocks, satisfying impacts. Made with LÖVE2D.

Inspired by Tetris but not affiliated with Tetris Holding,
LLC or The Tetris Company.

Font: GNU Unifont (GPLv2+ with Font Embedding Exception)
      © 1998-2020 Roman Czyborra, Paul Hardy, et al.
Audio: Sound Effects - soundgator.com | Music - pixabay.com

Developer: Tian | 2026]],
				200,
				130,
				love.graphics.getWidth() - 100,
				"left"
			)
		end
	else
		if gameFont then
			love.graphics.setFont(gameFont)
		end
		game_draw_fn()
	end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	if not gameStarted then
		local centerX = love.graphics.getWidth() / 2
		local centerY = love.graphics.getHeight() / 2

		if showDeclaration then
			showDeclaration = false
			declarationTimer = 0
			return
		end

		if x >= centerX - 100 and x <= centerX + 100 and y >= centerY + 50 and y <= centerY + 110 then
			playSound("button")
			vibrate(0.03)
			gameStarted = true
			selectRandomBGM()
			if bgm then
				bgm:play()
			end
			return
		end

		if x >= centerX - 100 and x <= centerX + 100 and y >= centerY + 120 and y <= centerY + 160 then
			playSound("button")
			vibrate(0.03)
			showDeclaration = true
			declarationTimer = 0
		end
	else
		game_touchpressed_fn(id, x, y, dx, dy, pressure)
	end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
	if gameStarted then
		game_touchreleased_fn(id, x, y, dx, dy, pressure)
	end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
	if gameStarted then
		game_touchmoved_fn(id, x, y, dx, dy, pressure)
	end
end

function love.focus(focused)
	if gameStarted then
		if not focused then
			if not game.gameOver then
				game.paused = true
			end
			if bgm and bgm:isPlaying() then
				bgm:pause()
			end
		else
		end
	end
end

function saveHighScore(score)
	if score > stats.highScore then
		stats.highScore = score
		saveStats()
	end
end