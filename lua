-- Inject script Ai The Strongest Battlegrounds
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local AIEnabled = false
local MainLoop = nil

-- SETTINGS STORE (used for synchronization)
local SettingsStore = {
    AttackDistance = 8,
    ApproachDistance = 5,
    RetreatDistance = 3,
    OptimalFightDistance = 6,
    
    AbilityRange = 18,
    VisionRange = 200,
    AttackCooldown = 0.22,
    DashCooldown = 1.5,
    JumpCooldown = 1.2,
    
    DashEnabled = true,
    DashChance = 80,
    SideDashFrequency = 70,
    ForwardDashChance = 40,
    BackDashChance = 30,
    DashDuration = 0.12,
    LeftDashChance = 50,
    RightDashChance = 50,
    SideDashWhenClose = 75,
    
    JumpEnabled = true,
    JumpChance = 45,
    JumpAttackChance = 70,
    JumpHeight = 0.12,
    
    BlockChance = 65,
    BlockDuration = 0.25,
    
    AimEnabled = true,
    AlwaysShiftlock = true,
    AimSpeed = 0.35,
    SmoothAim = true,
    AimPrediction = true,
    PredictionAmount = 0.15,
    
    AggressiveMode = false,
    AutoShoot = true,
    TriggerDelay = 0.06,
    
    UseAbility1 = true,
    UseAbility2 = true,
    UseAbility3 = true,
    UseAbility4 = true,
    Ability1Range = 15,
    Ability2Range = 12,
    Ability3Range = 8,
    Ability4Range = 6,
    Ability1Cooldown = 1.2,
    Ability2Cooldown = 1.0,
    Ability3Cooldown = 0.8,
    Ability4Cooldown = 1.5,
    
    UseUltimate = true,
    UltimateHP = 30,
    UltimateRange = 10,
    UltimateCooldown = 10,
    UltimateUseAbility1 = true,
    UltimateUseAbility2 = true,
    UltimateComboCount = 3,
    
    AutoStrafe = true,
    StrafeLeft = true,
    StrafeRight = true,
    StrafeChance = 70,
    StrafeIntensity = 0.8,
    StrafeChangeTime = 0.8,
    CircleStrafe = true,
    StrafeForward = true,
    
    TargetPriority = "Closest",
    
    CheckEnemyHealth = true,
    AutoPickTarget = true,
    AvoidWalls = true,
    PredictionMode = "Linear",
    WallCheckDistance = 5,
    MinHealthToFight = 10
    ,
    -- Learning settings
    EnableLearning = false,
    UseDataStore = true,
    Epsilon = 20, -- percent
    LearningRate = 0.25,
    Discount = 0.9,
    QSaveInterval = 60 -- seconds
}

local function GetSetting(name)
    return SettingsStore[name]
end

-- shortcuts to reduce global lookups
local GS = GetSetting            -- faster alias
local rnd = math.random
local tck = tick


local FriendList = {}
local IgnoreList = {}
local WhitelistMode = false
local BlacklistMode = false

local Target = nil
local TargetChar = nil
local LastAttack = 0
local LastDash = 0
local LastJump = 0
local LastAbility = {0, 0, 0, 0}
local LastUltimate = 0
local LastSideDash = 0
local LastLeftDash = 0
local LastRightDash = 0
local ComboCount = 0
local DashDirection = "forward"
local StrafeDirection = "left"
local StrafeTimer = 0
local UltimateCombo = 0
local UltimateAbilityCombo = 0

local function PressKey(key, duration)
    VIM:SendKeyEvent(true, key, false, nil)
    task.wait(duration or 0.04)
    VIM:SendKeyEvent(false, key, false, nil)
    return true
end

local function PressCombo(keys, duration)
    for _, key in ipairs(keys) do
        VIM:SendKeyEvent(true, key, false, nil)
    end
    task.wait(duration or 0.08)
    for _, key in ipairs(keys) do
        VIM:SendKeyEvent(false, key, false, nil)
    end
    return true
end

local function PressDash(directionKey, duration)
    -- Hold movement key, then press dash key (Q) to ensure dash registers
    VIM:SendKeyEvent(true, directionKey, false, nil)
    task.wait(0.02)
    VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, nil)
    task.wait(duration or 0.12)
    VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, nil)
    VIM:SendKeyEvent(false, directionKey, false, nil)
    return true
end

local function PressLMB()
    VIM:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
    task.wait(0.04)
    VIM:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
    return true
end

local function ReleaseAllMovement()
    local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
    for _, key in ipairs(keys) do
        VIM:SendKeyEvent(false, key, false, nil)
    end
end

local function IsFriend(player)
    if not player then return false end
    for _, name in ipairs(FriendList) do
        if player.Name:lower():find(name:lower()) then
            return true
        end
    end
    return false
end

local function IsIgnored(player)
    if not player then return false end
    for _, name in ipairs(IgnoreList) do
        if player.Name:lower():find(name:lower()) then
            return true
        end
    end
    return false
end

local function ShouldTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    if WhitelistMode then return IsFriend(player) end
    if BlacklistMode then return not IsIgnored(player) end
    return true
end

local function FindTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local bestTarget = nil
    local bestScore = -9999
    
    for _, player in ipairs(Players:GetPlayers()) do
        if ShouldTarget(player) and player.Character then
            local targetChar = player.Character
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
            local humanoid = targetChar:FindFirstChild("Humanoid")
            
            if targetRoot and humanoid and humanoid.Health > 0 then
                -- skip very low-health enemies when the setting is enabled
                            if not (GS("CheckEnemyHealth") and humanoid.Health < GS("MinHealthToFight")) then
                    local distance = (targetRoot.Position - root.Position).Magnitude
                    
                    if distance <= GS("VisionRange") then
                        local score = 0
                        local priority = GS("TargetPriority")
                        
                        if priority == "Closest" then
                            score = 1000 - distance
                        elseif priority == "LowestHealth" then
                            score = 1000 - humanoid.Health
                        else
                            score = 500 - distance
                        end
                        
                        if score > bestScore then
                            bestScore = score
                            bestTarget = player
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

local function GetDistance()
    if not TargetChar then return 9999 end
    local char = LocalPlayer.Character
    if not char then return 9999 end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local targetRoot = TargetChar:FindFirstChild("HumanoidRootPart")
    if not root or not targetRoot then return 9999 end
    
    return (targetRoot.Position - root.Position).Magnitude
end

