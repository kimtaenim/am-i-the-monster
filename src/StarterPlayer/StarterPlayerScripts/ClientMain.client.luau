-- 내 화면(클라이언트)에서 제일 먼저 실행돼요.
-- 서버가 보내는 한 줄 알림을 화면 위쪽에 잠깐 띄워요. 판정은 전부 서버가 해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)

local UI = Config.UI

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")

-- 알림이 쌓이는 칸
local list = Instance.new("Frame")
list.Name = "Toasts"
list.AnchorPoint = Vector2.new(0.5, 0)
list.Position = UDim2.new(0.5, 0, 0, UI.NotifyTop)
list.Size = UDim2.new(0.6, 0, 0, 150)
list.BackgroundTransparency = 1
list.Parent = gui

local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local order = 0
local function showToast(text: string)
	order += 1
	local toasts = {}
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= UI.MaxNotifies then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 0, 40)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.4
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = UI.NotifyTextSize
	label.Text = "  " .. text .. "  "
	label.Parent = list
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	task.delay(UI.NotifySeconds, function()
		if label.Parent then
			local fade = TweenInfo.new(UI.NotifyFadeSeconds)
			TweenService:Create(label, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(UI.NotifyFadeSeconds)
			label:Destroy()
		end
	end)
end

Remotes.Notify.OnClientEvent:Connect(showToast)
