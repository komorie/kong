--Lua에서 클래스 상속을 구현하기 위한 함수. (미테스트)
local function class(classname, super)
    local cls = {}
    cls.__index = cls
    cls.__classname = classname

    -- 상속 처리
    if super then
        setmetatable(cls, { __index = super })
		cls.super = super
    end

    -- 인스턴스 생성을 위한 메타테이블 설정
    local mt = getmetatable(cls) or {}

    mt.__call = function(_, ...)
        local instance = setmetatable({}, cls)
        if instance.init then
            instance:init(...)
        end
        return instance
    end

    setmetatable(cls, mt)

    return cls
end

--기반 스테이트
local BaseState = class("BaseState")

function BaseState:init(context)
    self.context = context
end

function BaseState:Enter() end

function BaseState:Update(dt) end

function BaseState:Exit() end

--Idle State
local StateIdle = class("StateIdle", BaseState)

function StateIdle:Enter()
    self.context:SetAnimation("Idle_Gauntlet")

    --플레이어 시작 위치
    self.start_pos = self.context:GetPlayerPosition()
end

function StateIdle:Update(dt)
    --소음 물체 파괴 감지 -> Kick State
    if self.context:IsBreakableDestroyed() then
        self.context:SetTarget(self.context:GetLastNoisePosition(), "Breakable")
        self.context:ChangeState(self.context.states.Kick)
        return
    end

    --플레이어 이동 감지 -> Suspicious State
    local current_pos = self.context:GetPlayerPosition()
    if self.context:GetDistance(self.start_pos, current_pos) > 0.1 then
        self.context:ChangeState(self.context.states.Suspicious)
    end
end

--Suspicious State: 공격 타이머(UI)를 띄워 플레이어에게 경고
local StateSuspicious = class("StateSuspicious", BaseState)

function StateSuspicious:Enter()
    self.lifetime = 1.0
    self.time_passed = 0

    -- 연출: 카메라 줌아웃, 공격 타이머 표시, 의심 대사 출력
    self.context:PlayCameraZoom(6.7, 0.1) -- Zoom out
    self.context:ShowAttackTimer(1.0)
    self.context:PlayRandomSpeech("Who goes there?")
end

function StateSuspicious:Update(dt)
    self.time_passed = self.time_passed + dt

    --소음 물체 파괴 감지 -> Kick State
    if self.context:IsBreakableDestroyed() then
        self.context:SetTarget(self.context:GetLastNoisePosition(), "Breakable")
        self.context:ChangeState(self.context.states.Kick)
        return
    end

    --일정 시간이 지나면 -> Aware State
    if self.time_passed > self.lifetime then
        self.context:ChangeState(self.context.states.Aware)
    end
end

function StateSuspicious:Exit()
    self.context:HideAttackTimer()
end

--Aware State: 플레이어가 움직일 시 즉시 공격
local StateAware = class("StateAware", BaseState)

function StateAware:Enter()
    self.lifetime = 2.0
    self.invincible_time = 0.2
    self.time_passed = 0

    self.current_pos = self.context:GetPlayerPosition()
    self.prev_pos = nil

    -- 연출: 플레이어 쪽 바라보기, 카메라 쉐이크, 공격 준비 태세
    self.context:LookAtPlayer()
    self.context:SetAnimation("Attack_Ready_Loop")
    self.context:PlayCameraShake(0.03, 999)
    self.context:PlaySound("Effect_Evolution")
end

function StateAware:Update(dt)
    self.time_passed = self.time_passed + dt
    local player_pos = self.context:GetPlayerPosition()

    --무적 시간 이후 위치 추적 시작
    if self.time_passed > self.invincible_time then
        if self.prev_pos == nil then
            self.prev_pos = player_pos
        else
            self.prev_pos = self.current_pos
        end

        self.current_pos = player_pos
    end

    --제한 시간 내에 플레이어 움직임/소음 감지 -> Kick State
    if self.time_passed <= self.lifetime then
        local is_moved = (self.prev_pos ~= self.current_pos)
        local is_distracted = self.context:IsBreakableDestroyed()

        if is_moved or is_distracted then
            if is_distracted then
                self.context:SetTarget(self.context:GetLastNoisePosition(), "Breakable")
            else
                self.context:SetTarget(player_pos, "Player")
            end

            self.context:ChangeState(self.context.states.Kick)
        end

        return
    end

    --제한 시간 동안 얌전했으면 -> Idle State
    self.context:PlayCameraZoom(6.5, 0.1)
    self.context:ChangeState(self.context.states.Idle)
end

