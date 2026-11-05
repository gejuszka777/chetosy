--[[
	CHEŁMSKI SIEKATOR V4
	Zaawansowany toolkit PvP dla Roblox (Luau)
	Uruchomienie: loadstring(game:HttpGet("<TWOJ_URL>"))()
	Autor: Venice
]]

if getgenv().CHELMSKI_V4 then
	pcall(function() getgenv().CHELMSKI_V4:Destroy() end)
end

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UserInput     = game:GetService("UserInputService")
local HttpService   = game:GetService("HttpService")
local Workspace     = game:GetService("Workspace")
local CoreGui       = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

local CS = {}
CS.Version   = "4.0"
CS.Connections = {}
CS.Alive     = true
CS.Destroyed = false

--==========================================================
-- CORE :: Signal
--==========================================================
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _h = {} }, Signal)
end

function Signal:Connect(fn)
	table.insert(self._h, fn)
	return {
		Disconnect = function()
			local i = table.find(self._h, fn)
			if i then table.remove(self._h, i) end
		end,
	}
end

function Signal:Fire(...)
	for _, fn in ipairs(self._h) do
		task.spawn(fn, ...)
	end
end

function Signal:Clear()
	self._h = {}
end

CS.Signal = {
	ConfigChanged = Signal.new(),
	TargetChanged = Signal.new(),
	Unload        = Signal.new(),
}

--==========================================================
-- CORE :: Util
--==========================================================
local Util = {}