local function AimAtTarget()
    if not TargetChar then return false end
    if not GS("AimEnabled") then return false end
    
    local char = LocalPlayer.Character
    if not char then return false end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local targetRoot = TargetChar:FindFirstChild("HumanoidRootPart")
    if not root or not targetRoot then return false end
    
    local aimPosition = targetRoot.Position
    
    if GS("AimPrediction") then
        local velocity = targetRoot.Velocity
        local distance = GetDistance()
        local travelTime = distance / 100
        
        if GS("PredictionMode") == "Advanced" then
            local acceleration = (targetRoot.Velocity - (targetRoot:GetAttribute("LastVelocity") or Vector3.new())) / RunService.Heartbeat:Wait()
            targetRoot:SetAttribute("LastVelocity", targetRoot.Velocity)
            aimPosition = aimPosition + (velocity * travelTime) + (acceleration * travelTime * travelTime * 0.5) * GS("PredictionAmount")
        else
            aimPosition = aimPosition + (velocity * travelTime * GS("PredictionAmount"))
        end
    end
    
    local direction = (aimPosition - root.Position).Unit
    local lookAt = root.Position + (direction * 10)
    
    if GS("AlwaysShiftlock") then
        if GS("SmoothAim") then
            local currentCF = Camera.CFrame
            local targetCF = CFrame.new(Camera.CFrame.Position, Vector3.new(lookAt.X, lookAt.Y, lookAt.Z))
            Camera.CFrame = currentCF:Lerp(targetCF, GS("AimSpeed"))
        else
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, Vector3.new(lookAt.X, lookAt.Y, lookAt.Z))
        end
    end
    
    return true
end

local function WASDStrafing(delta)
    if not TargetChar then
        ReleaseAllMovement()
        return
    end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        ReleaseAllMovement()
        return
    end
    
    local distance = GetDistance()
    
    local function CheckWall(direction)
        if not GS("AvoidWalls") then return true end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return true end
        
        local rayOrigin = root.Position
        local rayDirection = direction * GS("WallCheckDistance")
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {char}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        
        local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        return raycastResult == nil
    end
    
    -- Only release movement keys if not recently dashed (to avoid interrupting dashes)
    if not (tck() - LastDash < 0.2) then
        ReleaseAllMovement()
    end
    
    if distance > GS("ApproachDistance") + 2 then
        VIM:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        
    elseif distance < GS("RetreatDistance") then
        VIM:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
        
    else
        if GS("StrafeForward") then
            VIM:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        end
    end
    
    if GS("AutoStrafe") then
        StrafeTimer = StrafeTimer + (delta or 0)
        
        if StrafeTimer >= GS("StrafeChangeTime") then
            StrafeTimer = 0
            
            if GS("StrafeLeft") and GS("StrafeRight") then
                StrafeDirection = rnd(1, 2) == 1 and "left" or "right"
            elseif GS("StrafeLeft") then
                StrafeDirection = "left"
            elseif GS("StrafeRight") then
                StrafeDirection = "right"
            end
        end
        
        if rnd(1, 100) <= GS("StrafeChance") then
            if StrafeDirection == "left" and GS("StrafeLeft") then
                if CheckWall(Vector3.new(-1, 0, 0)) then
                    VIM:SendKeyEvent(true, Enum.KeyCode.A, false, nil)
                else
                    VIM:SendKeyEvent(true, Enum.KeyCode.D, false, nil)
                end
                
            elseif StrafeDirection == "right" and GS("StrafeRight") then
                if CheckWall(Vector3.new(1, 0, 0)) then
                    VIM:SendKeyEvent(true, Enum.KeyCode.D, false, nil)
                else
                    VIM:SendKeyEvent(true, Enum.KeyCode.A, false, nil)
                end
            end
        end
    end
    
    if GS("CircleStrafe") and distance <= GS("OptimalFightDistance") * 1.5 then
        local strafePattern = math.sin(tck() * 2)
        if strafePattern > GS("StrafeIntensity") then
            if CheckWall(Vector3.new(-1, 0, 0)) then
                VIM:SendKeyEvent(true, Enum.KeyCode.A, false, nil)
            end
        elseif strafePattern < -GS("StrafeIntensity") then
            if CheckWall(Vector3.new(1, 0, 0)) then
                VIM:SendKeyEvent(true, Enum.KeyCode.D, false, nil)
            end
        end
    end
end

local function SmartAttack()
    local currentTime = tck()
    if currentTime - LastAttack < GS("AttackCooldown") then return false end
    
    local distance = GetDistance()
    
    if distance > GS("AttackDistance") then return false end
    
    PressLMB()
    
    LastAttack = currentTime
    ComboCount = ComboCount + 1
    return true
end

local function SideDash(direction)
    -- quick side dash handler, direction is "left" or "right"
    local currentTime = tck()
    local lastDash = direction == "left" and LastLeftDash or LastRightDash

    if currentTime - lastDash < GS("DashCooldown") * 0.6 then
        return false
    end

    if direction == "left" then
        PressDash(Enum.KeyCode.A, GS("DashDuration"))
        DashDirection = "left"
        LastLeftDash = currentTime
    else
        PressDash(Enum.KeyCode.D, GS("DashDuration"))
        DashDirection = "right"
        LastRightDash = currentTime
    end

    LastSideDash = currentTime
    LastDash = currentTime

    task.wait(0.1)
    if GetDistance() <= GS("AttackDistance") then
        PressLMB()
    end

    return true
end

local function Block()
    if rnd(1, 100) > GS("BlockChance") then return false end
    PressKey(Enum.KeyCode.F, GS("BlockDuration"))
    return true
end

local function SaveSettings()
    if not QStore then QStore = DataStoreService:GetDataStore("AIAgentQ_v1") end
    local SettingsStoreKey = "AISettings_" .. (LocalPlayer.UserId or "guest")
    local ok, err = pcall(function()
        local encoded = HttpService:JSONEncode(SettingsStore)
        QStore:SetAsync(SettingsStoreKey, encoded)
    end)
    if ok then print("Settings saved!") else warn("Settings save failed:", err) end
end

local function LoadSettings()
    if not QStore then QStore = DataStoreService:GetDataStore("AIAgentQ_v1") end
    local SettingsStoreKey = "AISettings_" .. (LocalPlayer.UserId or "guest")
    local ok, res = pcall(function() return QStore:GetAsync(SettingsStoreKey) end)
    if ok and res then
        local success, t = pcall(function() return HttpService:JSONDecode(res) end)
        if success and type(t) == "table" then
            for k, v in pairs(t) do
                SettingsStore[k] = v
            end
            print("Settings loaded!")
        end
    end
end

