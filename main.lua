local camera = require('plugin.camera')
local widget = require('widget')

display.setDefault('background', 1, 1, 1)

-- Camera settings.
local useFrontCamera = true
local desiredWidth = 640
local desiredHeight = 480
local countdownSeconds = 5

-- Preview rectangle.
local view = display.newRect(display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)

-- Face silhouette image.
local outline = display.newImage('outline.png', display.contentCenterX, display.contentCenterY)
local scale = 0.8 * display.contentWidth / outline.width
outline:scale(scale, scale)

-- Countdown timer label.
local countdownLabel = display.newText{text = '', x = display.contentCenterX, y = 20, fontSize = 40, font = native.systemFontBold}
countdownLabel:setFillColor(0.2, 0.8, 0.2, 1)

-- Local stuff.
local isPreviewing = false
local captureTimer = nil
local cameraTexture = nil
local shouldInvalidate = true

-- Display camera images when they become available or clear things up when camera closes.
Runtime:addEventListener('enterFrame', function()
	if isPreviewing then
		if not cameraTexture then
			-- Query if camera has an image ready.
			cameraTexture = camera.newTexture()
			if cameraTexture then
				-- Got first camera image.
				-- Setup preview rectange.
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
				view.xScale = (useFrontCamera and -1 or 1) * scale -- Mirror preview if using the front camera.
				view.yScale = scale
			end
		else
			-- Update image from the camera.
			-- Reduce FPS by half.
			if shouldInvalidate then
				cameraTexture:invalidate()
				shouldInvalidate = false
			else
				shouldInvalidate = true
			end
		end
	else
		if cameraTexture then
			-- Clear texture when camera closes.
			cameraTexture:releaseSelf()
			cameraTexture = nil
			view.fill = {0}
		end
	end
end)

-- Save photo to the media library in original size and without mirroring.
local function capturePhoto()
	local photo = display.newImage(cameraTexture.filename, cameraTexture.baseDir, 0, 2 * display.contentHeight)
	photo.anchorY = 0
	local filename = 'photo.png'
	display.save(photo, {filename = filename, baseDir = system.TemporaryDirectory, captureOffscreenArea = true})
	media.save(filename, system.TemporaryDirectory)
	photo:removeSelf()
end

--[[
Possible orientations:
	'portrait'
	'landscapeLeft'
	'portraitUpsideDown'
	'landscapeRight'
]]

-- Start the camera.
local function startPreviewing()
	-- Get available resolutions for the camera.
	local supportedSizes = camera.getSupportedSizes(useFrontCamera)
	if not supportedSizes then
		print('Camera is not available.')
		return
	end
	-- Find the best matching resolution.
	local optimalWidth, optimalHeight = 0, 0
	local optimalDiff = nil
	for i = 1, #supportedSizes do
		local size = supportedSizes[i]
		local w, h = size[1], size[2]
		print('Supported resolution: ' .. tostring(w) .. 'x' .. tostring(h))
		local diff = math.pow(desiredWidth - w, 2) + math.pow(desiredHeight - h, 2)
		if not optimalDiff or diff < optimalDiff then
			optimalWidth, optimalHeight = w, h
			optimalDiff = diff
		end
	end
	print('Picked resolution: ' .. tostring(optimalWidth) .. 'x' .. tostring(optimalHeight))
	local systemOrientation = system.orientation
	-- Adjust for iOS specific orientations.
	if systemOrientation == 'faceUp' or systemOrientation == 'faceDown' then
		systemOrientation = 'portrait'
	end
	-- Start the camera. It will ask for a permission first.
	camera.start({
		width = optimalWidth,
		height = optimalHeight,
		orientation = system.orientation,
		useFrontCamera = useFrontCamera

	})
	isPreviewing = true
end

-- Stop the camera.
local function stopPreviewing()
	if isPreviewing then
		camera.stop()
	end
	isPreviewing = false
end

-- Start/stop button.
local w, h = display.contentWidth * 0.4, 50
widget.newButton{
	x = display.contentCenterX, y = display.contentHeight - 20,
	width = w, height = h,
	label = 'Start / Stop',
	onRelease = function()
		if not isPreviewing then
			startPreviewing()
			-- Start the countdown to make a photo.
			countdownLabel.text = tostring(countdownSeconds)
			captureTimer = timer.performWithDelay(1000, function(event)
				countdownLabel.text = tostring(countdownSeconds - event.count)
				if event.count == countdownSeconds then
					captureTimer = nil
					capturePhoto()
					countdownLabel.text = ''
					stopPreviewing()
				end
			end, countdownSeconds)
		else
			if captureTimer then
				timer.cancel(captureTimer)
				captureTimer = nil
				countdownLabel.text = ''
			end
			stopPreviewing()
		end
	end
}