function StateAware:Exit()
    self.context:StopCameraShake()
    self.context:StopSound("Effect_Evolution")
    self.context:SetAnimation("Idle_Gauntlet")
end

--Kick State (공격 상태)
local StateKick = class("StateKick", BaseState)

function StateKick:Enter()
    self.time_passed = 0
    self.is_hit = false

    local target_info = self.context:GetTarget() -- {pos, type}
    local my_pos = self.context:GetPosition()

    self.dir_vec = (target_info.pos - my_pos):Normalize()
    self.start_pos = my_pos

    if target_info.type == "Player" then
        self.context:SetPlayerControl(false)
        self.context:PlayDetectedSequence()
        self.dest_pos = target_info.pos
    else
        self.context:PlayDistractedSequence()

        -- 벽(Zone Border)까지의 충돌 지점 계산
        local zone = self.context:GetZoneInfo()
        self.dest_pos = self:CalculateZoneBorderPos(my_pos, zone.center, zone.extents, self.dir_vec)

        if not self.dest_pos then self.dest_pos = target_info.pos end
    end

    local distance = self.context:GetDistance(self.start_pos, self.dest_pos)
    self.duration = distance / 15
    self.context:SetAnimation("Attack_Kick")
end

-- 진행 방향이 벽면의 어느 위치에 부딪혔는지 계산
function StateKick:CalculateZoneBorderPos(pos, center, extents, dir)
    local min_x, max_x = center.x - extents.x, center.x + extents.x
    local min_z, max_z = center.z - extents.z, center.z + extents.z
    local intersection = nil

    if dir.x ~= 0 then
        local t = (dir.x > 0) and (max_x - pos.x) / dir.x or (min_x - pos.x) / dir.x
        local potential = pos + (dir * t)
        if potential.z >= min_z and potential.z <= max_z then intersection = potential end
    end

    if dir.z ~= 0 then
        local t = (dir.z > 0) and (max_z - pos.z) / dir.z or (min_z - pos.z) / dir.z
        local potential = pos + (dir * t)
        if potential.x >= min_x and potential.x <= max_x then intersection = potential end
    end

    return intersection
end

function StateKick:Update(dt)
    self.time_passed = self.time_passed + dt
    local t = math.min(self.time_passed / self.duration, 1)
    local current_pos = self.context:Lerp(self.start_pos, self.dest_pos, t)
    self.context:SetPosition(current_pos)

    --플레이어에게 닿은 경우 실패 연출
    if not self.is_hit and self.context:CheckCollisionWithPlayer(current_pos) then
        self.is_hit = true
        self.context:FailMission()
        return
    end

    --날아차기 목적지에 도달하면 -> Down State
    if self.time_passed >= self.duration then
        self.context:PlayEffect("Smoke_Screen", current_pos)
        self.context:PlayCameraShake(0.3, 0.5)
        self.context:ChangeState(self.context.states.Down)
    end
end

--Down State (그로기 상태)
local StateDown = class("StateDown", BaseState)

function StateDown:Enter()
    self.timer = 0
    self.recover_time = 1.7
    self.context:SetAnimation("Sleep_Down")
end

function StateDown:Update(dt)
    self.timer = self.timer + dt

    --다운 시간 끝나면 Idle State로
    if self.timer >= self.recover_time then
        self.context:PlaySound("Small_Jump")
        self.context:SetAnimation("Jump_Recover")
        self.context:ChangeState(self.context.states.Idle)
    end
end

--의사 컨트롤러
local BlindMasterAI = class("BlindMasterAI")

function BlindMasterAI:init()
    -- 상태 초기화
    self.states = {
        Idle = StateIdle(self),
        Suspicious = StateSuspicious(self),
        Aware = StateAware(self),
        Kick = StateKick(self),
        Down = StateDown(self)
    }

    self.current_state = self.states.Idle
    self.target_data = { pos = nil, type = nil }
    self.breakable_destroyed_pos = nil
end

function BlindMasterAI:Update(dt)
    if self.current_state then
        self.current_state:Update(dt)
    end
end

function BlindMasterAI:ChangeState(next_state)
    if not next_state or self.current_state == next_state then return end
    self.current_state:Exit()
    self.current_state = next_state
    self.current_state:Enter()
end

-- 추상 메서드
function BlindMasterAI:SetTarget(pos, type) self.target_data = { pos = pos, type = type } end

function BlindMasterAI:GetTarget() return self.target_data end

function BlindMasterAI:IsBreakableDestroyed() return self.breakable_destroyed_pos ~= nil end

function BlindMasterAI:GetLastNoisePosition() return self.breakable_destroyed_pos end