function Util.New(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if parent then inst.Parent = parent end
	return inst
end

function Util.Corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = inst
	return c
end

function Util.Stroke(inst, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function Util.Pad(inst, ...)
	local p = Instance.new("UIPadding")
	local map = { Top = "PaddingTop", Bottom = "PaddingBottom", Left = "PaddingLeft", Right = "PaddingRight" }
	for _, side in ipairs({ ... }) do
		local name, val = side[1], side[2]
		if map[name] then p[map[name]] = UDim.new(0, val) end
	end
	p.Parent = inst
	return p
end

function Util.Tween(inst, time, props, style, dir)
	local ti = TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, ti, props)
	t:Play()
	return t
end

function Util.Round(n, step)
	if step <= 0 then return n end
	return math.floor(n / step + 0.5) * step
end

function Util.IsAlive(char)
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

function Util.Track(conn)
	table.insert(CS.Connections, conn)
	return conn
end

CS.Util = Util

--==========================================================
-- CORE :: Storage
--==========================================================
local Storage = {}
local FILE = "ChelmskiSiekatorV4.json"

function Storage.Save(data)
	if not writefile then return false end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	if not ok then return false end
	pcall(writefile, FILE, encoded)
	return ok
end

function Storage.Load()
	if not readfile then return nil end
	if isfile and not isfile(FILE) then return nil end
	local ok, raw = pcall(readfile, FILE)
	if not ok or not raw or raw == "" then return nil end
	local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok2 and decoded or nil
end

CS.Storage = Storage

--==========================================================
-- CORE :: Config
--==========================================================
local DEFAULTS = {
	-- Silent Aim
	SilentAim       = false,
	SilentAimFOV    = 140,
	SilentAimRange  = 900,
	SilentAimPart   = "Head",
	SilentAimVisible = false,
	SilentAimCircle = true,
	SilentAimViz    = true,
	-- Aimbot
	Aimbot          = false,
	AimbotFOV       = 120,
	AimbotSmooth    = 0.18,
	AimbotRange     = 900,
	AimbotPart      = "Head",
	AimbotVisible   = true,
	-- ESP
	ESP             = false,
	ESPBox          = true,
	ESPSkeleton     = true,
	ESPName         = true,
	ESPDistance     = true,
	ESPHealth       = true,
	ESPTracer       = false,
	ESPTeamCheck    = true,
	ESPColorEnemy   = { 61, 255, 158 },
	ESPColorTeam    = { 90, 170, 255 },
	ESPColorSkel    = { 255, 255, 255 },
	ESPColorHealth  = { 61, 255, 158 },
	-- Wallhack
	Wallhack        = false,
	WallhackPlayers = true,
	WallhackBots    = true,
	WallhackObjects = false,
	WallhackFill    = 0.55,
	WallhackColor   = { 61, 255, 158 },
	-- Hitbox
	Hitbox          = false,
	HitboxWidth     = 4,
	HitboxHeight    = 6,
	HitboxPreview   = true,
	-- UI
	UIOpen          = true,
}

local Config = {}
local configData = {}

for k, v in pairs(DEFAULTS) do
	configData[k] = (type(v) == "table") and table.clone(v) or v
end

local saved = Storage.Load()
if saved then
	for k, v in pairs(saved) do
		if DEFAULTS[k] ~= nil then
			configData[k] = (type(v) == type(DEFAULTS[k])) and v or configData[k]
		end
	end
end

function Config.Get(key)
	return configData[key]
end

function Config.Set(key, value, silent)
	configData[key] = value
	if not silent then
		CS.Signal.ConfigChanged:Fire(key, value)
	end
end

function Config.All()
	return table.clone(configData)
end

function Config.Reset()
	for k, v in pairs(DEFAULTS) do
		Config.Set(k, (type(v) == "table") and table.clone(v) or v, true)
	end
	CS.Signal.ConfigChanged:Fire("__reset__", nil)
end

function Config.Save()
	Storage.Save(configData)
end

CS.Config = Config

--==========================================================
-- LOGIKA :: Targeting
--==========================================================
local Targeting = {}

local PART_CHAINS = {
	Head        = { "Head" },
	HumanoidRootPart = { "HumanoidRootPart" },
	UpperTorso  = { "UpperTorso", "Torso", "HumanoidRootPart" },
	ClosestPart = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
}

function Targeting.ResolvePart(char, mode)
	if not char then return nil end
	if mode == "ClosestPart" then
		local best, bestD
		local camPos = Camera.CFrame.Position
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				local dist = (d.Position - camPos).Magnitude
				if not bestD or dist < bestD then best, bestD = d, dist end
			end
		end
		return best
	end
	for _, name in ipairs(PART_CHAINS[mode] or PART_CHAINS.Head) do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then return p end
	end
	return nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function Targeting.IsVisible(part)
	if not part then return false end
	local ignore = { LocalPlayer.Character, part.Parent }
	rayParams.FilterDescendantsInstances = ignore
	local origin = Camera.CFrame.Position
	local dir = part.Position - origin
	local hit = Workspace:Raycast(origin, dir, rayParams)
	return hit == nil or hit.Instance:IsDescendantOf(part.Parent)
end

function Targeting.GetBest(cfg)
	local best, bestScore
	local camPos = Camera.CFrame.Position
	local viewport = Camera.ViewportSize
	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
	local localTeam = LocalPlayer.Team

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			if Util.IsAlive(char) and not (cfg.teamCheck and plr.Team == localTeam) then
				local part = Targeting.ResolvePart(char, cfg.part)
				if part then
					local dist = (part.Position - camPos).Magnitude
					if dist <= cfg.range then
						local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
						if onScreen and screen.Z > 0 then
							local fovDist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
							if fovDist <= cfg.fov then
								local score = fovDist + dist * 0.04
								if cfg.visible and not Targeting.IsVisible(part) then
									score += 400
								end
								if not bestScore or score < bestScore then
									best, bestScore = { Player = plr, Part = part }, score
								end
							end
						end
					end
				end
			end
		end
	end
	return best
end

CS.Targeting = Targeting

--==========================================================
-- LOGIKA :: SilentAim
--==========================================================
local SilentAim = { Target = nil, Busy = false }

function SilentAim:GetConfig()
	return {
		fov     = Config.Get("SilentAimFOV"),
		range   = Config.Get("SilentAimRange"),
		part    = Config.Get("SilentAimPart"),
		visible = Config.Get("SilentAimVisible"),
		teamCheck = Config.Get("ESPTeamCheck"),
	}
end

function SilentAim:Update()
	if not Config.Get("SilentAim") then
		self.Target = nil
		return
	end
	local target = Targeting.GetBest(self:GetConfig())
	self.Target = target
end

local mtHooked = false
local oldIndex

function SilentAim:InstallHook()
	if mtHooked then return end
	local mt = getrawmetatable(game)
	if not mt then return end
	oldIndex = mt.__index
	setreadonly(mt, false)

	mt.__index = newcclosure(function(self, key)
		local t = SilentAim.Target
		if t and t.Part and t.Part.Parent and not SilentAim.Busy then
			if self == Mouse then
				if key == "Hit" then
					return CFrame.new(t.Part.Position)
				elseif key == "Target" then
					return t.Part.Parent
				elseif key == "UnitRay" then
					local origin = Camera.CFrame.Position
					return Ray.new(origin, (t.Part.Position - origin).Unit * 2048)
				end
			elseif self == Camera and key == "CFrame" then
				return CFrame.lookAt(Camera.CFrame.Position, t.Part.Position)
			end
		end
		return oldIndex(self, key)
	end)

	setreadonly(mt, true)
	mtHooked = true
end

--==========================================================
-- LOGIKA :: Aimbot
--==========================================================
local Aimbot = { Conn = nil, Target = nil }

function Aimbot:Start()
	if self.Conn then return end
	self.Conn = Util.Track(RunService.RenderStepped:Connect(function(dt)
		if not Config.Get("Aimbot") then
			self.Target = nil
			return
		end

		local target = Targeting.GetBest({
			fov       = Config.Get("AimbotFOV"),
			range     = Config.Get("AimbotRange"),
			part      = Config.Get("AimbotPart"),
			visible   = Config.Get("AimbotVisible"),
			teamCheck = Config.Get("ESPTeamCheck"),
		})
		self.Target = target

		if target then
			local smooth = math.clamp(Config.Get("AimbotSmooth"), 0.01, 1)
			local goal = CFrame.lookAt(Camera.CFrame.Position, target.Part.Position)
			SilentAim.Busy = true
			Camera.CFrame = Camera.CFrame:Lerp(goal, 1 - math.exp(-dt / smooth * 6))
			SilentAim.Busy = false
		end
	end))
end

function Aimbot:Stop()
	if self.Conn then
		self.Conn:Disconnect()
		self.Conn = nil
	end
	self.Target = nil
end

--==========================================================
-- LOGIKA :: ESP
--==========================================================
local ESP = { Pool = {}, Conn = nil }

local R15_BONES = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "LowerTorso", "HumanoidRootPart" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local R6_BONES = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function newDrawing(class, props)
	local d = Drawing.new(class)
	for k, v in pairs(props or {}) do
		d[k] = v
	end
	return d
end

local function colorFrom(tbl)
	return Color3.fromRGB(tbl[1], tbl[2], tbl[3])
end

function ESP:CreateEntry(plr)
	local entry = {
		Box      = newDrawing("Square", { Thickness = 1, Filled = false, Visible = false }),
		Name     = newDrawing("Text", { Size = 14, Center = true, Outline = true, Visible = false }),
		Dist     = newDrawing("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
		HealthBg = newDrawing("Square", { Filled = true, Thickness = 1, Visible = false }),
		HealthFg = newDrawing("Square", { Filled = true, Thickness = 1, Visible = false }),
		Tracer   = newDrawing("Line", { Thickness = 1, Visible = false }),
		Bones    = {},
	}
	self.Pool[plr] = entry
	return entry
end

function ESP:CleanEntry(plr)
	local entry = self.Pool[plr]
	if not entry then return end
	entry.Box:Remove()
	entry.Name:Remove()
	entry.Dist:Remove()
	entry.HealthBg:Remove()
	entry.HealthFg:Remove()
	entry.Tracer:Remove()
	for _, b in ipairs(entry.Bones) do b:Remove() end
	self.Pool[plr] = nil
end

function ESP:Update()
	local viewport = Camera.ViewportSize
	local localTeam = LocalPlayer.Team

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == LocalPlayer then continue end
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local head = char and char:FindFirstChild("Head")
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))

		local active = Config.Get("ESP") and Util.IsAlive(char) and head and root
		if active and Config.Get("ESPTeamCheck") and plr.Team == localTeam then
			active = false
		end

		local entry = self.Pool[plr]
		if not active then
			if entry then
				entry.Box.Visible = false
				entry.Name.Visible = false
				entry.Dist.Visible = false
				entry.HealthBg.Visible = false
				entry.HealthFg.Visible = false
				entry.Tracer.Visible = false
				for _, b in ipairs(entry.Bones) do b.Visible = false end
			end
			continue
		end

		entry = entry or self:CreateEntry(plr)

		local headScreen, headOn = Camera:WorldToViewportPoint(head.Position)
		local rootScreen, rootOn = Camera:WorldToViewportPoint(root.Position)

		if not headOn or not rootOn or headScreen.Z <= 0 then
			entry.Box.Visible = false
			entry.Name.Visible = false
			entry.Dist.Visible = false
			entry.HealthBg.Visible = false
			entry.HealthFg.Visible = false
			entry.Tracer.Visible = false
			for _, b in ipairs(entry.Bones) do b.Visible = false end
			continue
		end

		local isTeam = plr.Team == localTeam
		local col = isTeam and colorFrom(Config.Get("ESPColorTeam")) or colorFrom(Config.Get("ESPColorEnemy"))
		local height = math.abs(rootScreen.Y - headScreen.Y) * 2.2
		local width = height * 0.55
		local center = Vector2.new(headScreen.X, headScreen.Y - height * 0.25)

		-- Box
		entry.Box.Visible = Config.Get("ESPBox")
		entry.Box.Color = col
		entry.Box.Size = Vector2.new(width, height)
		entry.Box.Position = center - Vector2.new(width / 2, 0)

		-- Name
		entry.Name.Visible = Config.Get("ESPName")
		entry.Name.Color = col
		entry.Name.Text = plr.DisplayName
		entry.Name.Position = center - Vector2.new(0, 20)

		-- Distance
		entry.Dist.Visible = Config.Get("ESPDistance")
		entry.Dist.Color = col
		entry.Dist.Text = string.format("%d m", math.floor((root.Position - Camera.CFrame.Position).Magnitude / 3))
		entry.Dist.Position = center + Vector2.new(0, height + 4)

		-- Health
		local hpVisible = Config.Get("ESPHealth") and hum
		entry.HealthBg.Visible = hpVisible and true or false
		entry.HealthFg.Visible = hpVisible and true or false
		if hpVisible then
			local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			local hcol = Color3.fromRGB(
				math.floor(255 * (1 - pct)),
				math.floor(255 * pct),
				70
			)
			entry.HealthBg.Color = Color3.fromRGB(15, 18, 22)
			entry.HealthBg.Size = Vector2.new(3, height)
			entry.HealthBg.Position = center - Vector2.new(width / 2 + 6, 0)
			entry.HealthFg.Color = hcol
			entry.HealthFg.Size = Vector2.new(3, height * pct)
			entry.HealthFg.Position = center - Vector2.new(width / 2 + 6, 0) + Vector2.new(0, height * (1 - pct))
		end

		-- Tracer
		entry.Tracer.Visible = Config.Get("ESPTracer")
		entry.Tracer.Color = col
		entry.Tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
		entry.Tracer.To = center

		-- Skeleton
		local bones = hum.RigType == Enum.HumanoidRigType.R15 and R15_BONES or R6_BONES
		local skelOn = Config.Get("ESPSkeleton")
		local skelCol = colorFrom(Config.Get("ESPColorSkel"))
		for i, pair in ipairs(bones) do
			local line = entry.Bones[i]
			if not line then
				line = newDrawing("Line", { Thickness = 1, Visible = false })
				entry.Bones[i] = line
			end
			local a = char:FindFirstChild(pair[1])
			local b = char:FindFirstChild(pair[2])
			if skelOn and a and b then
				local sa, oa = Camera:WorldToViewportPoint(a.Position)
				local sb, ob = Camera:WorldToViewportPoint(b.Position)
				if oa and ob then
					line.Visible = true
					line.Color = skelCol
					line.From = Vector2.new(sa.X, sa.Y)
					line.To = Vector2.new(sb.X, sb.Y)
				else
					line.Visible = false
				end
			else
				line.Visible = false
			end
		end
	end