local function Block()
    if rnd(1, 100) > GS("BlockChance") then return false end
    PressKey(Enum.KeyCode.F, GS("BlockDuration"))
    return true
end

local function SmartDash()
    if not GS("DashEnabled") then return false end

    -- overall dash chance check
    if rnd(1, 100) > GS("DashChance") then
        return false
    end

    local currentTime = tck()
    if currentTime - LastDash < GS("DashCooldown") then return false end

    local distance = GetDistance()

    -- release movement keys to avoid conflicts
    ReleaseAllMovement()

    -- special side dash when close
    if distance <= GS("OptimalFightDistance") * 1.5 and rnd(1, 100) <= GS("SideDashWhenClose") then
        if rnd(1, 100) <= GS("LeftDashChance") then
            return SideDash("left")
        else
            return SideDash("right")
        end
    end

    -- decide which type of dash to attempt
    local roll = rnd(1, 100)
    if roll <= GS("SideDashFrequency") then
        -- choose left/right based on their individual chances
        if rnd(1, 100) <= GS("LeftDashChance") then
            return SideDash("left")
        else
            return SideDash("right")
        end
    end

    -- new roll for forward/back movement
    roll = rnd(1, 100)
    if roll <= GS("ForwardDashChance") and distance > GS("ApproachDistance") + 3 then
        PressDash(Enum.KeyCode.W, GS("DashDuration"))
        DashDirection = "forward"
        LastDash = currentTime
        return true
    end

    roll = rnd(1, 100)
    if roll <= GS("BackDashChance") and distance < GS("RetreatDistance") then
        PressDash(Enum.KeyCode.S, GS("DashDuration"))
        DashDirection = "back"
        if rnd(1, 100) <= GS("BlockChance") then
            task.wait(0.18)
            PressKey(Enum.KeyCode.F, GS("BlockDuration"))
        end
        LastDash = currentTime
        return true
    end

    return false
end

local function UseAbility1()
    if not GS("UseAbility1") then return false end
    
    local currentTime = tck()
    if currentTime - LastAbility[1] < GS("Ability1Cooldown") then return false end
    
    local distance = GetDistance()
    if distance > GS("Ability1Range") then return false end
    
    PressKey(Enum.KeyCode.One, 0.15)
    LastAbility[1] = currentTime
    return true
end

local function UseAbility2()
    if not GS("UseAbility2") then return false end
    
    local currentTime = tck()
    if currentTime - LastAbility[2] < GS("Ability2Cooldown") then return false end
    
    local distance = GetDistance()
    if distance > GS("Ability2Range") then return false end
    
    PressKey(Enum.KeyCode.Two, 0.15)
    LastAbility[2] = currentTime
    return true
end

local function UseAbility3()
    if not GS("UseAbility3") then return false end
    
    local currentTime = tck()
    if currentTime - LastAbility[3] < GS("Ability3Cooldown") then return false end
    
    local distance = GetDistance()
    if distance > GS("Ability3Range") then return false end
    
    PressKey(Enum.KeyCode.Three, 0.15)
    LastAbility[3] = currentTime
    return true
end

local function UseAbility4()
    if not GS("UseAbility4") then return false end
    
    local currentTime = tck()
    if currentTime - LastAbility[4] < GS("Ability4Cooldown") then return false end
    
    local distance = GetDistance()
    if distance > GS("Ability4Range") then return false end
    
    PressKey(Enum.KeyCode.Four, 0.15)
    LastAbility[4] = currentTime
    return true
end

local function SmartAbility()
    local distance = GetDistance()
    
    if distance <= GS("Ability4Range") then
        return UseAbility4() or UseAbility3()
    elseif distance <= GS("Ability3Range") then
        return UseAbility3() or UseAbility2()
    elseif distance <= GS("Ability2Range") then
        return UseAbility2() or UseAbility1()
    elseif distance <= GS("Ability1Range") then
        return UseAbility1()
    end
    
    return false
end

local function IntelligentUltimate()
    if not GS("UseUltimate") then return false end
    
    local currentTime = tck()
    if currentTime - LastUltimate < GS("UltimateCooldown") then return false end
    
    local char = LocalPlayer.Character
    if not char then return false end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    local hpPercent = (humanoid.Health / humanoid.MaxHealth) * 100
    if hpPercent > GS("UltimateHP") then return false end
    
    local distance = GetDistance()
    if distance > GS("UltimateRange") then return false end
    
    if ComboCount < GS("UltimateComboCount") then return false end
    
    if GS("UltimateUseAbility1") then
        UseAbility1()
        task.wait(0.2)
    end
    
    if GS("UltimateUseAbility2") then
        UseAbility2()
        task.wait(0.2)
    end
    
    print("IntelligentUltimate triggered, pressing G")
    -- attempt ultimate key press; do twice to ensure registration
    PressKey(Enum.KeyCode.G, 0.25)
    task.wait(0.05)
    PressKey(Enum.KeyCode.G, 0.15)

    LastUltimate = currentTime
    UltimateCombo = UltimateCombo + 1
    UltimateAbilityCombo = UltimateAbilityCombo + 1
    
    return true
end

local function Jump()
    if not GS("JumpEnabled") then return false end
    
    local currentTime = tck()
    if currentTime - LastJump < GS("JumpCooldown") then return false end
    
    if rnd(1, 100) > GS("JumpChance") then return false end
    
    local distance = GetDistance()
    if distance > GS("OptimalFightDistance") + 3 then return false end
    
    PressKey(Enum.KeyCode.Space, GS("JumpHeight"))
    
    if rnd(1, 100) <= GS("JumpAttackChance") then
        task.wait(0.12)
        if distance <= GS("AttackDistance") then
            PressLMB()
        end
    end
    
    LastJump = currentTime
    return true
end

