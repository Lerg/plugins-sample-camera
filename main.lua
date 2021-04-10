local camera = require('plugin.camera')
local widget = require('widget')

display.setDefault('background', 1, 1, 1)

local presets = {
	{width = 352, height = 288},
	{width = 640, height = 480},
	{width = 1280, height = 720},
	{width = 1920, height = 1080},
	{width = 3840, height = 2160}
}

local isPreviewing = false
local captureTimer = nil
local cameraTexture = nil
local countdownSeconds = 5

local view = display.newRect(display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)

local outline = display.newImage('outline.png', display.contentCenterX, display.contentCenterY)
local scale = 0.8 * display.contentWidth / outline.width
outline:scale(scale, scale)

local countdownLabel = display.newText{text = '', x = display.contentCenterX, y = 20, fontSize = 40, font = native.systemFontBold}
countdownLabel:setFillColor(0.2, 0.8, 0.2, 1)

Runtime:addEventListener('enterFrame', function()
	if isPreviewing then
		if not cameraTexture then
			cameraTexture = camera.newTexture()
			if cameraTexture then
				view.fill = {
					type = 'image',
					filename = cameraTexture.filename,
					baseDir = cameraTexture.baseDir
				}
				local width, height = camera.getSize()
				print('Camera size:', width, height)
				view.width = width
				view.height = height
				local scale = math.min(display.contentWidth / width, display.contentHeight / height)
				view.xScale = scale
				view.yScale = scale
			end
		else
			cameraTexture:invalidate()
		end
	else
		if cameraTexture then
			cameraTexture:releaseSelf()
			cameraTexture = nil
			view.fill = {0}
		end
	end
end)

local function capturePhoto()
	local photo = display.newImage(cameraTexture.filename, cameraTexture.baseDir, 0, 2 * display.contentHeight)
	photo.anchorY = 0
	local filename = 'photo.png'
	display.save(photo, {filename = filename, baseDir = system.TemporaryDirectory, captureOffscreenArea = true})
	media.save(filename, system.TemporaryDirectory)
	photo:removeSelf()
end

--[[
Orientation:
	'portrait'
	'landscapeLeft'
	'portraitUpsideDown'
	'landscapeRight'
]]

local w, h = display.contentWidth * 0.4, 50
widget.newButton{
	x = display.contentCenterX, y = display.contentHeight - 20,
	width = w, height = h,
	label = 'Start / Stop',
	onRelease = function()
		if not isPreviewing then
			local preset = presets[2]
			camera.start({
				width = preset.width,
				height = preset.height,
				orientation = 'portrait',
				useFrontCamera = true

			})
			countdownLabel.text = tostring(countdownSeconds)
			captureTimer = timer.performWithDelay(1000, function(event)
				countdownLabel.text = tostring(countdownSeconds - event.count)
				if event.count == countdownSeconds then
					captureTimer = nil
					capturePhoto()
					countdownLabel.text = ''
				end
			end, countdownSeconds)
			isPreviewing = true
		else
			if captureTimer then
				timer.cancel(captureTimer)
				captureTimer = nil
			end
			camera.stop()
			isPreviewing = false
		end
	end
}