end

function ESP:Start()
	if self.Conn then return end
	self.Conn = Util.Track(RunService.RenderStepped:Connect(function()
		pcall(self.Update, self)
	end))
	Util.Track(Players.PlayerRemoving:Connect(function(p)
		task.defer(function() self:CleanEntry(p) end)
	end))
end

function ESP:Stop()
	if self.Conn then
		self.Conn:Disconnect()
		self.Conn = nil
	end
	for plr in pairs(self.Pool) do
		self:CleanEntry(plr)
	end
end

--==========================================================
-- LOGIKA :: Wallhack
--==========================================================
local Wallhack = { Pool = {}, Conn = nil }

function Wallhack:Apply(inst, color)
	if self.Pool[inst] then return end
	local hl = Instance.new("Highlight")
	hl.Name = "CS_WH"
	hl.Adornee = inst
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor = color
	hl.FillTransparency = Config.Get("WallhackFill")
	hl.OutlineColor = color
	hl.OutlineTransparency = 0.1
	hl.Parent = inst
	self.Pool[inst] = hl
end

function Wallhack:Clear()
	for inst, hl in pairs(self.Pool) do
		pcall(function() hl:Destroy() end)
	end
	self.Pool = {}
end

function Wallhack:Update()
	if not Config.Get("Wallhack") then
		if next(self.Pool) then self:Clear() end
		return
	end

	local color = colorFrom(Config.Get("WallhackColor"))
	local fill = Config.Get("WallhackFill")

	-- gracze
	if Config.Get("WallhackPlayers") then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				self:Apply(plr.Character, color)
			end
		end
	end

	-- boty / NPC
	if Config.Get("WallhackBots") then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(d) then
				self:Apply(d, color)
			end
		end
	end

	-- obiekty
	if Config.Get("WallhackObjects") then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Model") then
				self:Apply(d, color)
			end
		end
	end

	for _, hl in pairs(self.Pool) do
		hl.FillTransparency = fill
	end
