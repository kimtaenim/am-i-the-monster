-- 서버 시스템끼리 "이런 일이 생겼어!" 하고 알려 주는 작은 신호기예요.
-- 예 : GameLoop가 "밤이 됐어"를 Fire하면, Connect해 둔 시스템들이 모두 듣고 움직여요.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(callback)
	table.insert(self._listeners, callback)
	return {
		Disconnect = function()
			local index = table.find(self._listeners, callback)
			if index then
				table.remove(self._listeners, index)
			end
		end,
	}
end

-- 듣는 함수 하나가 오류를 내도 나머지는 계속 들어요
function Signal:Fire(...)
	for _, callback in table.clone(self._listeners) do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[Signal] 오류:", err)
		end
	end
end

return Signal