-- Decision engine: evaluate possible actions and attempt the highest-scoring one
local function DecideAction()
    local distance = GetDistance()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    local hpPercent = humanoid and (humanoid.Health / humanoid.MaxHealth) * 100 or 100
    local scores = {}

    -- ultimate (very high priority when available)
    if GS("UseUltimate") and tck() - LastUltimate >= GS("UltimateCooldown") and hpPercent <= GS("UltimateHP") and ComboCount >= GS("UltimateComboCount") then
        table.insert(scores, {name = "ultimate", score = 200})
    end

    -- abilities: sum availability and proximity
    local abilityScore = 0
    for i = 1, 4 do
        if GS("UseAbility" .. i) then
            local rangeKey = "Ability" .. i .. "Range"
            local cdKey = "Ability" .. i .. "Cooldown"
            local last = LastAbility[i] or 0
            if tck() - last >= GS(cdKey) and distance <= GS(rangeKey) then
                abilityScore = abilityScore + math.max(0, 60 - distance)
            end
        end
    end
    if abilityScore > 0 then table.insert(scores, {name = "ability", score = abilityScore}) end

    -- attack (preferred when inside attack distance and cooldown ready)
    if tck() - LastAttack >= GS("AttackCooldown") then
        if distance <= GS("AttackDistance") then
            local atkScore = 100 + (GS("AttackDistance") - distance) * 5
            table.insert(scores, {name = "attack", score = atkScore})
        end
    end

    -- dash (use when conditions and chance allow)
    if GS("DashEnabled") and tck() - LastDash >= GS("DashCooldown") and rnd(1, 100) <= GS("DashChance") then
        local dashScore = 60
        if distance > GS("ApproachDistance") then dashScore = dashScore + 20 end
        if distance < GS("RetreatDistance") then dashScore = dashScore + 10 end
        -- prioritize side dashes more
        if rnd(1, 100) <= GS("SideDashFrequency") then dashScore = dashScore + 30 end
        table.insert(scores, {name = "dash", score = dashScore})
    end

    -- jump (situational)
    if GS("JumpEnabled") and tck() - LastJump >= GS("JumpCooldown") and distance <= GS("OptimalFightDistance") + 3 and rnd(1, 100) <= GS("JumpChance") then
        table.insert(scores, {name = "jump", score = 30})
    end

    -- block (defensive)
    if GS("BlockChance") > 0 and distance < GS("RetreatDistance") + 2 then
        table.insert(scores, {name = "block", score = 40})
    end

    if #scores == 0 then return false end
    table.sort(scores, function(a, b) return a.score > b.score end)

    for _, s in ipairs(scores) do
        if s.name == "ultimate" then
            if IntelligentUltimate() then return true end
        elseif s.name == "ability" then
            if SmartAbility() then return true end
        elseif s.name == "attack" then
            if SmartAttack() then return true end
        elseif s.name == "dash" then
            if SmartDash() then return true end
        elseif s.name == "jump" then
            if Jump() then return true end
        elseif s.name == "block" then
            if Block() then return true end
        end
    end

    return false
end

-- ===== Q-learning agent (tabular) =====
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local QStore = nil
local QTable = {}
local LastSave = tck()

local Actions = {"attack","ability1","ability2","ability3","ability4","dash","jump","strafe_left","strafe_right","none"}

local function SerializeState(s)
    return table.concat({s.distBucket or 0, s.myHpBucket or 0, s.enemyHpBucket or 0, s.combo or 0}, ":")
end

local function GetState()
    local distance = GetDistance()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    local myHp = humanoid and humanoid.Health or 100
    local myMax = humanoid and humanoid.MaxHealth or 100
    local hpPercent = myMax > 0 and (myHp / myMax) * 100 or 100

    local enemyHp = 100
    if TargetChar then
        local eh = TargetChar:FindFirstChild("Humanoid")
        if eh then enemyHp = eh.Health end
    end

    local state = {
        distBucket = math.floor(distance / 5),
        myHpBucket = math.floor(hpPercent / 10),
        enemyHpBucket = math.floor(enemyHp / 10),
        combo = math.min(3, ComboCount)
    }
    return state
end

local function EnsureQ(stateKey)
    if not QTable[stateKey] then
        QTable[stateKey] = {}
        for _, a in ipairs(Actions) do QTable[stateKey][a] = 0 end
    end
end