end

function Wallhack:Start()
	if self.Conn then return end
	self.Conn = Util.Track(task.spawn(function()
		while CS.Alive do
			pcall(self.Update, self)
			task.wait(0.5)
		end
	end))
end

function Wallhack:Stop()
	if self.Conn then
		self.Conn:Disconnect()
		self.Conn = nil
	end
	self:Clear()
end

--==========================================================
-- LOGIKA :: Hitbox
--==========================================================
local Hitbox = { Originals = {}, Applied = {}, PreviewDrawings = {} }

local HITBOX_PARTS = { "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }

function Hitbox:ApplyTo(char)
	if not char then return end
	if self.Applied[char] then return end
	self.Applied[char] = true
	local w = Config.Get("HitboxWidth")
	local h = Config.Get("HitboxHeight")
	for _, name in ipairs(HITBOX_PARTS) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			self.Originals[part] = self.Originals[part] or part.Size
			part.Size = Vector3.new(w, h, w)
			part.CanCollide = false
		end
	end
end

function Hitbox:Restore(char)
	if not char then return end
	self.Applied[char] = nil
	for part, size in pairs(self.Originals) do
		if part and part.Parent and part:IsDescendantOf(char) then
			part.Size = size
			self.Originals[part] = nil
		end
	end
end

function Hitbox:RefreshAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			if Config.Get("Hitbox") then
				self:ApplyTo(plr.Character)
			else
				self:Restore(plr.Character)
			end
		end
	end
	if Config.Get("Hitbox") and LocalPlayer.Character then
		self:ApplyTo(LocalPlayer.Character)
	elseif LocalPlayer.Character then
		self:Restore(LocalPlayer.Character)
	end
end

function Hitbox:DrawPreview()
	for _, d in pairs(self.PreviewDrawings) do d:Remove() end
	self.PreviewDrawings = {}
	if not Config.Get("Hitbox") or not Config.Get("HitboxPreview") then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			for _, name in ipairs(HITBOX_PARTS) do
				local part = plr.Character:FindFirstChild(name)
				if part then
					local box = newDrawing("Square", { Thickness = 1, Filled = false, Color = Color3.fromRGB(61, 255, 158) })
					local pos, on = Camera:WorldToViewportPoint(part.Position)
					if on then
						local size = Camera:WorldToViewportPoint(part.Position + Vector3.new(part.Size.X / 2, part.Size.Y / 2, 0))
						box.Size = Vector2.new(math.abs(size.X - pos.X) * 2, math.abs(size.Y - pos.Y) * 2)
						box.Position = Vector2.new(pos.X - box.Size.X / 2, pos.Y - box.Size.Y / 2)
						box.Visible = true
					end
					table.insert(self.PreviewDrawings, box)
				end
			end
		end
	end
end

function Hitbox:Init()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			plr.CharacterAdded:Connect(function(char)
				char:WaitForChild("Humanoid")
				task.wait(0.2)
				if Config.Get("Hitbox") then self:ApplyTo(char) end
			end)
		end
		plr.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid")
			task.wait(0.2)
			if Config.Get("Hitbox") then self:ApplyTo(char) end
		end)
	end
end

--==========================================================
-- LOGIKA :: Overlay (FOV / wizualizacja celu)
--==========================================================
local Overlay = { Circle = nil, Box = nil, Line = nil, Info = nil }

function Overlay:Init()
	self.Circle = newDrawing("Circle", { Thickness = 1, Filled = false, Visible = false, NumSides = 64 })
	self.Box    = newDrawing("Square", { Thickness = 2, Filled = false, Visible = false, Color = Color3.fromRGB(61, 255, 158) })
	self.Line   = newDrawing("Line", { Thickness = 1, Visible = false, Color = Color3.fromRGB(61, 255, 158) })
	self.Info   = newDrawing("Text", { Size = 13, Center = true, Outline = true, Visible = false, Color = Color3.fromRGB(61, 255, 158) })
end

