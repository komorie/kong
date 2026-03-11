--직구만 던지는 기본 상대 투수 클래스
local OppositePitcher = require('OppositePitcher')

local FastballPitcher = class('FastballPitcher', OppositePitcher)

function FastballPitcher:init()
	self.super.init(self)
	self.pitch_const = Constants.FASTBALL_PITCHER
end

--직구만 던지는 투수
function FastballPitcher:Pitch()
	self.throw_count = self.throw_count + 1

	local is_strike = self:SelectStrike()
	local des = self:SelectEndPos(is_strike)
	local timing = self.pitch_const.fastball.timing

	self:Fastball(des, timing.duration)

	return {
		timing = timing,
		is_strike = is_strike,
	}
end

return FastballPitcher