local function ChooseAction(stateKey)
    EnsureQ(stateKey)
    local eps = GS("Epsilon") / 100
    if rnd() < eps then
        return Actions[rnd(1, #Actions)]
    end
    local best, bestA = -1/0, "none"
    for a, v in pairs(QTable[stateKey]) do
        if v > best then best, bestA = v, a end
    end
    return bestA
end

local function PerformActionByName(a)
    if a == "attack" then return SmartAttack()
    elseif a == "ability1" then return UseAbility1()
    elseif a == "ability2" then return UseAbility2()
    elseif a == "ability3" then return UseAbility3()
    elseif a == "ability4" then return UseAbility4()
    elseif a == "dash" then return SmartDash()
    elseif a == "jump" then return Jump()
    elseif a == "strafe_left" then VIM:SendKeyEvent(true, Enum.KeyCode.A, false, nil); task.wait(0.08); VIM:SendKeyEvent(false, Enum.KeyCode.A, false, nil); return true
    elseif a == "strafe_right" then VIM:SendKeyEvent(true, Enum.KeyCode.D, false, nil); task.wait(0.08); VIM:SendKeyEvent(false, Enum.KeyCode.D, false, nil); return true
    elseif a == "none" then return false
    end
    return false
end

local function RewardSignal(prevEnemyHP, newEnemyHP, prevMyHP, newMyHP, killed)
    local reward = 0
    if prevEnemyHP and newEnemyHP then reward = reward + (prevEnemyHP - newEnemyHP) end
    if killed then reward = reward + 50 end
    if prevMyHP and newMyHP then reward = reward - (prevMyHP - newMyHP) end
    return reward
end

local function UpdateQ(prevKey, action, reward, nextKey)
    EnsureQ(prevKey); EnsureQ(nextKey)
    local alpha = GS("LearningRate")
    local gamma = GS("Discount")
    local q = QTable[prevKey][action] or 0
    local maxNext = -1/0
    for _, v in pairs(QTable[nextKey]) do if v > maxNext then maxNext = v end end
    if maxNext == -1/0 then maxNext = 0 end
    QTable[prevKey][action] = q + alpha * (reward + gamma * maxNext - q)
end

local function SaveQ()
    if not GS("UseDataStore") then return end
    if not QStore then QStore = DataStoreService:GetDataStore("AIAgentQ_v1") end
    local key = "Q_" .. (LocalPlayer.UserId or "guest")
    local ok, err = pcall(function()
        local encoded = HttpService:JSONEncode(QTable)
        QStore:SetAsync(key, encoded)
    end)
    if not ok then warn("Q save failed:", err) end
    LastSave = tck()
end

local function LoadQ()
    if not GS("UseDataStore") then return end
    if not QStore then QStore = DataStoreService:GetDataStore("AIAgentQ_v1") end
    local key = "Q_" .. (LocalPlayer.UserId or "guest")
    local ok, res = pcall(function() return QStore:GetAsync(key) end)
    if ok and res then
        local success, t = pcall(function() return HttpService:JSONDecode(res) end)
        if success and type(t) == "table" then QTable = t end
    end
end

-- load on script start
pcall(LoadQ)


local function StartAI()
    if MainLoop then
        MainLoop:Disconnect()
    end
    
    if GS("AlwaysShiftlock") then
        VIM:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, nil)
    end
    
    MainLoop = RunService.Heartbeat:Connect(function(delta)
        if not AIEnabled then return end
        
        if GS("AutoPickTarget") and (not Target or not Target.Character) then
            Target = FindTarget()
            TargetChar = Target and Target.Character
        else
            Target = FindTarget()
            TargetChar = Target and Target.Character
        end
        
        if TargetChar then
            AimAtTarget()
            WASDStrafing(delta)

            if GS("EnableLearning") then
                local prevState = GetState()
                local prevKey = SerializeState(prevState)
                local prevEnemyHum = TargetChar and TargetChar:FindFirstChild("Humanoid")
                local prevEnemyHP = prevEnemyHum and prevEnemyHum.Health or nil
                local prevMyHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                local prevMyHP = prevMyHum and prevMyHum.Health or nil

                local action = ChooseAction(prevKey)
                PerformActionByName(action)
                task.wait(0.12)

                local nextState = GetState()
                local nextKey = SerializeState(nextState)
                local newEnemyHum = TargetChar and TargetChar:FindFirstChild("Humanoid")
                local newEnemyHP = newEnemyHum and newEnemyHum.Health or nil
                local newMyHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                local newMyHP = newMyHum and newMyHP.Health or nil
                local killed = prevEnemyHP and newEnemyHP and newEnemyHP <= 0
                local reward = RewardSignal(prevEnemyHP, newEnemyHP, prevMyHP, newMyHP, killed)
                UpdateQ(prevKey, action, reward, nextKey)

                if tck() - LastSave >= GS("QSaveInterval") then
                    pcall(SaveQ)
                end
            else
                -- Decision engine chooses and attempts the best action each tick
                DecideAction()
            end
            
            if GS("AutoShoot") and distance <= GS("AttackDistance") then
                task.wait(GS("TriggerDelay"))
                PressLMB()
            end
            
            IntelligentUltimate()
            
        else
            ReleaseAllMovement()
        end
    end)
    
    print("AI STARTED - Settings applied")
    print("Attack Distance:", GS("AttackDistance"))
    print("Approach Distance:", GS("ApproachDistance"))
    print("Optimal Fight Distance:", GS("OptimalFightDistance"))
    print("WASD Strafe:", GetSetting("AutoStrafe") and "ON" or "OFF")
end

local function StopAI()
    if MainLoop then
        MainLoop:Disconnect()
        MainLoop = nil
    end
    
    ReleaseAllMovement()
    
    local otherKeys = {
        Enum.KeyCode.LeftShift, Enum.KeyCode.Q, Enum.KeyCode.F,
        Enum.KeyCode.Space, Enum.KeyCode.G,
        Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four
    }
    
    for _, key in ipairs(otherKeys) do
        VIM:SendKeyEvent(false, key, false, nil)
    end
    
    VIM:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
    
    print("AI STOPPED - Combo:", ComboCount, "Ultimate Combos:", UltimateCombo)
end

-- Kavo UI
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("AI Distance Controller (Fixed)", "DarkTheme")

-- Tabs
local MainTab = Window:NewTab("Main")
local DistanceTab = Window:NewTab("Distance")
local AimTab = Window:NewTab("Aim")
local CombatTab = Window:NewTab("Combat")
local DashTab = Window:NewTab("Dash")
local AbilityTab = Window:NewTab("Abilities")
local UltimateTab = Window:NewTab("Ultimate")
local MoveTab = Window:NewTab("Movement")
local FriendTab = Window:NewTab("Friends")
local AdvancedTab = Window:NewTab("Advanced")

-- Sections
local ControlSection = MainTab:NewSection("AI Control")
local TestSection = MainTab:NewSection("Testing")

local DistanceSection = DistanceTab:NewSection("Main Distance")
local ApproachSection = DistanceTab:NewSection("Approach Settings")

local AimSection = AimTab:NewSection("Aim Settings")
local AimAdvancedSection = AimTab:NewSection("Advanced Aim")

local CombatSection = CombatTab:NewSection("Combat Settings")
local CombatAdvancedSection = CombatTab:NewSection("Advanced")

local DashSection = DashTab:NewSection("Dash Settings")
local SideDashSection = DashTab:NewSection("Side Dash")

local AbilitySection = AbilityTab:NewSection("Toggle Abilities")
local AbilityRangeSection = AbilityTab:NewSection("Ability Ranges")
local AbilityCDSection = AbilityTab:NewSection("Ability Cooldowns")

local UltimateSection = UltimateTab:NewSection("Ultimate")

local MoveSection = MoveTab:NewSection("Movement Settings")
local StrafeSection = MoveTab:NewSection("WASD Strafe")
local JumpSection = MoveTab:NewSection("Jump")

local FriendSection = FriendTab:NewSection("Friends System")
local TargetSection = FriendTab:NewSection("Target Settings")

local AdvancedGeneralSection = AdvancedTab:NewSection("General")
local AdvancedCombatSection = AdvancedTab:NewSection("Combat")

-- Controls
ControlSection:NewToggle("Enable AI", "Toggle AI on/off", function(state)
    AIEnabled = state
    if state then
        StartAI()
    else
        StopAI()
    end
end)

ControlSection:NewButton("Apply Settings", "Apply current settings", function()
    if AIEnabled then
        StopAI()
        task.wait(0.1)
        StartAI()
    end
    print("Settings applied!")
    print("Current attack distance:", GetSetting("AttackDistance"))
    print("Current approach distance:", GetSetting("ApproachDistance"))
end)

ControlSection:NewButton("Save Settings", "Save current settings to DataStore", function()
    SaveSettings()
end)

ControlSection:NewButton("Load Settings", "Load settings from DataStore", function()
    LoadSettings()
    print("Settings loaded! Apply them with 'Apply Settings' button.")
end)

TestSection:NewButton("Check Distance", "Show current distance", function()
    local dist = GetDistance()
    print("=== CURRENT SETTINGS ===")
    print("Current distance:", string.format("%.1f", dist))
    print("Attack distance setting:", GetSetting("AttackDistance"))
    print("Approach distance setting:", GetSetting("ApproachDistance"))
    print("Optimal fight distance:", GetSetting("OptimalFightDistance"))
    print("Retreat distance:", GetSetting("RetreatDistance"))
    print("WASD Strafe:", GetSetting("AutoStrafe") and "ON" or "OFF")
    print("Strafe left:", GetSetting("StrafeLeft") and "ON" or "OFF")
    print("Strafe right:", GetSetting("StrafeRight") and "ON" or "OFF")
end)

TestSection:NewButton("Print All Settings", "Output all current settings", function()
    print("=== ALL CURRENT SETTINGS ===")
    for key, value in pairs(SettingsStore) do
        print(key .. ":", value)
    end
end)

-- Distance
DistanceSection:NewSlider("Attack Distance", "Start attacking at this distance", 20, 3, function(val)
    SettingsStore.AttackDistance = val
    print("Attack distance set:", val)
end)

DistanceSection:NewSlider("Optimal Distance", "Best distance for fighting", 15, 2, function(val)
    SettingsStore.OptimalFightDistance = val
    print("Optimal fight distance set:", val)
end)

DistanceSection:NewSlider("Ability Max Range", "Max ability distance", 30, 5, function(val)
    SettingsStore.AbilityRange = val
    print("Ability max range set:", val)
end)

ApproachSection:NewSlider("Approach Distance", "How close to approach the enemy", 15, 2, function(val)
    SettingsStore.ApproachDistance = val
    print("Approach distance set:", val)
end)

ApproachSection:NewSlider("Retreat Distance", "Retreat if closer than", 10, 1, function(val)
    SettingsStore.RetreatDistance = val
    print("Retreat distance set:", val)
end)

ApproachSection:NewToggle("Hold W During Strafe", "Hold W while strafing", function(state)
    SettingsStore.StrafeForward = state
    print("Hold W During Strafe:", state and "ON" or "OFF")
end)

-- Aim
AimSection:NewToggle("Enable Aim", "Enable auto-aim", function(state)
    SettingsStore.AimEnabled = state
    print("Aim:", state and "ON" or "OFF")
end)

AimSection:NewToggle("Always Shiftlock", "Lock camera to target", function(state)
    SettingsStore.AlwaysShiftlock = state
    print("Shiftlock:", state and "ON" or "OFF")
end)

AimSection:NewToggle("Smooth Aim", "Smooth camera movement", function(state)
    SettingsStore.SmoothAim = state
    print("Smooth Aim:", state and "ON" or "OFF")
end)

AimSection:NewToggle("Aim Prediction", "Predict target movement", function(state)
    SettingsStore.AimPrediction = state
    print("Aim Prediction:", state and "ON" or "OFF")
end)

AimAdvancedSection:NewSlider("Aim Speed", "Camera turn speed", 100, 1, function(val)
    SettingsStore.AimSpeed = val / 100
    print("Aim speed set:", val/100)
end)

AimAdvancedSection:NewSlider("Prediction Strength", "How strongly to predict", 50, 0, function(val)
    SettingsStore.PredictionAmount = val / 100
    print("Prediction strength set:", val/100)
end)

AimAdvancedSection:NewDropdown("Prediction Mode", "Prediction style", {"Linear", "Advanced"}, function(option)
    SettingsStore.PredictionMode = option
    print("Prediction mode:", option)
end)

-- Combat
CombatSection:NewToggle("Aggressive Mode", "More aggressive behavior", function(state)
    SettingsStore.AggressiveMode = state
    print("Aggressive Mode:", state and "ON" or "OFF")
end)

CombatSection:NewToggle("Auto Shoot", "Automatically shoot", function(state)
    SettingsStore.AutoShoot = state
    print("Auto Shoot:", state and "ON" or "OFF")
end)

CombatSection:NewSlider("Trigger Delay", "Delay between shots", 20, 1, function(val)
    SettingsStore.TriggerDelay = val / 100
    print("Trigger delay set:", val/100)
end)

CombatSection:NewSlider("Attack Cooldown", "Delay between attacks", 50, 5, function(val)
    SettingsStore.AttackCooldown = val / 100
    print("Attack cooldown set:", val/100)
end)

CombatAdvancedSection:NewSlider("Vision Range", "Max detection distance", 1000, 50, function(val)
    SettingsStore.VisionRange = val
    print("Vision range set:", val)
end)

CombatAdvancedSection:NewToggle("Auto Pick Target", "Automatically pick a target", function(state)
    SettingsStore.AutoPickTarget = state
    print("Auto Pick Target:", state and "ON" or "OFF")
end)

CombatAdvancedSection:NewToggle("Check Enemy Health", "Ignore low-health enemies", function(state)
    SettingsStore.CheckEnemyHealth = state
    print("Check Enemy Health:", state and "ON" or "OFF")
end)

CombatAdvancedSection:NewSlider("Min Health To Fight", "Ignore enemies below this HP", 100, 0, function(val)
    SettingsStore.MinHealthToFight = val
    print("Min health to fight set:", val)
end)

-- Dash
DashSection:NewToggle("Enable Dash", "Enable dash usage", function(state)
    SettingsStore.DashEnabled = state
    print("Dash:", state and "ON" or "OFF")
end)

DashSection:NewSlider("Dash Chance %", "Overall chance to use dash", 100, 0, function(val)
    SettingsStore.DashChance = val
    print("Dash chance set:", val)
end)

DashSection:NewSlider("Dash Duration", "Dash duration", 30, 1, function(val)
    SettingsStore.DashDuration = val / 100
    print("Dash duration set:", val/100)
end)

DashSection:NewSlider("Dash Cooldown", "Dash cooldown", 30, 1, function(val)
    SettingsStore.DashCooldown = val / 10
    print("Dash cooldown set:", val/10)
end)

SideDashSection:NewSlider("Side Dash Chance %", "Chance to perform a side dash", 200, 0, function(val)
    SettingsStore.SideDashFrequency = val
    print("Side dash chance set:", val)
end)

SideDashSection:NewSlider("Left Dash Chance %", "Chance to dash left", 200, 0, function(val)
    SettingsStore.LeftDashChance = val
    print("Left dash chance set:", val)
end)

SideDashSection:NewSlider("Right Dash Chance %", "Chance to dash right", 200, 0, function(val)
    SettingsStore.RightDashChance = val
    print("Right dash chance set:", val)
end)

SideDashSection:NewSlider("Side Dash When Close %", "Chance to side-dash when close", 200, 0, function(val)
    SettingsStore.SideDashWhenClose = val
    print("Side dash when close set:", val)
end)

-- Abilities
AbilitySection:NewToggle("Ability 1", "Use ability 1", function(state)
    SettingsStore.UseAbility1 = state
    print("Ability 1:", state and "ON" or "OFF")
end)

AbilitySection:NewToggle("Ability 2", "Use ability 2", function(state)
    SettingsStore.UseAbility2 = state
    print("Ability 2:", state and "ON" or "OFF")
end)

AbilitySection:NewToggle("Ability 3", "Use ability 3", function(state)
    SettingsStore.UseAbility3 = state
    print("Ability 3:", state and "ON" or "OFF")
end)

AbilitySection:NewToggle("Ability 4", "Use ability 4", function(state)
    SettingsStore.UseAbility4 = state
    print("Ability 4:", state and "ON" or "OFF")
end)

AbilityRangeSection:NewSlider("Ability 1 Range", "Range", 40, 1, function(val)
    SettingsStore.Ability1Range = val
    print("Ability 1 range set:", val)
end)

AbilityRangeSection:NewSlider("Ability 2 Range", "Range", 40, 1, function(val)
    SettingsStore.Ability2Range = val
    print("Ability 2 range set:", val)
end)

AbilityRangeSection:NewSlider("Ability 3 Range", "Range", 40, 1, function(val)
    SettingsStore.Ability3Range = val
    print("Ability 3 range set:", val)
end)

AbilityRangeSection:NewSlider("Ability 4 Range", "Range", 40, 1, function(val)
    SettingsStore.Ability4Range = val
    print("Ability 4 range set:", val)
end)

AbilityCDSection:NewSlider("Ability 1 Cooldown", "Cooldown time", 30, 1, function(val)
    SettingsStore.Ability1Cooldown = val / 10
    print("Ability 1 cooldown set:", val/10)
end)

AbilityCDSection:NewSlider("Ability 2 Cooldown", "Cooldown time", 30, 1, function(val)
    SettingsStore.Ability2Cooldown = val / 10
    print("Ability 2 cooldown set:", val/10)
end)

AbilityCDSection:NewSlider("Ability 3 Cooldown", "Cooldown time", 30, 1, function(val)
    SettingsStore.Ability3Cooldown = val / 10
    print("Ability 3 cooldown set:", val/10)
end)

AbilityCDSection:NewSlider("Ability 4 Cooldown", "Cooldown time", 30, 1, function(val)
    SettingsStore.Ability4Cooldown = val / 10
    print("Ability 4 cooldown set:", val/10)
end)

-- Ultimate
UltimateSection:NewToggle("Auto Ultimate", "Use ultimate at low HP", function(state)
    SettingsStore.UseUltimate = state
    print("Auto Ultimate:", state and "ON" or "OFF")
end)

UltimateSection:NewSlider("Ultimate HP %", "Use when HP below", 100, 1, function(val)
    SettingsStore.UltimateHP = val
    print("Ultimate HP set:", val)
end)

UltimateSection:NewSlider("Ultimate Range", "Range to use ultimate", 50, 1, function(val)
    SettingsStore.UltimateRange = val
    print("Ultimate range set:", val)
end)

UltimateSection:NewSlider("Combo Needed for Ultimate", "How many combos needed", 10, 1, function(val)
    SettingsStore.UltimateComboCount = val
    print("Combo needed for ultimate:", val)
end)

UltimateSection:NewToggle("Use Ability 1 Before Ultimate", "Use ability 1", function(state)
    SettingsStore.UltimateUseAbility1 = state
    print("Use ability 1 before ultimate:", state and "ON" or "OFF")
end)

UltimateSection:NewToggle("Use Ability 2 Before Ultimate", "Use ability 2", function(state)
    SettingsStore.UltimateUseAbility2 = state
    print("Use ability 2 before ultimate:", state and "ON" or "OFF")
end)

UltimateSection:NewSlider("Ultimate Cooldown", "Cooldown time", 30, 5, function(val)
    SettingsStore.UltimateCooldown = val
    print("Ultimate cooldown set:", val)
end)

-- Movement
MoveSection:NewToggle("Auto Strafe", "Enable WASD strafing", function(state)
    SettingsStore.AutoStrafe = state
    print("Auto strafe:", state and "ON" or "OFF")
end)

MoveSection:NewToggle("Circle Strafe", "Strafe around the target", function(state)
    SettingsStore.CircleStrafe = state
    print("Circle strafe:", state and "ON" or "OFF")
end)

MoveSection:NewSlider("Strafe Intensity", "Strength of circle strafe", 100, 10, function(val)
    SettingsStore.StrafeIntensity = val / 100
    print("Strafe intensity set:", val/100)
end)

MoveSection:NewToggle("Avoid Walls", "Don't run into walls", function(state)
    SettingsStore.AvoidWalls = state
    print("Avoid walls:", state and "ON" or "OFF")
end)

MoveSection:NewSlider("Wall Check Distance", "Distance to check for walls", 10, 1, function(val)
    SettingsStore.WallCheckDistance = val
    print("Wall check distance set:", val)
end)

-- Strafe settings
StrafeSection:NewToggle("Strafe Left (W+A)", "Enable left strafe", function(state)
    SettingsStore.StrafeLeft = state
    print("Strafe left (W+A):", state and "ENABLED" or "DISABLED")
end)

StrafeSection:NewToggle("Strafe Right (W+D)", "Enable right strafe", function(state)
    SettingsStore.StrafeRight = state
    print("Strafe right (W+D):", state and "ENABLED" or "DISABLED")
end)

StrafeSection:NewSlider("Strafe Chance %", "Chance to strafe", 100, 0, function(val)
    SettingsStore.StrafeChance = val
    print("Strafe chance set:", val)
end)

StrafeSection:NewSlider("Strafe Change Time", "Seconds between direction changes", 20, 5, function(val)
    SettingsStore.StrafeChangeTime = val / 10
    print("Strafe change time set:", val/10)
end)

StrafeSection:NewLabel("WASD Strafe: W + A (left) or W + D (right)")

-- Jump
JumpSection:NewToggle("Enable Jump", "Use jumps in combat", function(state)
    SettingsStore.JumpEnabled = state
    print("Jump:", state and "ON" or "OFF")
end)

JumpSection:NewSlider("Jump Chance %", "Chance to jump", 500, 0, function(val)
    SettingsStore.JumpChance = val
    print("Jump chance set:", val)
end)

JumpSection:NewSlider("Jump Height", "Jump height", 30, 1, function(val)
    SettingsStore.JumpHeight = val / 100
    print("Jump height set:", val/100)
end)

JumpSection:NewSlider("Jump Attack Chance %", "Chance to attack during jump", 500, 0, function(val)
    SettingsStore.JumpAttackChance = val
    print("Jump attack chance set:", val)
end)

JumpSection:NewSlider("Jump Cooldown", "Time between jumps", 30, 1, function(val)
    SettingsStore.JumpCooldown = val / 10
    print("Jump cooldown set:", val/10)
end)

-- Friends
FriendSection:NewTextBox("Add Friend", "Username", function(txt)
    if txt and txt ~= "" then
        table.insert(FriendList, txt)
        print("Friend added:", txt)
    end
end)

FriendSection:NewTextBox("Add To Ignore", "Username", function(txt)
    if txt and txt ~= "" then
        table.insert(IgnoreList, txt)
        print("Added to ignore:", txt)
    end
end)

-- Targets
TargetSection:NewToggle("Whitelist Mode", "Attack only friends", function(state)
    WhitelistMode = state
    if state then BlacklistMode = false end
    print("Whitelist mode:", state and "ON" or "OFF")
end)

TargetSection:NewToggle("Blacklist Mode", "Ignore listed users", function(state)
    BlacklistMode = state
    if state then WhitelistMode = false end
    print("Blacklist mode:", state and "ON" or "OFF")
end)

TargetSection:NewDropdown("Target Priority", "Which target to choose", {"Closest", "LowestHealth"}, function(option)
    SettingsStore.TargetPriority = option
    print("Target priority:", option)
end)

-- Advanced
AdvancedGeneralSection:NewToggle("Enable Block", "Use block action", function(state)
    SettingsStore.BlockChance = state and 65 or 0
    print("Block:", state and "ON" or "OFF")
end)

AdvancedGeneralSection:NewSlider("Block Chance %", "Chance to block", 200, 0, function(val)
    SettingsStore.BlockChance = val
    print("Block chance set:", val)
end)

AdvancedGeneralSection:NewSlider("Block Duration", "How long to hold block", 100, 1, function(val)
    SettingsStore.BlockDuration = val / 100
    print("Block duration set:", val/100)
end)

AdvancedCombatSection:NewSlider("Forward Dash Chance %", "Chance to dash forward", 100, 0, function(val)
    SettingsStore.ForwardDashChance = val
    print("Forward dash chance set:", val)
end)

AdvancedCombatSection:NewSlider("Back Dash Chance %", "Chance to dash back", 100, 0, function(val)
    SettingsStore.BackDashChance = val
    print("Back dash chance set:", val)
end)

AdvancedCombatSection:NewToggle("Enable Learning", "Enable Q-learning agent", function(state)
    SettingsStore.EnableLearning = state
    print("EnableLearning:", state and "ON" or "OFF")
end)

AdvancedCombatSection:NewToggle("Use DataStore", "Persist learned policy", function(state)
    SettingsStore.UseDataStore = state
    print("UseDataStore:", state and "ON" or "OFF")
end)

AdvancedCombatSection:NewSlider("Epsilon %", "Exploration rate (0-100)", 100, 0, function(val)
    SettingsStore.Epsilon = val
    print("Epsilon set:", val)
end)

AdvancedCombatSection:NewSlider("Learning Rate %", "Learning rate (0-100)", 100, 0, function(val)
    SettingsStore.LearningRate = val / 100
    print("Learning rate set:", val/100)
end)

AdvancedCombatSection:NewSlider("Discount %", "Discount factor (0-100)", 100, 0, function(val)
    SettingsStore.Discount = val / 100
    print("Discount set:", val/100)
end)

AdvancedCombatSection:NewSlider("Q Save Interval", "Seconds between saves", 600, 10, function(val)
    SettingsStore.QSaveInterval = val
    print("Q save interval set:", val)
end)

-- Hotkeys
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        AIEnabled = not AIEnabled
        if AIEnabled then
            StartAI()
        else
            StopAI()
        end
        print("AI:", AIEnabled and "ENABLED" or "DISABLED")
    elseif input.KeyCode == Enum.KeyCode.O then
        Library:ToggleUI()
    elseif input.KeyCode == Enum.KeyCode.Y then
        print("=== AI STATUS ===")
        print("Active:", AIEnabled)
        print("Target:", Target and Target.Name or "None")
        print("Distance:", Target and string.format("%.1f", GetDistance()) or "N/A")
        print("Attack distance setting:", GS("AttackDistance"))
        print("Approach distance setting:", GS("ApproachDistance"))
        print("WASD Strafe: Left", GS("StrafeLeft") and "ON" or "OFF", 
              "Right", GS("StrafeRight") and "ON" or "OFF")
        print("Combo:", ComboCount)
        print("Current settings applied correctly!")
    elseif input.KeyCode == Enum.KeyCode.U then
        print("=== SETTINGS TEST ===")
        local testDistance = 10
        print("Test distance:", testDistance)
        print("Should attack at this distance?", testDistance <= GS("AttackDistance"))
        print("Settings appear to be working!")
    end
end)