function Overlay:Update()
	local vp = Camera.ViewportSize
	local center = Vector2.new(vp.X / 2, vp.Y / 2)

	local showCircle = Config.Get("SilentAim") and Config.Get("SilentAimCircle")
	self.Circle.Visible = showCircle
	if showCircle then
		self.Circle.Position = center
		self.Circle.Radius = Config.Get("SilentAimFOV")
		self.Circle.Color = Color3.fromRGB(61, 255, 158)
	end

	local target = SilentAim.Target or Aimbot.Target
	local showViz = target and Config.Get("SilentAimViz") and target.Part.Parent
	if showViz then
		local pos, on = Camera:WorldToViewportPoint(target.Part.Position)
		if on then
			self.Box.Visible = true
			self.Box.Size = Vector2.new(28, 28)
			self.Box.Position = Vector2.new(pos.X - 14, pos.Y - 14)
			self.Line.Visible = true
			self.Line.From = center
			self.Line.To = Vector2.new(pos.X, pos.Y)
			self.Info.Visible = true
			self.Info.Text = string.format("%s | %s", target.Player.Name, target.Part.Name)
			self.Info.Position = Vector2.new(pos.X, pos.Y - 26)
		else
			self.Box.Visible = false
			self.Line.Visible = false
			self.Info.Visible = false
		end
	else
		self.Box.Visible = false
		self.Line.Visible = false
		self.Info.Visible = false
	end
end

--==========================================================
-- UI :: Theme
--==========================================================
local Theme = {
	Bg        = Color3.fromRGB(12, 15, 19),
	Panel     = Color3.fromRGB(18, 22, 28),
	Element   = Color3.fromRGB(25, 30, 37),
	Hover     = Color3.fromRGB(33, 40, 48),
	Stroke    = Color3.fromRGB(40, 48, 57),
	Text      = Color3.fromRGB(232, 240, 236),
	Dim       = Color3.fromRGB(130, 143, 152),
	Accent    = Color3.fromRGB(61, 255, 158),
	AccentDim = Color3.fromRGB(24, 90, 58),
}

--==========================================================
-- UI :: Library
--==========================================================
local UI = {}
UI.Tabs = {}

local function buildRoot()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChelmskiSiekatorV4"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 9999
	gui.Parent = (gethui and gethui()) or CoreGui

	local main = Util.New("Frame", {
		Name = "Main",
		Size = UDim2.new(0, 620, 0, 420),
		Position = UDim2.new(0.5, -310, 0.5, -210),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
	}, gui)
	Util.Corner(main, 14)
	Util.Stroke(main, Theme.Stroke, 1)
	main.ClipsDescendants = true

	local shadow = Instance.new("ImageLabel")
	shadow.Image = "rbxassetid://5028857084"
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(24, 24, 276, 276)
	shadow.Size = UDim2.new(1, 30, 1, 30)
	shadow.Position = UDim2.new(0, -15, 0, -15)
	shadow.BackgroundTransparency = 1
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 0.55
	shadow.ZIndex = 0
	shadow.Parent = main

	-- Title bar
	local bar = Util.New("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, main)

	local logo = Util.New("Frame", {
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(0, 14, 0, 11),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, bar)
	Util.Corner(logo, 9)
	local logoText = Util.New("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "CS",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Theme.Bg,
		ZIndex = 5,
	}, logo)

	local title = Util.New("TextLabel", {
		Size = UDim2.new(1, -180, 0, 30),
		Position = UDim2.new(0, 54, 0, 11),
		BackgroundTransparency = 1,
		Text = "CHEŁMSKI SIEKATOR",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, bar)

	local ver = Util.New("TextLabel", {
		Size = UDim2.new(0, 40, 0, 30),
		Position = UDim2.new(0, 200, 0, 11),
		BackgroundTransparency = 1,
		Text = "V4",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, bar)

	local function barBtn(txt, xoff, cb)
		local b = Util.New("TextButton", {
			Size = UDim2.new(0, 26, 0, 26),
			Position = UDim2.new(1, xoff, 0, 13),
			BackgroundColor3 = Theme.Element,
			Text = txt,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Theme.Dim,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, bar)
		Util.Corner(b, 8)
		b.MouseEnter:Connect(function()
			Util.Tween(b, 0.12, { BackgroundColor3 = Theme.Hover, TextColor3 = Theme.Text })
		end)
		b.MouseLeave:Connect(function()
			Util.Tween(b, 0.12, { BackgroundColor3 = Theme.Element, TextColor3 = Theme.Dim })
		end)
		b.MouseButton1Click:Connect(cb)
		return b
	end

	barBtn("–", -70, function() UI:Minimize() end)
	barBtn("✕", -38, function() UI:Close() end)

	-- Drag
	local dragging, dragStart, startPos
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	UserInput.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	UserInput.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	-- Sidebar
	local side = Util.New("Frame", {
		Name = "Side",
		Size = UDim2.new(0, 150, 1, -52),
		Position = UDim2.new(0, 0, 0, 52),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
	}, main)
	local sidePad = Instance.new("UIPadding")
	sidePad.PaddingTop = UDim.new(0, 12)
	sidePad.PaddingLeft = UDim.new(0, 10)
	sidePad.PaddingRight = UDim.new(0, 10)
	sidePad.Parent = side
	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 6)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = side

	local content = Util.New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -150, 1, -52),
		Position = UDim2.new(0, 150, 0, 52),
		BackgroundTransparency = 1,
	}, main)

	return gui, main, side, content
end

