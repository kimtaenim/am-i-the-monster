-- 무기를 들고 클릭(모바일은 화면 터치)하면 "여기를 노렸어"를 서버에 알려요.
-- 맞았는지는 서버가 판정해요. 여기서는 노린 위치만 보내요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("WeaponId") then
		return
	end
	if tool:GetAttribute("InputHooked") then
		return
	end
	tool:SetAttribute("InputHooked", true)
	tool.Activated:Connect(function()
		Remotes.UseWeapon:FireServer(mouse.Hit.Position)
	end)
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
	character.ChildAdded:Connect(watchTool)
end

if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)
