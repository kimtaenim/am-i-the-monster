-- 공포 엔딩 연출을 내 화면에 보여줘요. (어두워지는 화면, 큰 해설, 하얀 번쩍임, 괴물 쪽으로 카메라)
-- 서버가 "Intro → Reveal → Transform → Catch → Final → Clear" 순서로 신호를 보내요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)

local E = Config.Ending
local UI = Config.UI
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")

local FADE = TweenInfo.new(UI.NarrationFadeSeconds)

-- 화면을 덮는 어둠
local dark = Instance.new("Frame")
dark.Name = "EndingDark"
dark.Size = UDim2.fromScale(1, 1)
dark.BackgroundColor3 = Color3.new(0, 0, 0)
dark.BackgroundTransparency = 1
dark.ZIndex = 50
dark.Visible = false
dark.Parent = gui

local function makeText(name: string, y: number, height: number, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, y, 0)
	label.Size = UDim2.new(0.9, 0, 0, height)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextWrapped = true
	label.TextTransparency = 1
	label.ZIndex = 52
	label.Text = ""
	label.Parent = dark
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = label
	return label
end

local mainText = makeText("Main", 0.25, 160, 56, Color3.fromRGB(255, 225, 215))
local subText = makeText("Sub", 0.52, 60, 34, Color3.fromRGB(255, 170, 150))
local smallText = makeText("Small", 0.68, 50, 28, Color3.fromRGB(220, 220, 225))

-- 하얀 번쩍임
local flash = Instance.new("Frame")
flash.Name = "EndingFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 60
flash.Parent = gui

local function show(label: TextLabel, text: string)
	label.Text = text
	label.TextTransparency = 1
	TweenService:Create(label, FADE, { TextTransparency = 0 }):Play()
end

local function hide(label: TextLabel)
	TweenService:Create(label, FADE, { TextTransparency = 1 }):Play()
end

local function doFlash()
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(E.FlashSeconds), { BackgroundTransparency = 1 }):Play()
end

local function resetCamera()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

Remotes.Ending.OnClientEvent:Connect(function(stage: string, data)
	if stage == "Intro" then
		dark.Visible = true
		dark.BackgroundTransparency = 1
		TweenService:Create(dark, FADE, { BackgroundTransparency = E.DarkTransparency }):Play()
		show(mainText, data.Text)
		hide(subText)
		hide(smallText)
	elseif stage == "Reveal" then
		doFlash()
		show(mainText, data.Text)
		show(subText, data.Sub)
	elseif stage == "Transform" then
		show(mainText, data.Text)
		hide(subText)
		if data.Focus then
			Workspace.CurrentCamera.CameraSubject = data.Focus -- 괴물 쪽으로 카메라
		end
	elseif stage == "Catch" then
		doFlash()
		hide(mainText)
		show(smallText, data.Text)
	elseif stage == "Final" then
		hide(smallText)
		show(mainText, data.Text)
	elseif stage == "Clear" then
		dark.Visible = false
		mainText.TextTransparency = 1
		subText.TextTransparency = 1
		smallText.TextTransparency = 1
		resetCamera()
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(resetCamera)
end)