function UI:Init()
	self.Gui, self.Main, self.Side, self.Content = buildRoot()
	self.Main.Size = UDim2.new(0, 620, 0, 0)
	Util.Tween(self.Main, 0.3, { Size = UDim2.new(0, 620, 0, 420) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function UI:Tab(name, icon)
	local btn = Util.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 1,
		Text = "  " .. name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Theme.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, self.Side)
	Util.Corner(btn, 8)

	local page = Util.New("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.new(0, 12, 0, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.AccentDim,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Visible = false,
	}, self.Content)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = page
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
	end)

	local tab = { Button = btn, Page = page, Name = name }
	table.insert(self.Tabs, tab)

	btn.MouseEnter:Connect(function()
		if self.Active ~= tab then
			Util.Tween(btn, 0.12, { TextColor3 = Theme.Text, BackgroundTransparency = 0.85 })
		end
	end)
	btn.MouseLeave:Connect(function()
		if self.Active ~= tab then
			Util.Tween(btn, 0.12, { TextColor3 = Theme.Dim, BackgroundTransparency = 1 })
		end
	end)
	btn.MouseButton1Click:Connect(function() self:Select(tab) end)

	return tab
end

function UI:Select(tab)
	if self.Active == tab then return end
	if self.Active then
		self.Active.Page.Visible = false
		Util.Tween(self.Active.Button, 0.12, { TextColor3 = Theme.Dim, BackgroundTransparency = 1 })
	end
	self.Active = tab
	tab.Page.Visible = true
	Util.Tween(tab.Button, 0.12, { TextColor3 = Theme.Accent, BackgroundTransparency = 0.7 })
end

function UI:Section(page, text)
	local lbl = Util.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = text:upper(),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
	return lbl
end

function UI:Toggle(page, label, key, callback)
	local row = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
	}, page)
	Util.Corner(row, 8)

	local txt = Util.New("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local pill = Util.New("Frame", {
		Size = UDim2.new(0, 38, 0, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = Theme.Hover,
		BorderSizePixel = 0,
	}, row)
	Util.Corner(pill, 10)

	local knob = Util.New("Frame", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = Theme.Dim,
		BorderSizePixel = 0,
	}, pill)
	Util.Corner(knob, 7)

	local btn = Util.New("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
	}, row)

	local state = Config.Get(key)

	local function render(on, animate)
		local props = on and {
			BackgroundColor3 = Theme.AccentDim,
		} or {
			BackgroundColor3 = Theme.Hover,
		}
		local knobProps = on and {
			Position = UDim2.new(1, -17, 0.5, -7),
			BackgroundColor3 = Theme.Accent,
		} or {
			Position = UDim2.new(0, 3, 0.5, -7),
			BackgroundColor3 = Theme.Dim,
		}
		if animate then
			Util.Tween(pill, 0.15, props)
			Util.Tween(knob, 0.15, knobProps)
		else
			for k, v in pairs(props) do pill[k] = v end
			for k, v in pairs(knobProps) do knob[k] = v end
		end
	end

	render(state, false)

	btn.MouseButton1Click:Connect(function()
		state = not state
		Config.Set(key, state)
		render(state, true)
		if callback then task.spawn(callback, state) end
	end)

	return row
end

