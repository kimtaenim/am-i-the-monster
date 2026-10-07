-- NPC 머리 위에 말풍선을 띄워요. 가까이(60스터드 안) 있을 때만 들려요.
-- 채팅창에는 올리지 않아요. 한 NPC가 새 말을 하면 전 말풍선은 바로 바뀌어요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)

local D = Config.Dialogue
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local bubbles = {} -- NPC → 말풍선

local function myPosition(): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or Workspace.CurrentCamera.CFrame.Position
end

local function makeBubble(head: BasePart): BillboardGui
	local board = Instance.new("BillboardGui")
	board.Name = "SpeechBubble"
	board.Adornee = head
	board.Size = UDim2.fromOffset(240, 70)
	board.StudsOffsetWorldSpace = Vector3.new(0, D.BubbleHeight, 0)
	board.MaxDistance = D.HearDistance
	board.LightInfluence = 0
	board.AlwaysOnTop = true

	local frame = Instance.new("Frame")
	frame.Name = "Box"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(250, 245, 230)
	frame.BackgroundTransparency = 0.05
	frame.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Position = UDim2.fromOffset(8, 4)
	label.Size = UDim2.new(1, -16, 1, -8)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(40, 35, 30)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = frame
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = label

	board.Parent = gui
	return board
end

Remotes.NpcSay.OnClientEvent:Connect(function(npc: Instance, text: string)
	local head = npc and npc:FindFirstChild("Head")
	if not head or (head.Position - myPosition()).Magnitude > D.HearDistance then
		return
	end
	local board = bubbles[npc]
	if not board or not board.Parent then
		board = makeBubble(head)
		bubbles[npc] = board
	end
	board.Box.Text.Text = text
	board.Enabled = true
	local shown = text
	task.delay(D.BubbleSeconds, function()
		if board.Parent and board.Box.Text.Text == shown then
			board.Enabled = false
		end
	end)
	-- NPC가 사라지면 말풍선도 치워요
	if not board:GetAttribute("Watching") then
		board:SetAttribute("Watching", true)
		npc.AncestryChanged:Connect(function(_, parent)
			if not parent then
				board:Destroy()
				bubbles[npc] = nil
			end
		end)
	end
end)
