-- 밤 연출이에요. 졸리면 화면이 서서히 검어지고 "졸려..." 한 줄만 보여요.
-- 괴물에게 잡히면 화면이 하얗게 번쩍여요. 저주 보유자는 깨어날 때 "...어, 내가 왜 여기 있지?"가 떠요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)

local UI = Config.UI
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")

local SLEEP_FADE = TweenInfo.new(2)
local WAKE_FADE = TweenInfo.new(1)
local SLEEPY_DARKNESS = 0.05 -- 졸 때 화면 투명도 (0 = 깜깜)

local curtain = Instance.new("Frame")
curtain.Name = "SleepCurtain"
curtain.Size = UDim2.fromScale(1, 1)
curtain.BackgroundColor3 = Color3.new(0, 0, 0)
curtain.BackgroundTransparency = 1
curtain.ZIndex = 40
curtain.Visible = false
curtain.Parent = gui

local function centerText(parent: Instance, y: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.new(0.9, 0, 0, size * 2)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(220, 220, 230)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextTransparency = 1
	label.ZIndex = 41
	label.Text = ""
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = label
	return label
end

local sleepyText = centerText(curtain, 0.5, 40)
local wakeText = centerText(gui, 0.4, 36)

local flash = Instance.new("Frame")
flash.Name = "CatchFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 45
flash.Parent = gui
local flashText = centerText(gui, 0.45, 36)
flashText.ZIndex = 46

local function showFor(label: TextLabel, text: string, seconds: number)
	label.Text = text
	label.TextTransparency = 0
	task.delay(seconds, function()
		if label.Text == text then
			TweenService:Create(label, WAKE_FADE, { TextTransparency = 1 }):Play()
		end
	end)
end

Remotes.SleepState.OnClientEvent:Connect(function(asleep: boolean, wakeMessage: string?)
	if asleep then
		curtain.Visible = true
		TweenService:Create(curtain, SLEEP_FADE, { BackgroundTransparency = SLEEPY_DARKNESS }):Play()
		sleepyText.Text = "졸려..."
		TweenService:Create(sleepyText, SLEEP_FADE, { TextTransparency = 0 }):Play()
	else
		TweenService:Create(curtain, WAKE_FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(sleepyText, WAKE_FADE, { TextTransparency = 1 }):Play()
		task.delay(1, function()
			if curtain.BackgroundTransparency >= 1 then
				curtain.Visible = false
			end
		end)
		if wakeMessage then
			showFor(wakeText, wakeMessage, UI.NarrationSeconds)
		end
	end
end)

Remotes.ScreenFlash.OnClientEvent:Connect(function(message: string)
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(Config.Ending.FlashSeconds * 2), { BackgroundTransparency = 1 }):Play()
	showFor(flashText, message, UI.NarrationSeconds)
end)