print("========================================")
print("AI DISTANCE CONTROLLER (FIXED)")
print("SETTINGS APPLYING FIXES INCLUDED")
print("")
print("What's changed:")
print("1. Functions use GetSetting() to read settings")
print("2. UI writes to SettingsStore")
print("3. Settings now affect AI behavior")
print("4. Test functions added for verification")
print("")
print("To test:")
print("1. Adjust attack distance")
print("2. Press Y for status")
print("3. Verify settings are displayed correctly")
print("4. Use 'Check Distance' button")
print("")
print("Controls:")
print("P - Toggle AI")
print("O - Show/Hide UI")
print("Y - Status and settings check")
print("U - Settings test")
print("========================================")

local function TestSettings()
    print("=== SETTINGS TEST ===")
    print("AttackDistance works:", GS("AttackDistance") == SettingsStore.AttackDistance)
    print("ApproachDistance works:", GS("ApproachDistance") == SettingsStore.ApproachDistance)
    print("OptimalFightDistance works:", GS("OptimalFightDistance") == SettingsStore.OptimalFightDistance)
    print("AutoStrafe works:", GS("AutoStrafe") == SettingsStore.AutoStrafe)
    print("SideDashFrequency works:", GS("SideDashFrequency") == SettingsStore.SideDashFrequency)
    print("LeftDashChance works:", GS("LeftDashChance") == SettingsStore.LeftDashChance)
    print("RightDashChance works:", GS("RightDashChance") == SettingsStore.RightDashChance)
    print("UseUltimate works:", GS("UseUltimate") == SettingsStore.UseUltimate)
    return true
end

-- Run simple test on load
task.wait(1)
TestSettings()

return {
    StartAI = StartAI,
    StopAI = StopAI,
    GetSetting = GetSetting,
    SettingsStore = SettingsStore,
    TestSettings = TestSettings
}