function UI:Slider(page, label, key, min, max, step, suffix, callback)
	local row = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
	}, page)
	Util.Corner(row, 8)

	Util.New("TextLabel", {
		Size = UDim2.new(1, -80, 0, 20),
		Position = UDim2.new(0, 12, 0, 6),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local val = Util.New("TextLabel", {
		Size = UDim2.new(0, 60, 0, 20),
		Position = UDim2.new(1, -72, 0, 6),
		BackgroundTransparency = 1,
		Text = tostring(Config.Get(key)) .. (suffix or ""),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)

	local track = Util.New("Frame", {
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.new(0, 12, 0, 34),
		BackgroundColor3 = Theme.Hover,
		BorderSizePixel = 0,
	}, row)
	Util.Corner(track, 2)

	local fill = Util.New("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, track)
	Util.Corner(fill, 2)

	local knob = Util.New("Frame", {
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0, 0, 0.5, -6),
		BackgroundColor3 = Theme.Text,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, track)
	Util.Corner(knob, 6)

	local dragging = false

	local function setValue(v, fire)
		v = math.clamp(Util.Round(v, step), min, max)
		local alpha = (v - min) / (max - min)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, -6, 0.5, -6)
		val.Text = tostring(v) .. (suffix or "")
		Config.Set(key, v)
		if fire and callback then task.spawn(callback, v) end
	end

	setValue(Config.Get(key), false)

	local function updateFromInput(input)
		local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(min + (max - min) * rel, true)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateFromInput(input)
		end
	end)
	UserInput.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromInput(input)
		end
	end)
	UserInput.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	row.setValue = setValue
	return row
end

function UI:Dropdown(page, label, key, options, callback)
	local row = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, page)
	Util.Corner(row, 8)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = row

	local head = Util.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, row)

	Util.New("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, head)

	local current = Util.New("TextLabel", {
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.new(1, -72, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(Config.Get(key)) .. " ▾",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, head)

	local open = false
	local holder = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
	}, row)

	local holderList = Instance.new("UIListLayout")
	holderList.Padding = UDim.new(0, 4)
	holderList.Parent = holder

	for _, opt in ipairs(options) do
		local b = Util.New("TextButton", {
			Size = UDim2.new(1, -16, 0, 26),
			BackgroundColor3 = Theme.Hover,
			Text = "  " .. opt,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, holder)
		Util.Corner(b, 6)
		b.MouseEnter:Connect(function() Util.Tween(b, 0.1, { TextColor3 = Theme.Text }) end)
		b.MouseLeave:Connect(function() Util.Tween(b, 0.1, { TextColor3 = Theme.Dim }) end)
		b.MouseButton1Click:Connect(function()
			Config.Set(key, opt)
			current.Text = opt .. " ▾"
			open = false
			Util.Tween(row, 0.15, { Size = UDim2.new(1, 0, 0, 34) })
			holder.Visible = false
			if callback then task.spawn(callback, opt) end
		end)
	end
	holder.Visible = false

	head.MouseButton1Click:Connect(function()
		open = not open
		holder.Visible = open
		local target = open and (34 + #options * 30 + 6) or 34
		Util.Tween(row, 0.18, { Size = UDim2.new(1, 0, 0, target) })
	end)

	return row
end

local SWATCHES = {
	{ 61, 255, 158 }, { 90, 170, 255 }, { 255, 90, 90 }, { 255, 200, 60 },
	{ 200, 120, 255 }, { 255, 255, 255 }, { 255, 120, 200 }, { 120, 255, 255 },
}

function UI:ColorPicker(page, label, key)
	local row = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
	}, page)
	Util.Corner(row, 8)

	Util.New("TextLabel", {
		Size = UDim2.new(0, 140, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	for i, rgb in ipairs(SWATCHES) do
		local sw = Util.New("TextButton", {
			Size = UDim2.new(0, 18, 0, 18),
			Position = UDim2.new(0, 150 + (i - 1) * 22, 0.5, -9),
			BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, row)
		Util.Corner(sw, 9)
		sw.MouseButton1Click:Connect(function()
			Config.Set(key, table.clone(rgb))
		end)
	end
	return row
end

function UI:Button(page, label, callback, danger)
	local b = Util.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = danger and Color3.fromRGB(70, 26, 30) or Theme.Element,
		Text = label,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = danger and Color3.fromRGB(255, 140, 140) or Theme.Text,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, page)
	Util.Corner(b, 8)
	b.MouseEnter:Connect(function() Util.Tween(b, 0.12, { BackgroundColor3 = Theme.Hover }) end)
	b.MouseLeave:Connect(function()
		Util.Tween(b, 0.12, { BackgroundColor3 = danger and Color3.fromRGB(70, 26, 30) or Theme.Element })
	end)
	b.MouseButton1Click:Connect(function() task.spawn(callback) end)
	return b
end

function UI:Label(page, text, dim)
	local l = Util.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = dim and Theme.Dim or Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, page)
	return l
end

function UI:Minimize()
	self.Minimized = not self.Minimized
	local goal = self.Minimized and UDim2.new(0, 620, 0, 52) or UDim2.new(0, 620, 0, 420)
	Util.Tween(self.Main, 0.2, { Size = goal }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self.Side.Visible = not self.Minimized
	self.Content.Visible = not self.Minimized
end

function UI:Close()
	self.Gui.Enabled = false
end

function UI:Open()
	self.Gui.Enabled = true
end

function UI:ToggleOpen()
	self.Gui.Enabled = not self.Gui.Enabled
end

CS.UI = UI

--==========================================================
-- UI :: Build
--==========================================================
local function buildUI()
	UI:Init()

	-- ── AIM ─────────────────────────────────────────────
	local aim = UI:Tab("Aim")
	UI:Section(aim.Page, "Silent Aim")
	UI:Toggle(aim.Page, "Silent Aim", "SilentAim", function(on)
		if on then SilentAim:InstallHook() end
	end)
	UI:Slider(aim.Page, "FOV", "SilentAimFOV", 20, 500, 5, " px")
	UI:Slider(aim.Page, "Zasięg", "SilentAimRange", 50, 3000, 25, " st")
	UI:Dropdown(aim.Page, "Część ciała", "SilentAimPart", { "Head", "UpperTorso", "HumanoidRootPart", "ClosestPart" })
	UI:Toggle(aim.Page, "Tylko widoczni", "SilentAimVisible")
	UI:Toggle(aim.Page, "Koło FOV", "SilentAimCircle")
	UI:Toggle(aim.Page, "Wizualizacja celu", "SilentAimViz")

	UI:Section(aim.Page, "Aimbot")
	UI:Toggle(aim.Page, "Aimbot", "Aimbot", function(on)
		if on then Aimbot:Start() else Aimbot:Stop() end
	end)
	UI:Slider(aim.Page, "Płynność", "AimbotSmooth", 0.01, 1, 0.01, "")
	UI:Slider(aim.Page, "FOV", "AimbotFOV", 10, 400, 5, " px")
	UI:Slider(aim.Page, "Zasięg", "AimbotRange", 50, 3000, 25, " st")
	UI:Dropdown(aim.Page, "Punkt celowania", "AimbotPart", { "Head", "UpperTorso", "HumanoidRootPart", "ClosestPart" })
	UI:Toggle(aim.Page, "Tylko widoczni", "AimbotVisible")

	-- ── VISUALS ─────────────────────────────────────────
	local vis = UI:Tab("Visuals")
	UI:Section(vis.Page, "ESP")
	UI:Toggle(vis.Page, "ESP", "ESP", function(on)
		if on then ESP:Start() else ESP:Stop() end
	end)
	UI:Toggle(vis.Page, "Box ESP", "ESPBox")
	UI:Toggle(vis.Page, "Skeleton ESP", "ESPSkeleton")
	UI:Toggle(vis.Page, "Name ESP", "ESPName")
	UI:Toggle(vis.Page, "Distance ESP", "ESPDistance")
	UI:Toggle(vis.Page, "Health ESP", "ESPHealth")
	UI:Toggle(vis.Page, "Tracer", "ESPTracer")
	UI:Toggle(vis.Page, "Team Check", "ESPTeamCheck")
	UI:Section(vis.Page, "Kolory")
	UI:ColorPicker(vis.Page, "Wróg", "ESPColorEnemy")
	UI:ColorPicker(vis.Page, "Sojusznik", "ESPColorTeam")
	UI:ColorPicker(vis.Page, "Szkielet", "ESPColorSkel")
	UI:ColorPicker(vis.Page, "Pasek HP", "ESPColorHealth")

	-- ── WALLHACK ────────────────────────────────────────
	local wh = UI:Tab("Wallhack")
	UI:Section(wh.Page, "Wallhack")
	UI:Toggle(wh.Page, "Wallhack", "Wallhack", function(on)
		if on then Wallhack:Start() else Wallhack:Stop() end
	end)
	UI:Toggle(wh.Page, "Gracze", "WallhackPlayers")
	UI:Toggle(wh.Page, "Boty / NPC", "WallhackBots")
	UI:Toggle(wh.Page, "Obiekty", "WallhackObjects")
	UI:Slider(wh.Page, "Przezroczystość", "WallhackFill", 0, 1, 0.05, "")
	UI:ColorPicker(wh.Page, "Kolor", "WallhackColor")

	-- ── HITBOX ──────────────────────────────────────────
	local hb = UI:Tab("Hitbox")
	UI:Section(hb.Page, "Hitbox Editor")
	UI:Toggle(hb.Page, "Hitbox Editor", "Hitbox", function(on)
		Hitbox:RefreshAll()
		if on then Config.Set("HitboxPreview", true) end
	end)
	UI:Slider(hb.Page, "Szerokość", "HitboxWidth", 0.5, 20, 0.5, "", function()
		Hitbox:RefreshAll()
	end)
	UI:Slider(hb.Page, "Wysokość", "HitboxHeight", 0.5, 20, 0.5, "", function()
		Hitbox:RefreshAll()
	end)
	UI:Toggle(hb.Page, "Podgląd hitboxów", "HitboxPreview")
	UI:Button(hb.Page, "Przywróć domyślne", function()
		Config.Set("HitboxWidth", 4)
		Config.Set("HitboxHeight", 6)
		Config.Set("Hitbox", false)
		Hitbox:RefreshAll()
	end)

	-- ── CONFIG ──────────────────────────────────────────
	local cfgTab = UI:Tab("Config")
	UI:Section(cfgTab.Page, "Konfiguracja")
	UI:Button(cfgTab.Page, "Zapisz ustawienia", function()
		Config.Save()
	end)
	UI:Button(cfgTab.Page, "Wczytaj ustawienia", function()
		local d = Storage.Load()
		if not d then return end
		for k, v in pairs(d) do
			if DEFAULTS[k] ~= nil then Config.Set(k, v) end
		end
		Hitbox:RefreshAll()
	end)
	UI:Button(cfgTab.Page, "Reset ustawień", function()
		Config.Reset()
		Hitbox:RefreshAll()
	end, true)
	UI:Section(cfgTab.Page, "Narzędzia")
	UI:Button(cfgTab.Page, "Odśwież hitboxy", function()
		Hitbox:RefreshAll()
	end)

	-- ── INFO ────────────────────────────────────────────
	local info = UI:Tab("Info")
	UI:Section(info.Page, "CHEŁMSKI SIEKATOR V4")
	UI:Label(info.Page, "Wersja " .. CS.Version, true)
	UI:Label(info.Page, "Skróty:", true)
	UI:Label(info.Page, "• RIGHT SHIFT — pokaż / ukryj GUI")
	UI:Label(info.Page, "• END — wyładuj skrypt")
	UI:Label(info.Page, "Silent Aim wymaga włączonego przełącznika w zakładce Aim.")
	UI:Label(info.Page, "Hitbox działa po stronie klienta — gry oparte na raycastach klienta zarejestrują trafienia.")

	UI:Select(UI.Tabs[1])
end

--==========================================================
-- BOOTSTRAP
--==========================================================
function CS:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.Alive = false
	CS.Signal.Unload:Fire()

	Config.Save()

	for _, conn in ipairs(self.Connections) do
		pcall(function() conn:Disconnect() end)
	end
	self.Connections = {}

	pcall(function() Aimbot:Stop() end)
	pcall(function() ESP:Stop() end)
	pcall(function() Wallhack:Stop() end)

	for _, d in pairs(Overlay) do
		if typeof(d) == "Instance" and d.Remove then pcall(d.Remove, d) end
	end
	for _, d in pairs(Hitbox.PreviewDrawings) do pcall(d.Remove, d) end

	if self.UI and self.UI.Gui then
		pcall(function() self.UI.Gui:Destroy() end)
	end
	getgenv().CHELMSKI_V4 = nil
end

function CS:Start()
	Overlay:Init()
	Hitbox:Init()
	SilentAim:InstallHook()
	buildUI()

	if Config.Get("ESP") then ESP:Start() end
	if Config.Get("Aimbot") then Aimbot:Start() end
	if Config.Get("Wallhack") then Wallhack:Start() end

	-- pętla logiki
	Util.Track(RunService.RenderStepped:Connect(function()
		if not self.Alive then return end
		pcall(SilentAim.Update, SilentAim)
		pcall(Overlay.Update, Overlay)
	end))

	Util.Track(task.spawn(function()
		while self.Alive do
			pcall(Hitbox.DrawPreview, Hitbox)
			task.wait(0.1)
		end
	end))

	-- keybindy
	Util.Track(UserInput.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			UI:ToggleOpen()
		elseif input.KeyCode == Enum.KeyCode.End then
			CS:Destroy()
		end
	end))

	-- persystencja przy wyjściu
	Util.Track(game:BindToClose(function()
		Config.Save()
	end))
end

getgenv().CHELMSKI_V4 = CS
CS:Start()

return CS
