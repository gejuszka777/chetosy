--[[
	CHEŁMSKI SIEKATOR V8
	loadstring(game:HttpGet("https://raw.githubusercontent.com/gejuszka777/chetosy/main/chetosy.lua?v=8"))()
	Ugotowane przez Pstryczka
]]

local getgenv = getgenv or function() return _G end
local newcclosure = newcclosure or function(f) return f end
local getrawmetatable = getrawmetatable
local setreadonly = setreadonly
local hookmetamethod = hookmetamethod
local writefile, readfile = writefile, readfile

if type(getgenv().CHELMSKI) == "table" then
	pcall(function() getgenv().CHELMSKI:Destroy() end)
end

--==========================================================
-- 0. SERWISY
--==========================================================
local function svc(name)
	local ok, s = pcall(game.GetService, game, name)
	if ok then return s end
	return nil
end

local Players    = svc("Players")
local RunService = svc("RunService")
local Tween      = svc("TweenService")
local Input      = svc("UserInputService")
local Http       = svc("HttpService")
local Workspace  = svc("Workspace")
local Lighting   = svc("Lighting")
local CoreGui    = svc("CoreGui")
local Stats      = svc("Stats")
local RS         = svc("ReplicatedStorage")
local VIM        = svc("VirtualInputManager")
local TCS        = svc("TextChatService")
local Clipboard  = setclipboard or toclipboard

local LP = Players and Players.LocalPlayer
local Camera = Workspace and Workspace.CurrentCamera
local Mouse = LP and LP:GetMouse()

local function gethuiSafe()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	if LP then
		local pg = LP:FindFirstChildOfClass("PlayerGui")
		if pg then return pg end
	end
	return CoreGui
end

--==========================================================
-- 1. PANEL BŁĘDU
--==========================================================
local function fatal(err)
	err = tostring(err)
	warn("[SIEKATOR FATAL] " .. err)
	local ok = pcall(function()
		local g = Instance.new("ScreenGui")
		g.Name = "SiekatorFatal"
		g.IgnoreGuiInset = true
		g.DisplayOrder = 1000000
		g.ResetOnSpawn = false
		g.Parent = gethuiSafe()

		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, 560, 0, 200)
		f.Position = UDim2.new(0.5, -280, 0, 40)
		f.BackgroundColor3 = Color3.fromRGB(30, 10, 12)
		f.BorderSizePixel = 0
		f.Parent = g
		U_Corner(f, 10)

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -24, 1, -24)
		t.Position = UDim2.new(0, 12, 0, 12)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Code
		t.TextSize = 12
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.TextColor3 = Color3.fromRGB(255, 140, 140)
		t.Text = "CHEŁMSKI SIEKATOR — BŁĄD STARTU\n\n" .. err:sub(1, 900)
		t.Parent = f
	end)
	if not ok then warn("[SIEKATOR] nie udało się narysować panelu błędu") end
end

local function U_Corner(i, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = i
	return c
end

--==========================================================
-- 2. STAN
--==========================================================
local CS = {
	Version = "8.0",
	Alive = true,
	Destroyed = false,
	Conns = {},
	FPS = 60,
	Ready = false,
	Log = {},
}
CS.__index = CS

function CS:Note(txt)
	table.insert(self.Log, os.date("%H:%M:%S") .. "  " .. tostring(txt))
	if #self.Log > 200 then table.remove(self.Log, 1) end
end

--==========================================================
-- 3. UTIL
--==========================================================
local U = {}

function U.New(cls, props, parent)
	local i = Instance.new(cls)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then pcall(function() i[k] = v end) end
	end
	if parent then i.Parent = parent end
	return i
end

function U.Try(cls, props, parent)
	local ok, i = pcall(U.New, cls, props, parent)
	if ok then return i end
	return nil
end

function U.Corner(i, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = i
	return c
end

function U.Stroke(i, col, t, tr)
	local s = Instance.new("UIStroke")
	s.Color = col or Color3.new(1, 1, 1)
	s.Thickness = t or 1
	s.Transparency = tr or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = i
	return s
end

function U.Grad(i, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = i
	return g
end

function U.Tween(i, t, props, style, dir)
	if not i then return end
	local ok = pcall(function()
		local tw = Tween:Create(i, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
		tw:Play()
	end)
	if not ok then
		for k, v in pairs(props) do pcall(function() i[k] = v end) end
	end
end

function U.Round(n, s)
	if not s or s <= 0 then return n end
	return math.floor(n / s + 0.5) * s
end

function U.Alive(ch)
	if not ch then return false end
	local h = ch:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

function U.Track(c) table.insert(CS.Conns, c) return c end

function U.Col(t)
	if type(t) ~= "table" then return Color3.fromRGB(61, 255, 158) end
	return Color3.fromRGB(t[1] or 61, t[2] or 255, t[3] or 158)
end

function U.Hue(h) return Color3.fromHSV(h % 1, 0.7, 1) end
function U.Clamp(n, a, b) if n < a then return a elseif n > b then return b end return n end
function U.Dist(a, b) return (a - b).Magnitude end

--==========================================================
-- 4. SIGNAL
--==========================================================
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _h = {} }, Signal) end
function Signal:Connect(fn)
	table.insert(self._h, fn)
	return { Disconnect = function()
		local i = table.find(self._h, fn)
		if i then table.remove(self._h, i) end
	end }
end
function Signal:Fire(...)
	for _, fn in ipairs(table.clone(self._h)) do task.spawn(fn, ...) end
end
CS.Signal = { Changed = Signal.new(), Unload = Signal.new() }

--==========================================================
-- 5. STORAGE
--==========================================================
local FILE = "ChelmskiSiekatorV8.json"
local Store = {}

function Store.SaveTo(name, d)
	local fn = name or FILE
	if not writefile then getgenv().CHELMSKI_CFG = d return end
	local ok, e = pcall(function() return Http:JSONEncode(d) end)
	if ok then pcall(writefile, fn, e) end
end

function Store.LoadFrom(name)
	local fn = name or FILE
	if readfile then
		local ok, raw = pcall(readfile, fn)
		if ok and raw and raw ~= "" then
			local ok2, d = pcall(function() return Http:JSONDecode(raw) end)
			if ok2 and type(d) == "table" then return d end
		end
	end
	if not name then return getgenv().CHELMSKI_CFG end
	return nil
end

function Store.Save(d) Store.SaveTo(FILE, d) end
function Store.Load() return Store.LoadFrom(nil) end

--==========================================================
-- 6. CONFIG
--==========================================================
local DEF = {
	SilentAim = false, SilentFOV = 150, SilentRange = 900, SilentPart = "Head",
	SilentChance = 100, SilentVisible = false, SilentHold = false, SilentViz = true,
	SilentPredict = 0, SilentPriority = "FOV", FovMode = "Ekran", LockRing = true,
	CircleOn = true, CircleStyle = "Cienkie", ColorCircle = { 61, 255, 158 },
	TriggerBot = false, TriggerDelay = 0.05,
	Aimbot = false, AimbotMode = "Hold", AimbotSmooth = 0.18, AimbotStyle = "Wykładniczy",
	AimbotFOV = 120, AimbotRange = 900, AimbotPart = "Head", AimbotVisible = true,
	AimbotHumanize = 0.15, AimbotSticky = true, AimbotPredict = 0,
	ESP = false, ESPBox = true, ESPBoxStyle = "Pełny", ESPGradient = true, ESPSkeleton = true,
	ESPName = true, ESPDistance = true, ESPHealth = true, ESPHealthText = false,
	ESPHealthColor = true, ESPTracer = false, ESPHeadDot = false, ESPArrows = true,
	ESPAlpha = 0.9, ESPMaxDist = 1500, ESPTeamCheck = true, ESPRainbow = false,
	ESPChams = false, ESPTextScale = 1, ESPTargetRing = true,
	ColorEnemy = { 61, 255, 158 }, ColorTeam = { 90, 170, 255 },
	ColorSkel = { 255, 255, 255 }, ColorTracer = { 61, 255, 158 },
	Wallhack = false, WHPlayers = true, WHBots = true, WHObjects = false,
	WHFill = 0.55, WHOutline = 0.1, WHDepth = "Zawsze", ColorWH = { 61, 255, 158 },
	Fullbright = false, NoFog = false, ClockTime = 14, Crosshair = false,
	CrosshairStyle = "Krzyż", ColorCross = { 61, 255, 158 }, CamFOV = 70,
	Hitbox = false, HitboxW = 4, HitboxH = 6, HitboxD = 4, HitboxHeadMul = 1,
	HitboxPreview = true,
	HitboxParts = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
	BigHead = false, Disco = false,
	PerfMode = false, AutoPerf = true, Friends = {}, ShowWM = true, ShowToast = true,
	UIScale = 1, ColorAccent = { 61, 255, 158 },
	UIKey = "RightShift", AimKey = "E", AimbotKey = "X", UnloadKey = "Delete",
	ExportStr = "", WinX = 0, WinY = 0, WinW = 680, WinH = 470, WinSet = false,
}

local Cfg, data = {}, {}
for k, v in pairs(DEF) do data[k] = type(v) == "table" and table.clone(v) or v end

do
	local s = Store.Load()
	if type(s) == "table" then
		for k, v in pairs(s) do
			if DEF[k] ~= nil and type(v) == type(DEF[k]) then data[k] = v end
		end
	end
end

function Cfg.Get(k) return data[k] end
function Cfg.Set(k, v)
	data[k] = v
	CS.Signal.Changed:Fire(k, v)
end
function Cfg.Reset()
	for k, v in pairs(DEF) do data[k] = type(v) == "table" and table.clone(v) or v end
	CS.Signal.Changed:Fire("__all__", nil)
end
function Cfg.Save() Store.Save(data) end
function Cfg.Apply(t)
	for k, v in pairs(t) do
		if DEF[k] ~= nil and type(v) == type(DEF[k]) then data[k] = v end
	end
	CS.Signal.Changed:Fire("__all__", nil)
end
CS.Cfg = Cfg

--==========================================================
-- 7. DRAW
--==========================================================
local Draw = { Has = false, Layer = nil, Pool = {} }

pcall(function()
	Draw.Has = type(Drawing) == "table" and type(Drawing.new) == "function"
	local p = Drawing.new("Square")
	p:Remove()
end)

local function apply(o, k, v)
	local i = o.Inst
	if not i then o.Props[k] = v return end
	if k == "Visible" then i.Visible = v
	elseif k == "Position" then
		if typeof(v) == "Vector2" then i.Position = UDim2.fromOffset(v.X, v.Y) end
	elseif k == "Size" then
		if type(v) == "number" then
			if o.Kind == "Text" then i.TextSize = v else i.Size = UDim2.fromOffset(v, v) end
		elseif v then
			i.Size = UDim2.fromOffset(math.max(v.X, 0), math.max(v.Y, 0))
		end
	elseif k == "Color" then
		if o.Kind == "Text" then i.TextColor3 = v else i.BackgroundColor3 = v end
		if o.Stroke then o.Stroke.Color = v end
	elseif k == "Transparency" then
		if o.Kind == "Text" then i.TextTransparency = v else i.BackgroundTransparency = v end
		if o.Stroke then o.Stroke.Transparency = v end
	elseif k == "Filled" then
		if o.Kind ~= "Text" then
			i.BackgroundTransparency = v and 0.35 or 1
			if o.Stroke then o.Stroke.Transparency = v and 1 or 0 end
		end
	elseif k == "Thickness" then
		if o.Stroke then o.Stroke.Thickness = v end
	elseif k == "Text" then i.Text = v
	elseif k == "Center" then
		i.TextXAlignment = v and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	elseif k == "Outline" then
		i.TextStrokeTransparency = v and 0 or 1
	elseif k == "Radius" then
		local p = o.Props.Position or Vector2.new()
		i.Position = UDim2.fromOffset(p.X - v, p.Y - v)
		i.Size = UDim2.fromOffset(v * 2, v * 2)
	elseif k == "From" or k == "To" then
		local f = o.Props.From or Vector2.new()
		local t = o.Props.To or Vector2.new()
		if k == "From" then f = v else t = v end
		local d = t - f
		i.Position = UDim2.fromOffset(f.X, f.Y)
		i.Size = UDim2.fromOffset(math.max(d.Magnitude, 0), o.Props.Thickness or 1)
		i.Rotation = math.deg(math.atan2(d.Y, d.X))
	end
	o.Props[k] = v
end

local MT = {
	__index = function(t, k)
		if k == "Remove" then
			return function(self)
				if self.Inst then pcall(function() self.Inst:Destroy() end) end
				self.Inst = nil
			end
		end
		return rawget(t, "Props")[k]
	end,
	__newindex = function(t, k, v)
		if rawget(t, "Inst") then apply(t, k, v) else rawget(t, "Props")[k] = v end
	end,
}

local function frameObject(kind)
	local o = { Kind = kind, Props = {}, Inst = nil }
	local i
	if kind == "Text" then
		i = Instance.new("TextLabel")
		i.BackgroundTransparency = 1
		i.Font = Enum.Font.GothamBold
		i.TextSize = 13
		i.Text = ""
		i.Size = UDim2.fromOffset(240, 16)
		i.AnchorPoint = Vector2.new(0.5, 0)
		i.TextXAlignment = Enum.TextXAlignment.Center
		i.TextStrokeTransparency = 0
		i.TextStrokeColor3 = Color3.new(0, 0, 0)
	elseif kind == "Line" then
		i = Instance.new("Frame")
		i.BorderSizePixel = 0
		i.AnchorPoint = Vector2.new(0, 0.5)
	else
		i = Instance.new("Frame")
		i.BorderSizePixel = 0
		i.BackgroundTransparency = 1
		if kind == "Square" then
			o.Stroke = U.Stroke(i, Color3.new(1, 1, 1), 1, 0)
		elseif kind == "Circle" then
			U.Corner(i, 999)
			o.Stroke = U.Stroke(i, Color3.new(1, 1, 1), 1, 0)
		end
	end
	i.Visible = false
	if Draw.Layer then i.Parent = Draw.Layer end
	o.Inst = i
	return setmetatable(o, MT)
end

function Draw.Init()
	if Draw.Layer then return end
	local g = Instance.new("ScreenGui")
	g.Name = "ChelmskiSiekatorV8_Draw"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 9990
	local ok = pcall(function() g.Parent = gethuiSafe() end)
	if not ok or not g.Parent then
		pcall(function() g.Parent = LP:WaitForChild("PlayerGui") end)
	end
	Draw.Layer = g
end

function Draw.New(kind, props, noPool)
	local o
	if Draw.Has then
		local ok, d = pcall(Drawing.new, kind)
		if ok and d then o = d end
	end
	if not o then
		Draw.Init()
		o = frameObject(kind)
	end
	for k, v in pairs(props or {}) do o[k] = v end
	if not noPool then table.insert(Draw.Pool, o) end
	return o
end

function Draw.Purge()
	for _, o in ipairs(Draw.Pool) do pcall(function() o:Remove() end) end
	Draw.Pool = {}
end

--==========================================================
-- 8. TARGETING
--==========================================================
local T = {}
local CHAIN = {
	Head = { "Head" },
	HumanoidRootPart = { "HumanoidRootPart" },
	UpperTorso = { "UpperTorso", "Torso", "HumanoidRootPart" },
	Blisko = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
}

function T.Part(ch, mode)
	if not ch or not Camera then return nil end
	if mode == "Blisko" then
		local b, bd, cp = nil, nil, Camera.CFrame.Position
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("BasePart") then
				local x = (d.Position - cp).Magnitude
				if not bd or x < bd then b, bd = d, x end
			end
		end
		return b
	end
	for _, n in ipairs(CHAIN[mode] or CHAIN.Head) do
		local p = ch:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
	return nil
end

function T.AimPoint(part, predict)
	if not part then return nil end
	if predict and predict > 0 then
		local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
		if ok and v then return part.Position + v * predict end
	end
	return part.Position
end

local rp = RaycastParams.new()
pcall(function() rp.FilterType = Enum.RaycastFilterType.Exclude end)

function T.Visible(part)
	if not part or not Camera or not Workspace then return false end
	local f = {}
	if LP and LP.Character then table.insert(f, LP.Character) end
	if part.Parent then table.insert(f, part.Parent) end
	rp.FilterDescendantsInstances = f
	local hit = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
	return hit == nil or hit.Instance:IsDescendantOf(part.Parent)
end

function T.Friend(p) return table.find(Cfg.Get("Friends"), p.UserId) ~= nil end

function T.Score(kind, fovDist, dist, hum)
	if kind == "Dystans" then return dist end
	if kind == "Zdrowie" then return hum and hum.Health or 0 end
	return fovDist + dist * 0.04
end

function T.Angle(from, to)
	local a = (to - from).Unit
	local b = Camera.CFrame.LookVector
	local d = U.Clamp(a:Dot(b), -1, 1)
	return math.deg(math.acos(d))
end

function T.Best(o)
	if not Players or not Camera or not LP then return nil end
	local best, bs
	local cp = Camera.CFrame.Position
	local vp = Camera.ViewportSize
	local mid = Vector2.new(vp.X / 2, vp.Y / 2)
	local myTeam = LP.Team
	local mode3d = Cfg.Get("FovMode") == "3D"
	local degLimit = o.fov / 4

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local ch = p.Character
			if U.Alive(ch) and not (o.teamCheck and p.Team == myTeam) and not T.Friend(p) then
				local part = T.Part(ch, o.part)
				if part then
					local dist = (part.Position - cp).Magnitude
					if dist <= o.range then
						local s, on = Camera:WorldToViewportPoint(part.Position)
						local fd
						if mode3d then
							fd = T.Angle(cp, part.Position)
							if fd > degLimit then fd = nil end
						elseif on and s.Z > 0 then
							local d2 = (Vector2.new(s.X, s.Y) - mid).Magnitude
							fd = d2 <= o.fov and d2 or nil
						end
						if fd then
							local sc = T.Score(o.priority, fd, dist, ch:FindFirstChildOfClass("Humanoid"))
							if o.visible and not T.Visible(part) then sc += 400 end
							if not bs or sc < bs then
								best, bs = { Player = p, Part = part, Dist = dist }, sc
							end
						end
					end
				end
			end
		end
	end
	return best
end

--==========================================================
-- 9. SILENT AIM
--==========================================================
local SA = { Target = nil, Busy = false, Hooked = false, Rolled = false, KeyDown = false }

function SA:Update()
	if not Cfg.Get("SilentAim") or (Cfg.Get("SilentHold") and not self.KeyDown) then
		self.Target = nil
		return
	end
	local t = T.Best({
		fov = Cfg.Get("SilentFOV"), range = Cfg.Get("SilentRange"), part = Cfg.Get("SilentPart"),
		visible = Cfg.Get("SilentVisible"), teamCheck = Cfg.Get("ESPTeamCheck"),
		priority = Cfg.Get("SilentPriority"),
	})
	if t then
		if not self.Rolled then self.Rolled = math.random(1, 100) <= Cfg.Get("SilentChance") end
		if not self.Rolled then t = nil end
	end else self.Rolled = false end
	self.Target = t
end

function SA:Handler(raw)
	return newcclosure(function(self, key)
		local t = SA.Target
		if t and t.Part and t.Part.Parent and not SA.Busy and Camera then
			local aim = T.AimPoint(t.Part, Cfg.Get("SilentPredict")) or t.Part.Position
			if self == Mouse then
				if key == "Hit" then return CFrame.new(aim)
				elseif key == "Target" then return t.Part.Parent
				elseif key == "UnitRay" then
					local o = raw(Camera, "CFrame").Position
					return Ray.new(o, (aim - o).Unit * 2048)
				end
			elseif self == Camera and key == "CFrame" then
				local b = raw(Camera, "CFrame")
				return CFrame.lookAt(b.Position, aim)
			end
		end
		return raw(self, key)
	end)
end

function SA:Install()
	if self.Hooked then return true end
	local mt = getrawmetatable and getrawmetatable(game) or nil
	if mt and setreadonly then
		local ok = pcall(function()
			local old = mt.__index
			setreadonly(mt, false)
			mt.__index = SA:Handler(old)
			setreadonly(mt, true)
		end)
		if ok then
			self.Hooked = true
			CS:Note("hook: getrawmetatable OK")
			return true
		end
	end
	if hookmetamethod then
		local ok = pcall(function()
			local old
			old = hookmetamethod(game, "__index", SA:Handler(function(s, k) return old(s, k) end))
		end)
		if ok then
			self.Hooked = true
			CS:Note("hook: hookmetamethod OK")
			return true
		end
	end
	CS:Note("hook: BRAK — tryb kamerowy")
	return false
end

--==========================================================
-- 10. AIMBOT
--==========================================================
local AB = { Conn = nil, Target = nil, KeyDown = false, Jit = Vector2.new(), Sticky = nil, StickyAt = 0 }

function AB:Pick()
	local cfg = {
		fov = Cfg.Get("AimbotFOV"), range = Cfg.Get("AimbotRange"), part = Cfg.Get("AimbotPart"),
		visible = Cfg.Get("AimbotVisible"), teamCheck = Cfg.Get("ESPTeamCheck"),
		priority = Cfg.Get("SilentPriority"),
	}
	if Cfg.Get("AimbotSticky") and self.Sticky and os.clock() - self.StickyAt < 1.2 then
		local p = self.Sticky
		local ch = p.Character
		if U.Alive(ch) and Camera then
			local part = T.Part(ch, Cfg.Get("AimbotPart"))
			if part then
				local s, on = Camera:WorldToViewportPoint(part.Position)
				local vp = Camera.ViewportSize
				if on then
					local fd = (Vector2.new(s.X, s.Y) - Vector2.new(vp.X / 2, vp.Y / 2)).Magnitude
					if fd <= Cfg.Get("AimbotFOV") * 1.6 then
						return { Player = p, Part = part }
					end
				end
			end
		end
		self.Sticky = nil
	end
	local t = T.Best(cfg)
	if t and Cfg.Get("AimbotSticky") then
		self.Sticky = t.Player
		self.StickyAt = os.clock()
	end
	return t
end

function AB:Step(dt)
	if not Camera then return end
	if not Cfg.Get("Aimbot") or (Cfg.Get("AimbotMode") == "Hold" and not self.KeyDown) then
		self.Target = nil
		return
	end
	local t = self:Pick()
	self.Target = t
	if not t then return end

	local aim = T.AimPoint(t.Part, Cfg.Get("AimbotPredict")) or t.Part.Position
	local hum = Cfg.Get("AimbotHumanize")
	if hum > 0 and math.random() < 0.15 then
		local a = math.random() * math.pi * 2
		self.Jit = Vector2.new(math.cos(a), math.sin(a)) * hum
	end

	local goal = CFrame.lookAt(Camera.CFrame.Position, aim)
		* CFrame.Angles(math.rad(self.Jit.Y * 0.4), math.rad(self.Jit.X * 0.4), 0)

	local sm = U.Clamp(Cfg.Get("AimbotSmooth"), 0.005, 1)
	local a
	if Cfg.Get("AimbotStyle") == "Liniowy" then a = U.Clamp(dt / sm, 0, 1)
	elseif Cfg.Get("AimbotStyle") == "Snap" then a = 1
	else a = 1 - math.exp(-dt / sm * 6) end

	SA.Busy = true
	Camera.CFrame = Camera.CFrame:Lerp(goal, a)
	SA.Busy = false
end

function AB:Start()
	if self.Conn then return end
	self.Conn = U.Track(RunService.RenderStepped:Connect(function(dt)
		pcall(AB.Step, AB, dt)
	end))
end

function AB:Stop()
	if self.Conn then self.Conn:Disconnect() self.Conn = nil end
	self.Target = nil
end

--==========================================================
-- 11. TRIGGER BOT
--==========================================================
local TG = { Conn = nil, Last = 0 }

function TG:Fire()
	if not VIM then return end
	if os.clock() - self.Last < Cfg.Get("TriggerDelay") then return end
	self.Last = os.clock()
	pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
	task.delay(0.02, function()
		pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
	end)
end

function TG:Start()
	if self.Conn then return end
	self.Conn = U.Track(RunService.RenderStepped:Connect(function()
		if not Cfg.Get("TriggerBot") then return end
		local t = SA.Target or AB.Target
		if t and t.Part and T.Visible(t.Part) then pcall(TG.Fire, TG) end
	end))
end

function TG:Stop()
	if self.Conn then self.Conn:Disconnect() self.Conn = nil end
end

--==========================================================
-- 12. ESP
--==========================================================
local ESP = { Pool = {}, Conn = nil, Acc = 0, Hz = 0 }

local R15 = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "LowerTorso", "HumanoidRootPart" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6 = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

function ESP:Entry(p)
	local e = {
		Box = Draw.New("Square", { Filled = false, Thickness = 1 }),
		Fill = Draw.New("Square", { Filled = true, Thickness = 0 }),
		Name = Draw.New("Text", { Center = true, Outline = true, Size = 14 }),
		Dist = Draw.New("Text", { Center = true, Outline = true, Size = 13 }),
		HpBg = Draw.New("Square", { Filled = true, Thickness = 0 }),
		HpFg = Draw.New("Square", { Filled = true, Thickness = 0 }),
		HpTx = Draw.New("Text", { Center = true, Outline = true, Size = 11 }),
		Dot = Draw.New("Circle", { Thickness = 2, Filled = true }),
		Tracer = Draw.New("Line", { Thickness = 1 }),
		Arrow = Draw.New("Square", { Filled = true, Thickness = 0 }),
		C = {}, Bones = {},
	}
	for i = 1, 8 do e.C[i] = Draw.New("Line", { Thickness = 2 }) end
	self.Pool[p] = e
	return e
end

function ESP:Drop(p)
	local e = self.Pool[p]
	if not e then return end
	for k, v in pairs(e) do
		if k == "C" or k == "Bones" then
			for _, o in ipairs(v) do pcall(function() o:Remove() end) end
		else pcall(function() v:Remove() end) end
	end
	self.Pool[p] = nil
end

function ESP:Hide(e)
	for _, k in ipairs({ "Box", "Fill", "Name", "Dist", "HpBg", "HpFg", "HpTx", "Dot", "Tracer", "Arrow" }) do
		e[k].Visible = false
	end
	for _, l in ipairs(e.C) do l.Visible = false end
	for _, l in ipairs(e.Bones) do l.Visible = false end
end

function ESP:Draw(p)
	if not Camera then return end
	local ch = p.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local head = ch and ch:FindFirstChild("Head")
	local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))

	local on = Cfg.Get("ESP") and U.Alive(ch) and head and root
	if on and Cfg.Get("ESPTeamCheck") and LP and p.Team == LP.Team then on = false end
	if on and (root.Position - Camera.CFrame.Position).Magnitude > Cfg.Get("ESPMaxDist") then on = false end

	local e = self.Pool[p]
	if not on then if e then self:Hide(e) end return end
	e = e or self:Entry(p)

	local hs, ho = Camera:WorldToViewportPoint(head.Position)
	local rs, ro = Camera:WorldToViewportPoint(root.Position)
	if not ho or not ro or hs.Z <= 0 then self:Hide(e) return end

	local tr = 1 - Cfg.Get("ESPAlpha")
	local scale = Cfg.Get("ESPTextScale")
	local col
	if Cfg.Get("ESPRainbow") then col = U.Hue(os.clock() * 0.35 + (p.UserId % 100) / 100)
	elseif T.Friend(p) then col = Color3.fromRGB(255, 210, 60)
	elseif LP and p.Team == LP.Team then col = U.Col(Cfg.Get("ColorTeam"))
	else col = U.Col(Cfg.Get("ColorEnemy")) end

	local h = math.abs(rs.Y - hs.Y) * 2.2
	local w = h * 0.55
	local top = Vector2.new(hs.X, hs.Y - h * 0.25)
	local tl = top - Vector2.new(w / 2, 0)
	local br = tl + Vector2.new(w, h)
	local style = Cfg.Get("ESPBoxStyle")
	local box = Cfg.Get("ESPBox")

	e.Box.Visible = box and style == "Pełny"
	e.Box.Color = col
	e.Box.Transparency = tr
	e.Box.Size = Vector2.new(w, h)
	e.Box.Position = tl

	e.Fill.Visible = box and style == "Wypełniony"
	e.Fill.Color = col
	e.Fill.Transparency = tr + 0.35
	e.Fill.Size = Vector2.new(w, h)
	e.Fill.Position = tl

	local corner = box and style == "Narożniki"
	local cl = math.min(w, h) * 0.22
	local segs = {
		{ tl, tl + Vector2.new(cl, 0) }, { tl, tl + Vector2.new(0, cl) },
		{ Vector2.new(br.X, tl.Y), Vector2.new(br.X - cl, tl.Y) },
		{ Vector2.new(br.X, tl.Y), Vector2.new(br.X, tl.Y + cl) },
		{ Vector2.new(tl.X, br.Y), Vector2.new(tl.X + cl, br.Y) },
		{ Vector2.new(tl.X, br.Y), Vector2.new(tl.X, br.Y - cl) },
		{ br, br - Vector2.new(cl, 0) }, { br, br - Vector2.new(0, cl) },
	}
	for i, l in ipairs(e.C) do
		l.Visible = corner
		if corner then
			l.Color = col
			l.Transparency = tr
			l.From = segs[i][1]
			l.To = segs[i][2]
		end
	end

	local nameCol = col
	if Cfg.Get("ESPHealthColor") and hum then
		local pct = U.Clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		nameCol = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 80)
	end

	e.Name.Visible = Cfg.Get("ESPName")
	e.Name.Color = nameCol
	e.Name.Transparency = tr
	e.Name.Size = math.floor(14 * scale)
	e.Name.Text = T.Friend(p) and ("★ " .. p.DisplayName) or p.DisplayName
	e.Name.Position = top - Vector2.new(0, 18)

	e.Dist.Visible = Cfg.Get("ESPDistance")
	e.Dist.Color = col
	e.Dist.Transparency = tr
	e.Dist.Size = math.floor(13 * scale)
	e.Dist.Text = string.format("%d m", math.floor((root.Position - Camera.CFrame.Position).Magnitude / 3))
	e.Dist.Position = br + Vector2.new(0, 2)

	if Cfg.Get("ESPHealth") and hum then
		local pct = U.Clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		e.HpBg.Visible = true
		e.HpBg.Color = Color3.fromRGB(14, 18, 22)
		e.HpBg.Transparency = tr
		e.HpBg.Size = Vector2.new(3, h)
		e.HpBg.Position = tl - Vector2.new(6, 0)
		e.HpFg.Visible = true
		e.HpFg.Color = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 70)
		e.HpFg.Transparency = tr
		e.HpFg.Size = Vector2.new(3, h * pct)
		e.HpFg.Position = tl - Vector2.new(6, 0) + Vector2.new(0, h * (1 - pct))
		e.HpTx.Visible = Cfg.Get("ESPHealthText")
		e.HpTx.Color = col
		e.HpTx.Transparency = tr
		e.HpTx.Size = math.floor(11 * scale)
		e.HpTx.Text = tostring(math.floor(hum.Health))
		e.HpTx.Position = tl - Vector2.new(20, 0)
	else
		e.HpBg.Visible = false
		e.HpFg.Visible = false
		e.HpTx.Visible = false
	end

	e.Dot.Visible = Cfg.Get("ESPHeadDot")
	e.Dot.Color = col
	e.Dot.Radius = 3
	e.Dot.Position = Vector2.new(hs.X, hs.Y)

	e.Tracer.Visible = Cfg.Get("ESPTracer")
	e.Tracer.Color = U.Col(Cfg.Get("ColorTracer"))
	e.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
	e.Tracer.To = Vector2.new(hs.X, br.Y)

	local vp = Camera.ViewportSize
	local arrow = Cfg.Get("ESPArrows") and (hs.X < 0 or hs.X > vp.X or hs.Y < 0 or hs.Y > vp.Y)
	e.Arrow.Visible = arrow
	if arrow then
		local c = Vector2.new(vp.X / 2, vp.Y / 2)
		local d = Vector2.new(hs.X, hs.Y) - c
		if d.Magnitude < 1 then d = Vector2.new(0, -1) end
		local pos = c + d.Unit * math.min(vp.X, vp.Y) * 0.38
		e.Arrow.Color = col
		e.Arrow.Size = Vector2.new(9, 9)
		e.Arrow.Position = pos - Vector2.new(4.5, 4.5)
	end

	local bones = hum.RigType == Enum.HumanoidRigType.R15 and R15 or R6
	local sk = Cfg.Get("ESPSkeleton")
	local sc = U.Col(Cfg.Get("ColorSkel"))
	for i, pr in ipairs(bones) do
		local l = e.Bones[i]
		if not l then
			l = Draw.New("Line", { Thickness = 1 })
			e.Bones[i] = l
		end
		local a = ch:FindFirstChild(pr[1])
		local b = ch:FindFirstChild(pr[2])
		if sk and a and b then
			local sa, oa = Camera:WorldToViewportPoint(a.Position)
			local sb, ob = Camera:WorldToViewportPoint(b.Position)
			if oa and ob then
				l.Visible = true
				l.Color = sc
				l.Transparency = tr
				l.From = Vector2.new(sa.X, sa.Y)
				l.To = Vector2.new(sb.X, sb.Y)
			else l.Visible = false end
		else l.Visible = false end
	end
end

function ESP:Step(dt)
	if not Players then return end
	local hz = 1 / 60
	if Cfg.Get("PerfMode") then
		hz = 1 / 40
	elseif Cfg.Get("AutoPerf") and CS.FPS < 30 then
		hz = 1 / 20
	end
	self.Acc += dt
	if self.Acc < hz then return end
	self.Acc = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then pcall(ESP.Draw, ESP, p) end
	end
end

function ESP:Start()
	if self.Conn then return end
	self.Conn = U.Track(RunService.RenderStepped:Connect(function(dt)
		pcall(ESP.Step, ESP, dt)
	end))
end

function ESP:Stop()
	if self.Conn then self.Conn:Disconnect() self.Conn = nil end
	for p in pairs(self.Pool) do self:Drop(p) end
end

--==========================================================
-- 13. CHAMS
--==========================================================
local Chams = { Pool = {} }

function Chams:Clear()
	for _, h in pairs(self.Pool) do pcall(function() h:Destroy() end) end
	self.Pool = {}
end

function Chams:Step()
	if not Players then return end
	if not (Cfg.Get("ESP") and Cfg.Get("ESPChams")) then
		if next(self.Pool) then self:Clear() end
		return
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character and not self.Pool[p.Character] then
			local h = Instance.new("Highlight")
			h.Adornee = p.Character
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillColor = U.Col(Cfg.Get("ColorEnemy"))
			h.FillTransparency = 0.65
			h.OutlineColor = U.Col(Cfg.Get("ColorEnemy"))
			h.Parent = p.Character
			self.Pool[p.Character] = h
		end
	end
end

--==========================================================
-- 14. WORLD
--==========================================================
local World = { Pool = {}, Loop = nil }

function World:HL(inst, col, fill, out, depth)
	if self.Pool[inst] then return end
	local h = Instance.new("Highlight")
	h.Adornee = inst
	h.DepthMode = depth
	h.FillColor = col
	h.FillTransparency = fill
	h.OutlineColor = col
	h.OutlineTransparency = out
	h.Parent = inst
	self.Pool[inst] = h
end

function World:ClearHL()
	for _, h in pairs(self.Pool) do pcall(function() h:Destroy() end) end
	self.Pool = {}
end

function World:Step()
	if not Players or not Workspace then return end
	if not Cfg.Get("Wallhack") then
		if next(self.Pool) then self:ClearHL() end
		return
	end
	local col = Cfg.Get("ESPRainbow") and U.Hue(os.clock() * 0.35) or U.Col(Cfg.Get("ColorWH"))
	local fill = Cfg.Get("WHFill")
	local out = Cfg.Get("WHOutline")
	local depth = Cfg.Get("WHDepth") == "Zawsze"
		and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded

	if Cfg.Get("WHPlayers") then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then self:HL(p.Character, col, fill, out, depth) end
		end
	end
	if Cfg.Get("WHBots") then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(d) then
				self:HL(d, col, fill, out, depth)
			end
		end
	end
	if Cfg.Get("WHObjects") then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Model") then
				self:HL(d, col, fill, out, depth)
			end
		end
	end
	for _, h in pairs(self.Pool) do
		h.FillTransparency = fill
		h.OutlineTransparency = out
		if Cfg.Get("ESPRainbow") then h.FillColor = col h.OutlineColor = col end
	end
end

function World:Light()
	if not Lighting then return end
	Lighting.Brightness = Cfg.Get("Fullbright") and 3 or 1
	Lighting.GlobalShadows = not Cfg.Get("Fullbright")
	pcall(function() Lighting.ClockTime = Cfg.Get("ClockTime") end)
	if Cfg.Get("NoFog") then
		Lighting.FogEnd = 100000
		Lighting.FogStart = 0
	end
end

function World:FOV()
	if Camera then pcall(function() Camera.FieldOfView = Cfg.Get("CamFOV") end) end
end

function World:Start()
	if self.Loop then return end
	self.Loop = U.Track(task.spawn(function()
		while CS.Alive do
			pcall(World.Step, World)
			task.wait(0.5)
		end
	end))
end

function World:Stop()
	if self.Loop then self.Loop:Disconnect() self.Loop = nil end
	self:ClearHL()
end

--==========================================================
-- 15. HITBOX
--==========================================================
local HB = { Orig = {}, Done = {}, Preview = {} }
local PARTS = { "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart",
	"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }

function HB:Apply(ch)
	if not ch or self.Done[ch] then return end
	self.Done[ch] = true
	local w, h, d = Cfg.Get("HitboxW"), Cfg.Get("HitboxH"), Cfg.Get("HitboxD")
	local mul = Cfg.Get("HitboxHeadMul")
	local sel = Cfg.Get("HitboxParts")
	for _, n in ipairs(PARTS) do
		if table.find(sel, n) then
			local p = ch:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				self.Orig[p] = self.Orig[p] or { Size = p.Size, Collide = p.CanCollide }
				local k = (n == "Head") and mul or 1
				p.Size = Vector3.new(w * k, h * k, d * k)
				p.CanCollide = false
			end
		end
	end
end

function HB:Restore(ch)
	if not ch then return end
	self.Done[ch] = nil
	for p, o in pairs(self.Orig) do
		if p and p.Parent and p:IsDescendantOf(ch) then
			p.Size = o.Size
			p.CanCollide = o.Collide
			self.Orig[p] = nil
		end
	end
end

function HB:Refresh()
	if not Players then return end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			if Cfg.Get("Hitbox") then self:Apply(p.Character) else self:Restore(p.Character) end
		end
	end
	if LP and LP.Character then
		if Cfg.Get("Hitbox") then self:Apply(LP.Character) else self:Restore(LP.Character) end
	end
end

function HB:PreviewStep()
	for _, d in ipairs(self.Preview) do pcall(function() d:Remove() end) end
	self.Preview = {}
	if not Cfg.Get("Hitbox") or not Cfg.Get("HitboxPreview") or not Camera then return end
	local col = Color3.fromRGB(61, 255, 158)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			for _, n in ipairs(Cfg.Get("HitboxParts")) do
				local part = p.Character:FindFirstChild(n)
				if part then
					local a, oa = Camera:WorldToViewportPoint(part.Position)
					local b, ob = Camera:WorldToViewportPoint(part.Position + Vector3.new(part.Size.X / 2, part.Size.Y / 2, 0))
					local c, oc = Camera:WorldToViewportPoint(part.Position - Vector3.new(part.Size.X / 2, part.Size.Y / 2, 0))
					if oa and ob and oc then
						local box = Draw.New("Square", { Thickness = 1, Filled = false, Color = col }, true)
						box.Size = Vector2.new(math.abs(b.X - c.X), math.abs(b.Y - c.Y))
						box.Position = Vector2.new(a.X - box.Size.X / 2, a.Y - box.Size.Y / 2)
						box.Visible = true
						table.insert(self.Preview, box)
					end
				end
			end
		end
	end
end

function HB:Init()
	if not Players then return end
	local function hook(p)
		p.CharacterAdded:Connect(function(ch)
			ch:WaitForChild("Humanoid", 10)
			task.wait(0.25)
			if Cfg.Get("Hitbox") then pcall(HB.Apply, HB, ch) end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do hook(p) end
	U.Track(Players.PlayerAdded:Connect(hook))
end

--==========================================================
-- 16. FUN
--==========================================================
local Fun = { Spin = false }

local LINES = {
	"gg ez", "ale wpierdol", "aim diff", "to był lag", "oddajcie hp",
	"siekator mode on", "l2p", "1v1?", "no i po co było", "siema cieniasy",
	"kręci się w głowie", "nie da się ze mną grać", "ugotowane przez pstryczka",
	"ser w kostkę", "pstryczek pozdrawia",
}

function Fun:Say(msg)
	pcall(function()
		local ev = RS and RS:FindFirstChild("DefaultChatSystemChatEvents")
		if ev then
			local req = ev:FindFirstChild("SayMessageRequest")
			if req then req:FireServer(msg, "All") end
		end
	end)
	pcall(function()
		if TCS and TCS.ChatInputBarConfiguration and TCS.ChatInputBarConfiguration.TargetTextChannel then
			TCS.ChatInputBarConfiguration.TargetTextChannel:SendAsync(msg)
		end
	end)
end

function Fun:Taunt() self:Say(LINES[math.random(1, #LINES)]) end

function Fun:BigHead(on)
	if not Players then return end
	for _, p in ipairs(Players:GetPlayers()) do
		local ch = p.Character
		local h = ch and ch:FindFirstChild("Head")
		if h and h:IsA("BasePart") then
			if on then
				if not h:GetAttribute("CS_H") then h:SetAttribute("CS_H", h.Size) end
				h.Size = h.Size * 2.2
			else
				local s = h:GetAttribute("CS_H")
				if typeof(s) == "Vector3" then h.Size = s end
			end
		end
	end
end

function Fun:Shake()
	if not Camera then return end
	local t0 = os.clock()
	local c = RunService.RenderStepped:Connect(function()
		if os.clock() - t0 > 0.7 then c:Disconnect() return end
		Camera.CFrame = Camera.CFrame * CFrame.new((math.random() - 0.5) * 0.9, (math.random() - 0.5) * 0.9, 0)
	end)
end

function Fun:Disco(on)
	Cfg.Set("Disco", on)
	if not Lighting then return end
	if not on then
		pcall(function()
			Lighting.Ambient = Color3.fromRGB(70, 70, 70)
			Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		end)
		return
	end
	task.spawn(function()
		while Cfg.Get("Disco") and CS.Alive do
			pcall(function()
				Lighting.Ambient = U.Hue(os.clock() * 0.9)
				Lighting.OutdoorAmbient = U.Hue(os.clock() * 0.9 + 0.5)
			end)
			task.wait(0.08)
		end
		pcall(function()
			Lighting.Ambient = Color3.fromRGB(70, 70, 70)
			Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		end)
	end)
end

function Fun:SpinToggle()
	self.Spin = not self.Spin
	if not self.Spin then return end
	task.spawn(function()
		while self.Spin and CS.Alive and Camera do
			Camera.CFrame = Camera.CFrame * CFrame.Angles(0, math.rad(1.6), 0)
			task.wait(0.01)
		end
	end)
end

--==========================================================
-- 17. OVERLAY
--==========================================================
local OV = { Circle = nil, Box = nil, Line = nil, Info = nil, Ring = nil, Dots = {}, Cross = {} }

function OV:Init()
	self.Circle = Draw.New("Circle", { Thickness = 1, Filled = false, NumSides = 96 })
	self.Box = Draw.New("Square", { Thickness = 2, Filled = false })
	self.Line = Draw.New("Line", { Thickness = 1 })
	self.Info = Draw.New("Text", { Center = true, Outline = true, Size = 13 })
	self.Ring = Draw.New("Circle", { Thickness = 1, Filled = false, NumSides = 40 })
	for i = 1, 44 do self.Dots[i] = Draw.New("Square", { Filled = true, Thickness = 0, Size = Vector2.new(3, 3) }) end
	for i = 1, 4 do self.Cross[i] = Draw.New("Line", { Thickness = 2 }) end
end

function OV:Step()
	if not Camera then return end
	local vp = Camera.ViewportSize
	local c = Vector2.new(vp.X / 2, vp.Y / 2)
	local acc = U.Col(Cfg.Get("ColorCircle"))

	local on = Cfg.Get("SilentAim") and Cfg.Get("CircleOn")
	local style = Cfg.Get("CircleStyle")
	self.Circle.Visible = on and style ~= "Kropkowane"
	if self.Circle.Visible then
		self.Circle.Position = c
		self.Circle.Radius = Cfg.Get("SilentFOV")
		self.Circle.Color = acc
		self.Circle.Thickness = style == "Grube" and 3 or 1
	end

	local dots = on and style == "Kropkowane"
	local r = Cfg.Get("SilentFOV")
	for i, d in ipairs(self.Dots) do
		d.Visible = dots
		if dots then
			local a = (i / #self.Dots) * math.pi * 2
			d.Color = acc
			d.Position = c + Vector2.new(math.cos(a), math.sin(a)) * r - Vector2.new(1.5, 1.5)
		end
	end

	local t = SA.Target or AB.Target
	local viz = t and Cfg.Get("SilentViz") and t.Part.Parent
	if viz then
		local aim = T.AimPoint(t.Part, Cfg.Get("SilentPredict")) or t.Part.Position
		local s, o = Camera:WorldToViewportPoint(aim)
		self.Box.Visible = o
		self.Line.Visible = o
		self.Info.Visible = o
		if o then
			self.Box.Color = acc
			self.Box.Size = Vector2.new(26, 26)
			self.Box.Position = Vector2.new(s.X - 13, s.Y - 13)
			self.Line.Color = acc
			self.Line.From = c
			self.Line.To = Vector2.new(s.X, s.Y)
			self.Info.Color = acc
			self.Info.Text = string.format("%s · %s", t.Player.Name, t.Part.Name)
			self.Info.Position = Vector2.new(s.X, s.Y - 28)

			self.Ring.Visible = Cfg.Get("LockRing")
			self.Ring.Color = acc
			self.Ring.Position = Vector2.new(s.X, s.Y)
			self.Ring.Radius = 20 + math.sin(os.clock() * 6) * 3
		else
			self.Ring.Visible = false
		end
	else
		self.Box.Visible = false
		self.Line.Visible = false
		self.Info.Visible = false
		self.Ring.Visible = false
	end

	for _, l in ipairs(self.Cross) do l.Visible = false end
	if Cfg.Get("Crosshair") then
		local col = U.Col(Cfg.Get("ColorCross"))
		local gap, len = 6, 10
		local function seg(a, b)
			for _, l in ipairs(self.Cross) do
				if not l.Visible then
					l.Visible = true
					l.Color = col
					l.From = a
					l.To = b
					return
				end
			end
		end
		if Cfg.Get("CrosshairStyle") == "Krzyż" then
			seg(c - Vector2.new(gap + len, 0), c - Vector2.new(gap, 0))
			seg(c + Vector2.new(gap, 0), c + Vector2.new(gap + len, 0))
			seg(c - Vector2.new(0, gap + len), c - Vector2.new(0, gap))
			seg(c + Vector2.new(0, gap), c + Vector2.new(0, gap + len))
		else
			seg(c - Vector2.new(5, 5), c + Vector2.new(5, 5))
			seg(c + Vector2.new(5, -5), c + Vector2.new(-5, 5))
		end
	end
end

--==========================================================
-- 18. THEME
--==========================================================
local TH = {
	Bg = Color3.fromRGB(9, 12, 16),
	Panel = Color3.fromRGB(15, 19, 25),
	Card = Color3.fromRGB(21, 26, 33),
	Hover = Color3.fromRGB(31, 38, 47),
	Line = Color3.fromRGB(40, 49, 59),
	Text = Color3.fromRGB(236, 244, 240),
	Dim = Color3.fromRGB(122, 136, 147),
	Acc = Color3.fromRGB(61, 255, 158),
	AccD = Color3.fromRGB(19, 84, 55),
	Red = Color3.fromRGB(255, 96, 96),
}

local Accents = {}

local function applyAccent()
	local c = U.Col(Cfg.Get("ColorAccent"))
	TH.Acc = c
	TH.AccD = Color3.fromRGB(c.R * 84, c.G * 84, c.B * 84)
	for _, inst in ipairs(Accents) do
		if inst and inst.Parent then pcall(function() inst.BackgroundColor3 = c end) end
	end
end

--==========================================================
-- 19. UI
--==========================================================
local UI = { Tabs = {}, Ref = {}, Toasts = {}, Search = {}, Min = false, Drag = nil }

function UI:Bind(k, fn) self.Ref[k] = fn end

function UI:Hook()
	local move = Input.InputChanged:Connect(function(i)
		if not (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then return end
		if UI.Drag and UI.Drag.Move then pcall(UI.Drag.Move, i) end
	end)
	local up = Input.InputEnded:Connect(function(i)
		if not (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then return end
		if UI.Drag and UI.Drag.Stop then pcall(UI.Drag.Stop) end
		UI.Drag = nil
	end)
	U.Track(move)
	U.Track(up)
end

function UI:Hint(txt)
	if self.FootHint then self.FootHint.Text = txt end
end

function UI:Root()
	local g = Instance.new("ScreenGui")
	g.Name = "ChelmskiSiekatorV8"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 10000
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local ok = pcall(function() g.Parent = gethuiSafe() end)
	if not ok or not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end

	local holder = U.Try("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, g)
	if holder then UI.IsCanvas = true
	else holder = U.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, g) end

	local w0 = U.Clamp(tonumber(Cfg.Get("WinW")) or 680, 520, 1600)
	local h0 = U.Clamp(tonumber(Cfg.Get("WinH")) or 470, 340, 1200)

	local main = U.New("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(w0, h0),
		Position = UDim2.new(0.5, -w0 / 2, 0.5, -h0 / 2),
		BackgroundColor3 = TH.Bg,
		BorderSizePixel = 0,
	}, holder)
	U.Corner(main, 18)
	local mainStroke = U.Stroke(main, TH.Line, 1, 0.3)
	main.ClipsDescendants = true

	local sc = U.Try("UIScale", {}, main)
	if sc then sc.Scale = U.Clamp(tonumber(Cfg.Get("UIScale")) or 1, 0.8, 1.25) end

	for i = 1, 3 do
		local b = U.New("Frame", {
			Size = UDim2.fromOffset(200 + i * 45, 200 + i * 45),
			Position = UDim2.fromOffset(-70 + i * 190, -90 + i * 40),
			BackgroundColor3 = TH.Acc, BackgroundTransparency = 0.94,
			BorderSizePixel = 0, ZIndex = 1,
		}, main)
		U.Corner(b, 999)
		table.insert(Accents, b)
	end

	local accent = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = TH.Acc, BorderSizePixel = 0, ZIndex = 4,
	}, main)
	U.Grad(accent, TH.Acc, Color3.fromRGB(120, 255, 200), 0)
	table.insert(Accents, accent)

	local bar = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = TH.Panel, BorderSizePixel = 0, ZIndex = 3,
	}, main)
	U.Grad(bar, Color3.fromRGB(24, 31, 39), TH.Bg, 90)

	local logo = U.New("Frame", {
		Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(18, 15),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0, ZIndex = 5,
	}, bar)
	U.Corner(logo, 11)
	table.insert(Accents, logo)
	U.New("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "◤",
		Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = TH.Bg, ZIndex = 6,
	}, logo)

	local title = U.New("TextLabel", {
		Size = UDim2.fromOffset(320, 20), Position = UDim2.fromOffset(62, 13),
		BackgroundTransparency = 1, Text = "CHEŁMSKI SIEKATOR",
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	}, bar)

	local sub = U.New("TextLabel", {
		Size = UDim2.fromOffset(320, 16), Position = UDim2.fromOffset(62, 33),
		BackgroundTransparency = 1, Text = "Ugotowane przez Pstryczka  ·  v" .. CS.Version,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TH.Acc,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	}, bar)

	local function barBtn(glyph, x, cb, danger)
		local b = U.New("TextButton", {
			Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, x, 0, 18),
			BackgroundColor3 = TH.Card, Text = glyph, Font = Enum.Font.GothamBold,
			TextSize = 14, TextColor3 = TH.Dim, AutoButtonColor = false,
			BorderSizePixel = 0, ZIndex = 5,
		}, bar)
		U.Corner(b, 9)
		b.MouseEnter:Connect(function()
			U.Tween(b, 0.12, { BackgroundColor3 = TH.Hover, TextColor3 = danger and TH.Red or TH.Text })
		end)
		b.MouseLeave:Connect(function()
			U.Tween(b, 0.12, { BackgroundColor3 = TH.Card, TextColor3 = TH.Dim })
		end)
		b.MouseButton1Click:Connect(function() pcall(cb) end)
		return b
	end
	barBtn("–", -74, function() UI:Minimize() end)
	barBtn("✕", -42, function() UI:Close() end, true)

	local side = U.New("Frame", {
		Size = UDim2.new(0, 176, 1, -90), Position = UDim2.fromOffset(0, 64),
		BackgroundColor3 = TH.Panel, BorderSizePixel = 0, ZIndex = 2,
	}, main)
	U.Grad(side, Color3.fromRGB(18, 23, 30), TH.Bg, 90)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 11)
	pad.PaddingRight = UDim.new(0, 11)
	pad.Parent = side

	local search = U.New("TextBox", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = TH.Card, Text = "",
		PlaceholderText = "szukaj…", PlaceholderColor3 = TH.Dim,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0,
		ZIndex = 3,
	}, side)
	U.Corner(search, 7)
	local sp = Instance.new("UIPadding")
	sp.PaddingLeft = UDim.new(0, 9)
	sp.Parent = search
	UI.FootHint = nil

	local listWrap = U.New("Frame", {
		Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34),
		BackgroundTransparency = 1, ZIndex = 2,
	}, side)
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 5)
	lay.Parent = listWrap

	local content = U.New("Frame", {
		Size = UDim2.new(1, -176, 1, -90), Position = UDim2.fromOffset(176, 64),
		BackgroundTransparency = 1, ZIndex = 2,
	}, main)

	local foot = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -26),
		BackgroundColor3 = TH.Panel, BorderSizePixel = 0, ZIndex = 3,
	}, main)
	U.Grad(foot, TH.Bg, Color3.fromRGB(20, 26, 33), 90)
	local fdot = U.New("Frame", {
		Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(18, 10),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0, ZIndex = 4,
	}, foot)
	U.Corner(fdot, 3)
	table.insert(Accents, fdot)

	UI.FootHint = U.New("TextLabel", {
		Size = UDim2.fromOffset(430, 26), Position = UDim2.fromOffset(30, 0),
		BackgroundTransparency = 1, Text = "Ugotowane przez Pstryczka  ·  v" .. CS.Version,
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = TH.Dim,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
	}, foot)
	U.New("TextLabel", {
		Size = UDim2.fromOffset(140, 26), Position = UDim2.new(1, -152, 0, 0),
		BackgroundTransparency = 1, Text = "PSTRYCZEK",
		Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = TH.AccD,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
	}, foot)

	local handle = U.New("Frame", {
		Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -18, 1, -18),
		BackgroundTransparency = 1, ZIndex = 6,
	}, main)
	U.New("Frame", {
		Size = UDim2.fromOffset(9, 2), Position = UDim2.fromOffset(5, 10),
		BackgroundColor3 = TH.Dim, BorderSizePixel = 0, Rotation = 45,
	}, handle)

	local function beginDrag(i)
		local base = main.AbsolutePosition
		local st = i.Position
		U.Tween(mainStroke, 0.15, { Transparency = 0, Color = TH.Acc })
		UI.Drag = {
			Move = function(mv)
				local vp = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
				local d = mv.Position - st
				local x = U.Clamp(base.X + d.X, 0, math.max(vp.X - main.AbsoluteSize.X, 0))
				local y = U.Clamp(base.Y + d.Y, 0, math.max(vp.Y - main.AbsoluteSize.Y, 0))
				main.Position = UDim2.fromOffset(x, y)
				Cfg.Set("WinX", math.floor(x))
				Cfg.Set("WinY", math.floor(y))
				Cfg.Set("WinSet", true)
			end,
			Stop = function() U.Tween(mainStroke, 0.25, { Transparency = 0.3, Color = TH.Line }) end,
		}
	end

	for _, h in ipairs({ bar, logo, title, sub }) do
		h.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				beginDrag(i)
			end
		end)
	end

	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			if (os.clock() - (UI.LastBar or 0)) < 0.35 then
				main.Position = UDim2.new(0.5, -main.AbsoluteSize.X / 2, 0.5, -main.AbsoluteSize.Y / 2)
				Cfg.Set("WinSet", false)
			end
			UI.LastBar = os.clock()
		end
	end)

	handle.InputBegan:Connect(function(i)
		if not (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then return end
		local st = i.Position
		local base = Vector2.new(main.AbsoluteSize.X, main.AbsoluteSize.Y)
		UI.Drag = {
			Move = function(mv)
				local vp = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
				local d = mv.Position - st
				local w = U.Clamp(base.X + d.X, 520, math.max(vp.X - 40, 520))
				local hh = U.Clamp(base.Y + d.Y, 340, math.max(vp.Y - 40, 340))
				main.Size = UDim2.fromOffset(w, hh)
				Cfg.Set("WinW", math.floor(w))
				Cfg.Set("WinH", math.floor(hh))
			end,
			Stop = function() end,
		}
	end)

	search:GetPropertyChangedSignal("Text"):Connect(function()
		UI:Filter(search.Text)
	end)

	return g, holder, main, listWrap, content
end

function UI:Filter(q)
	q = q:lower()
	for _, item in ipairs(self.Search) do
		if item.Row and item.Row.Parent then
			if q == "" then
				item.Row.Visible = true
			else
				item.Row.Visible = item.Label:lower():find(q, 1, true) ~= nil
			end
		end
	end
end

function UI:Reg(row, label)
	table.insert(self.Search, { Row = row, Label = label })
end

function UI:Init()
	self.Gui, self.Holder, self.Main, self.Side, self.Content = self:Root()
	local w = self.Main.Size.X.Offset
	local h = self.Main.Size.Y.Offset
	self.Main.Size = UDim2.fromOffset(w, 300)
	if self.IsCanvas then self.Holder.GroupTransparency = 1 end
	U.Tween(self.Main, 0.45, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	if self.IsCanvas then U.Tween(self.Holder, 0.28, { GroupTransparency = 0 }) end

	if Cfg.Get("WinSet") then
		local vp = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
		local x = U.Clamp(tonumber(Cfg.Get("WinX")) or 0, 0, math.max(vp.X - w, 0))
		local y = U.Clamp(tonumber(Cfg.Get("WinY")) or 0, 0, math.max(vp.Y - h, 0))
		self.Main.Position = UDim2.fromOffset(x, y)
	end

	pcall(applyAccent)
	self.IsOpen = true
end

function UI:Ripple(btn)
	btn.MouseButton1Click:Connect(function()
		local m = Input:GetMouseLocation()
		local r = U.New("Frame", {
			Size = UDim2.fromOffset(0, 0),
			Position = UDim2.fromOffset(m.X - btn.AbsolutePosition.X, m.Y - btn.AbsolutePosition.Y),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7,
			BorderSizePixel = 0, ZIndex = 2,
		}, btn)
		U.Corner(r, 999)
		U.Tween(r, 0.45, { Size = UDim2.fromOffset(180, 180), BackgroundTransparency = 1 })
		task.delay(0.5, function() if r.Parent then r:Destroy() end end)
	end)
end

function UI:Tab(name, glyph)
	local btn = U.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = TH.Card,
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, self.Side)
	U.Corner(btn, 9)

	local badge = U.New("Frame", {
		Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(9, 7),
		BackgroundColor3 = TH.Hover, BorderSizePixel = 0, ZIndex = 2,
	}, btn)
	U.Corner(badge, 6)
	U.New("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = glyph,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TH.Dim, ZIndex = 3,
	}, badge)
	local lbl = U.New("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(36, 0),
		BackgroundTransparency = 1, Text = name, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = TH.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
	}, btn)

	local marker = U.New("Frame", {
		Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, -1, 0.5, -10),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0, ZIndex = 4,
	}, btn)
	U.Corner(marker, 2)
	table.insert(Accents, marker)

	local page = U.New("ScrollingFrame", {
		Size = UDim2.new(1, -28, 1, -26), Position = UDim2.fromOffset(16, 13),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = TH.AccD, CanvasSize = UDim2.new(), Visible = false,
	}, self.Content)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = page
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 24)
	end)

	local tab = { Btn = btn, Page = page, Marker = marker, Badge = badge, Label = lbl }
	table.insert(self.Tabs, tab)

	btn.MouseEnter:Connect(function()
		if self.Active ~= tab then
			U.Tween(btn, 0.12, { BackgroundTransparency = 0.88 })
			U.Tween(lbl, 0.12, { TextColor3 = TH.Text })
			U.Tween(badge, 0.12, { BackgroundColor3 = TH.AccD })
		end
	end)
	btn.MouseLeave:Connect(function()
		if self.Active ~= tab then
			U.Tween(btn, 0.12, { BackgroundTransparency = 1 })
			U.Tween(lbl, 0.12, { TextColor3 = TH.Dim })
			U.Tween(badge, 0.12, { BackgroundColor3 = TH.Hover })
		end
	end)
	btn.MouseButton1Click:Connect(function() self:Select(tab) end)

	return tab
end

function UI:Select(tab)
	if self.Active == tab then return end
	if self.Active then
		self.Active.Page.Visible = false
		U.Tween(self.Active.Label, 0.12, { TextColor3 = TH.Dim })
		U.Tween(self.Active.Btn, 0.12, { BackgroundTransparency = 1 })
		U.Tween(self.Active.Badge, 0.12, { BackgroundColor3 = TH.Hover })
		U.Tween(self.Active.Marker, 0.15, { Size = UDim2.new(0, 3, 0, 0) })
	end
	self.Active = tab
	tab.Page.Visible = true
	U.Tween(tab.Label, 0.12, { TextColor3 = TH.Acc })
	U.Tween(tab.Btn, 0.12, { BackgroundTransparency = 0.7 })
	U.Tween(tab.Badge, 0.12, { BackgroundColor3 = TH.AccD })
	U.Tween(tab.Marker, 0.2, { Size = UDim2.new(0, 3, 0, 20) }, Enum.EasingStyle.Back)
	tab.Page.Position = UDim2.fromOffset(30, 13)
	U.Tween(tab.Page, 0.22, { Position = UDim2.fromOffset(16, 13) })
end

function UI:Section(page, text)
	local f = U.New("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }, page)
	local b = U.New("Frame", {
		Size = UDim2.fromOffset(3, 11), Position = UDim2.fromOffset(0, 3),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0,
	}, f)
	table.insert(Accents, b)
	U.New("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(11, 0),
		BackgroundTransparency = 1, Text = text:upper(), Font = Enum.Font.GothamBold,
		TextSize = 10, TextColor3 = TH.Acc, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
end

function UI:Card(page, h, hint, label)
	local f = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, h or 36), BackgroundColor3 = TH.Card, BorderSizePixel = 0,
	}, page)
	U.Corner(f, 10)
	local s = U.Stroke(f, TH.Line, 1, 0.55)
	U.Grad(f, Color3.fromRGB(27, 33, 41), TH.Card, 90)
	f.MouseEnter:Connect(function()
		U.Tween(s, 0.15, { Transparency = 0.2, Color = TH.AccD })
		if hint then UI:Hint(hint) end
	end)
	f.MouseLeave:Connect(function()
		U.Tween(s, 0.15, { Transparency = 0.55, Color = TH.Line })
		if hint then UI:Hint("Ugotowane przez Pstryczka  ·  v" .. CS.Version) end
	end)
	if label then self:Reg(f, label) end
	return f
end

function UI:Toggle(page, label, key, cb, hint)
	local row = self:Card(page, 36, hint, label)
	U.New("TextLabel", {
		Size = UDim2.new(1, -62, 1, 0), Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local pill = U.New("Frame", {
		Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = TH.Hover, BorderSizePixel = 0,
	}, row)
	U.Corner(pill, 10)

	local knob = U.New("Frame", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = TH.Dim, BorderSizePixel = 0,
	}, pill)
	U.Corner(knob, 7)

	local hit = U.New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, row)

	local function paint(on, anim)
		local bg = on and TH.AccD or TH.Hover
		local kc = on and TH.Acc or TH.Dim
		local kp = on and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3)
		if anim then
			U.Tween(pill, 0.18, { BackgroundColor3 = bg }, Enum.EasingStyle.Back)
			U.Tween(knob, 0.18, { Position = kp, BackgroundColor3 = kc }, Enum.EasingStyle.Back)
		else
			pill.BackgroundColor3 = bg knob.BackgroundColor3 = kc knob.Position = kp
		end
	end

	paint(Cfg.Get(key), false)
	self:Bind(key, function() paint(Cfg.Get(key), true) end)

	hit.MouseButton1Click:Connect(function()
		local v = not Cfg.Get(key)
		Cfg.Set(key, v)
		paint(v, true)
		if cb then task.spawn(cb, v) end
	end)
	return row
end

function UI:Slider(page, label, key, min, max, step, suffix, cb, hint)
	local row = self:Card(page, 50, hint, label)
	U.New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 20), Position = UDim2.fromOffset(13, 6),
		BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local val = U.New("TextLabel", {
		Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -84, 0, 6),
		BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold,
		TextSize = 12, TextColor3 = TH.Acc, TextXAlignment = Enum.TextXAlignment.Right,
	}, row)

	local track = U.New("Frame", {
		Size = UDim2.new(1, -26, 0, 4), Position = UDim2.fromOffset(13, 36),
		BackgroundColor3 = TH.Hover, BorderSizePixel = 0,
	}, row)
	U.Corner(track, 2)

	local fill = U.New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = TH.Acc, BorderSizePixel = 0 }, track)
	U.Corner(fill, 2)

	local knob = U.New("Frame", {
		Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, -6, 0.5, -6),
		BackgroundColor3 = TH.Text, BorderSizePixel = 0, ZIndex = 2,
	}, track)
	U.Corner(knob, 6)

	local function set(v, fire, silent)
		v = U.Clamp(U.Round(v, step), min, max)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.new(a, -6, 0.5, -6)
		val.Text = tostring(v) .. (suffix or "")
		if not silent then Cfg.Set(key, v) end
		if fire and cb then task.spawn(cb, v) end
	end

	set(Cfg.Get(key), false, true)
	self:Bind(key, function() set(Cfg.Get(key), false, true) end)

	local function from(i)
		local r = U.Clamp((i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(min + (max - min) * r, true, false)
	end

	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			U.Tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
			from(i)
			UI.Drag = {
				Move = from,
				Stop = function() U.Tween(knob, 0.12, { Size = UDim2.fromOffset(12, 12) }) end,
			}
		end
	end)
	return row
end

function UI:Dropdown(page, label, key, opts, cb, hint)
	local row = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = TH.Card,
		BorderSizePixel = 0, ClipsDescendants = true,
	}, page)
	U.Corner(row, 10)
	U.Stroke(row, TH.Line, 1, 0.55)
	self:Reg(row, label)
	if hint then
		row.MouseEnter:Connect(function() UI:Hint(hint) end)
		row.MouseLeave:Connect(function() UI:Hint("Ugotowane przez Pstryczka  ·  v" .. CS.Version) end)
	end

	local head = U.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
	}, row)
	U.New("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, head)
	local cur = U.New("TextLabel", {
		Size = UDim2.fromOffset(90, 36), Position = UDim2.new(1, -100, 0, 0),
		BackgroundTransparency = 1, Text = tostring(Cfg.Get(key)) .. "  ▾",
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TH.Acc,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, head)

	local holder = U.New("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, row)
	local hl = Instance.new("UIListLayout")
	hl.Padding = UDim.new(0, 4)
	hl.Parent = holder

	local open = false
	for _, o in ipairs(opts) do
		local b = U.New("TextButton", {
			Size = UDim2.new(1, -18, 0, 28), BackgroundColor3 = TH.Hover,
			Text = "   " .. o, Font = Enum.Font.Gotham, TextSize = 12,
			TextColor3 = TH.Dim, TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false, BorderSizePixel = 0,
		}, holder)
		U.Corner(b, 7)
		b.MouseEnter:Connect(function() U.Tween(b, 0.1, { TextColor3 = TH.Text }) end)
		b.MouseLeave:Connect(function() U.Tween(b, 0.1, { TextColor3 = TH.Dim }) end)
		b.MouseButton1Click:Connect(function()
			Cfg.Set(key, o)
			cur.Text = o .. "  ▾"
			open = false
			holder.Visible = false
			U.Tween(row, 0.16, { Size = UDim2.new(1, 0, 0, 36) })
			if cb then task.spawn(cb, o) end
		end)
	end
	holder.Visible = false

	head.MouseButton1Click:Connect(function()
		open = not open
		holder.Visible = open
		U.Tween(row, 0.2, { Size = UDim2.new(1, 0, 0, open and (42 + #opts * 32) or 36) })
	end)

	self:Bind(key, function() cur.Text = tostring(Cfg.Get(key)) .. "  ▾" end)
	return row
end

local SWATCH = {
	{ 61, 255, 158 }, { 90, 170, 255 }, { 255, 96, 96 }, { 255, 200, 60 },
	{ 200, 120, 255 }, { 255, 255, 255 }, { 255, 120, 200 }, { 120, 255, 255 },
}

function UI:Color(page, label, key, hint)
	local row = self:Card(page, 32, hint, label)
	row.ClipsDescendants = true
	U.New("TextLabel", {
		Size = UDim2.fromOffset(112, 32), Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
		TextSize = 12, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local prev = U.New("TextButton", {
		Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -30, 0, 7),
		BackgroundColor3 = U.Col(Cfg.Get(key)), Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, row)
	U.Corner(prev, 9)
	U.Stroke(prev, TH.Line, 1)

	for i, rgb in ipairs(SWATCH) do
		local s = U.New("TextButton", {
			Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(126 + (i - 1) * 20, 8),
			BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
			Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		}, row)
		U.Corner(s, 8)
		s.MouseButton1Click:Connect(function()
			Cfg.Set(key, table.clone(rgb))
			prev.BackgroundColor3 = U.Col(rgb)
		end)
	end

	local panel = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, 32),
		BackgroundTransparency = 1, ClipsDescendants = true,
	}, row)
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 3)
	pl.Parent = panel
	local plPad = Instance.new("UIPadding")
	plPad.PaddingLeft = UDim.new(0, 13)
	plPad.PaddingRight = UDim.new(0, 13)
	plPad.Parent = panel

	local cur = table.clone(Cfg.Get(key))
	local function write()
		Cfg.Set(key, table.clone(cur))
		prev.BackgroundColor3 = Color3.fromRGB(cur[1], cur[2], cur[3])
	end

	for idx, nm in ipairs({ "R", "G", "B" }) do
		local r = U.New("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = TH.Hover, BorderSizePixel = 0 }, panel)
		U.Corner(r, 6)
		U.New("TextLabel", {
			Size = UDim2.fromOffset(18, 24), BackgroundTransparency = 1, Text = nm,
			Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = TH.Dim,
		}, r)
		local tr = U.New("Frame", {
			Size = UDim2.new(1, -50, 0, 4), Position = UDim2.new(0, 22, 0.5, -2),
			BackgroundColor3 = TH.Line, BorderSizePixel = 0,
		}, r)
		U.Corner(tr, 2)
		local fl = U.New("Frame", { Size = UDim2.fromScale(cur[idx] / 255, 1), BackgroundColor3 = TH.Acc, BorderSizePixel = 0 }, tr)
		U.Corner(fl, 2)
		local function upd(i)
			local a = U.Clamp((i.Position.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
			cur[idx] = math.floor(a * 255)
			fl.Size = UDim2.fromScale(a, 1)
			write()
		end
		tr.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				upd(i)
				UI.Drag = { Move = upd, Stop = function() end }
			end
		end)
	end

	prev.MouseButton1Click:Connect(function()
		local open = row.Size.Y.Offset < 60
		U.Tween(row, 0.2, { Size = UDim2.new(1, 0, 0, open and 120 or 32) })
		panel.Size = UDim2.new(1, 0, 0, open and 84 or 0)
		panel.Visible = open
	end)
	panel.Visible = false
	self:Bind(key, function()
		local c = Cfg.Get(key)
		cur = table.clone(c)
		prev.BackgroundColor3 = U.Col(c)
	end)
	return row
end

function UI:Keybind(page, label, key, hint)
	local row = self:Card(page, 36, hint, label)
	U.New("TextLabel", {
		Size = UDim2.new(1, -92, 1, 0), Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local b = U.New("TextButton", {
		Size = UDim2.fromOffset(72, 22), Position = UDim2.new(1, -82, 0.5, -11),
		BackgroundColor3 = TH.Hover, Text = Cfg.Get(key), Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = TH.Acc, AutoButtonColor = false, BorderSizePixel = 0,
	}, row)
	U.Corner(b, 6)
	local wait = false
	b.MouseButton1Click:Connect(function() wait = true b.Text = "…" b.TextColor3 = TH.Red end)
	U.Track(Input.InputBegan:Connect(function(i)
		if not wait or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		wait = false
		Cfg.Set(key, i.KeyCode.Name)
		b.Text = i.KeyCode.Name
		b.TextColor3 = TH.Acc
	end))
	self:Bind(key, function() b.Text = Cfg.Get(key) end)
	return row
end

function UI:Button(page, label, cb, danger, hint)
	local b = U.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = danger and Color3.fromRGB(64, 26, 30) or TH.Card,
		Text = label, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = danger and TH.Red or TH.Text, AutoButtonColor = false,
		BorderSizePixel = 0, ClipsDescendants = true,
	}, page)
	U.Corner(b, 10)
	U.Stroke(b, TH.Line, 1, 0.6)
	self:Reg(b, label)
	if hint then
		b.MouseEnter:Connect(function() UI:Hint(hint) end)
		b.MouseLeave:Connect(function() UI:Hint("Ugotowane przez Pstryczka  ·  v" .. CS.Version) end)
	end
	b.MouseEnter:Connect(function() U.Tween(b, 0.12, { BackgroundColor3 = TH.Hover }) end)
	b.MouseLeave:Connect(function() U.Tween(b, 0.12, { BackgroundColor3 = danger and Color3.fromRGB(64, 26, 30) or TH.Card }) end)
	b.MouseButton1Click:Connect(function() task.spawn(cb) end)
	self:Ripple(b)
	return b
end

function UI:Label(page, text, dim)
	U.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1, Text = text,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = dim and TH.Dim or TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, page)
end

function UI:Minimize()
	self.Min = not self.Min
	local w = self.Main.Size.X.Offset
	U.Tween(self.Main, 0.26, { Size = self.Min and UDim2.fromOffset(w, 64) or UDim2.fromOffset(w, Cfg.Get("WinH")) }, Enum.EasingStyle.Quart)
	self.Side.Visible = not self.Min
	self.Content.Visible = not self.Min
end

function UI:Close()
	if not self.IsOpen then return end
	self.IsOpen = false
	if self.IsCanvas then U.Tween(self.Holder, 0.2, { GroupTransparency = 1 }) end
	task.delay(0.21, function() if self.Gui then self.Gui.Enabled = false end end)
end

function UI:Open()
	if self.IsOpen or not self.Gui then return end
	self.IsOpen = true
	self.Gui.Enabled = true
	if self.IsCanvas then
		self.Holder.GroupTransparency = 1
		U.Tween(self.Holder, 0.2, { GroupTransparency = 0 })
	end
end

function UI:ToggleOpen()
	if not self.Gui then return end
	if self.IsOpen then self:Close() else self:Open() end
end

function UI:Toast(title, body, danger)
	if not self.Gui or not Cfg.Get("ShowToast") then return end
	local t = U.New("Frame", {
		Size = UDim2.fromOffset(250, 46), Position = UDim2.new(1, 12, 0, 12),
		BackgroundColor3 = TH.Card, BorderSizePixel = 0,
	}, self.Gui)
	U.Corner(t, 11)
	U.Stroke(t, danger and TH.Red or TH.Acc, 1, 0.45)
	U.New("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = danger and TH.Red or TH.Acc, BorderSizePixel = 0 }, t)
	U.New("TextLabel", {
		Size = UDim2.new(1, -18, 0, 16), Position = UDim2.fromOffset(13, 6),
		BackgroundTransparency = 1, Text = title, Font = Enum.Font.GothamBold,
		TextSize = 12, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, t)
	U.New("TextLabel", {
		Size = UDim2.new(1, -18, 0, 14), Position = UDim2.fromOffset(13, 24),
		BackgroundTransparency = 1, Text = body, Font = Enum.Font.Gotham, TextSize = 10,
		TextColor3 = TH.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, t)

	for i, o in ipairs(self.Toasts) do U.Tween(o, 0.2, { Position = UDim2.new(1, 12, 0, 12 + i * 54) }) end
	table.insert(self.Toasts, t)
	U.Tween(t, 0.3, { Position = UDim2.new(1, -262, 0, 12) }, Enum.EasingStyle.Back)

	task.delay(3.2, function()
		local i = table.find(self.Toasts, t)
		if i then table.remove(self.Toasts, i) end
		U.Tween(t, 0.25, { Position = UDim2.new(1, 12, 0, t.Position.Y.Offset), BackgroundTransparency = 1 })
		task.delay(0.3, function() if t.Parent then t:Destroy() end end)
	end)
end

--==========================================================
-- 20. WATERMARK
--==========================================================
local WM = {}

function WM:Init()
	self.F = U.New("Frame", {
		Size = UDim2.fromOffset(232, 26), Position = UDim2.fromOffset(12, -40),
		BackgroundColor3 = TH.Bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}, UI.Gui)
	U.Corner(self.F, 8)
	U.Stroke(self.F, TH.Acc, 1, 0.6)
	self.D = U.New("Frame", {
		Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0,
	}, self.F)
	U.Corner(self.D, 3)
	table.insert(Accents, self.D)
	self.T = U.New("TextLabel", {
		Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(22, 0),
		BackgroundTransparency = 1, Text = "PSTRYCZEK · v" .. CS.Version,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.F)
	U.Tween(self.F, 0.4, { Position = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back)
	task.spawn(function()
		while CS.Alive do
			U.Tween(self.D, 0.5, { BackgroundTransparency = 0.7 })
			task.wait(0.55)
			U.Tween(self.D, 0.5, { BackgroundTransparency = 0 })
			task.wait(0.55)
		end
	end)
end

function WM:Step()
	if not self.T then return end
	if not Cfg.Get("ShowWM") then self.F.Visible = false return end
	self.F.Visible = true
	local ping = 0
	pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
	self.T.Text = string.format("PSTRYCZEK · v%s · %d FPS · %d ms", CS.Version, math.floor(CS.FPS), ping)
end

--==========================================================
-- 21. DIAGNOSTYKA
--==========================================================
local Diag = {}

local CHECKS = {
	{ "Drawing API", function() return Draw.Has end },
	{ "getrawmetatable", function() return type(getrawmetatable) == "function" end },
	{ "hookmetamethod", function() return type(hookmetamethod) == "function" end },
	{ "gethui", function() return type(gethui) == "function" end },
	{ "writefile", function() return type(writefile) == "function" end },
	{ "VirtualInputManager", function() return VIM ~= nil end },
	{ "TextChatService", function() return TCS ~= nil end },
	{ "Kamera", function() return Camera ~= nil end },
	{ "PlayerGui", function() return LP and LP:FindFirstChildOfClass("PlayerGui") ~= nil end },
	{ "Hook zamontowany", function() return SA.Hooked end },
	{ "GUI rodzic", function() return UI.Gui and UI.Gui.Parent ~= nil end },
	{ "FPS >= 30", function() return CS.FPS >= 30 end },
}

function Diag:Run()
	if not self.Holder then return end
	for _, ch in ipairs(self.Holder:GetChildren()) do
		if ch:IsA("TextButton") then ch:Destroy() end
	end
	for _, c in ipairs(CHECKS) do
		local ok = false
		pcall(function() ok = c[2]() == true end)
		local b = U.New("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = ok and Color3.fromRGB(18, 46, 32) or Color3.fromRGB(52, 20, 24),
			Text = "  " .. (ok and "✔  " or "✖  ") .. c[1],
			Font = Enum.Font.Gotham, TextSize = 11,
			TextColor3 = ok and TH.Acc or TH.Red,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false, BorderSizePixel = 0,
		}, self.Holder)
		U.Corner(b, 6)
	end
end

--==========================================================
-- 22. BUILD
--==========================================================
local function tab(name, glyph, fn)
	local t
	local ok = pcall(function() t = UI:Tab(name, glyph) end)
	if not ok or not t then return nil end
	if fn then pcall(fn, t.Page) end
	return t
end

local function build()
	UI:Init()
	UI:Hook()
	WM:Init()

	tab("Aim", "⌖", function(p)
		UI:Section(p, "Silent Aim")
		UI:Toggle(p, "Silent Aim", "SilentAim", function(on)
			if on and not SA:Install() then UI:Toast("Silent Aim", "Brak hooków — tryb kamerowy", true) end
		end, "Przechwytuje wektor strzału — kamera zostaje na miejscu")
		UI:Slider(p, "Szansa trafienia", "SilentChance", 0, 100, 1, "%", nil, "Odsetek strzałów, które trafią w cel")
		UI:Slider(p, "FOV", "SilentFOV", 20, 500, 5, " px", nil, "Stożek, w którym szukany jest cel")
		UI:Slider(p, "Zasięg", "SilentRange", 50, 3000, 25, " st", nil, "Maksymalna odległość celu")
		UI:Slider(p, "Predykcja", "SilentPredict", 0, 0.6, 0.01, " s", nil, "Wyprzedzenie ruchu celu")
		UI:Dropdown(p, "Część ciała", "SilentPart", { "Head", "UpperTorso", "HumanoidRootPart", "Blisko" }, nil, "Punkt, w który leci strzał")
		UI:Dropdown(p, "Priorytet", "SilentPriority", { "FOV", "Dystans", "Zdrowie" }, nil, "Jak wybierany jest cel")
		UI:Dropdown(p, "Tryb FOV", "FovMode", { "Ekran", "3D" }, nil, "Ekran = piksele, 3D = kąt w stopniach")
		UI:Toggle(p, "Tylko widoczni", "SilentVisible", nil, "Pomija cele za ścianami")
		UI:Toggle(p, "Tylko na trzymanie", "SilentHold", nil, "Cel aktywny wyłącznie przy trzymaniu klawisza")
		UI:Toggle(p, "Koło FOV", "CircleOn", nil, "Rysuje stożek na ekranie")
		UI:Dropdown(p, "Styl koła", "CircleStyle", { "Cienkie", "Grube", "Kropkowane" }, nil, "Wygląd znacznika FOV")
		UI:Color(p, "Kolor koła", "ColorCircle", "Kolor znacznika FOV")
		UI:Toggle(p, "Wizualizacja celu", "SilentViz", nil, "Ramka i linia do wybranego celu")
		UI:Toggle(p, "Pierścień blokady", "LockRing", nil, "Pulsujący okrąg na celu")

		UI:Section(p, "Aimbot")
		UI:Toggle(p, "Aimbot", "Aimbot", function(on) if on then AB:Start() else AB:Stop() end end, "Prowadzi kamerę za celem")
		UI:Dropdown(p, "Tryb", "AimbotMode", { "Hold", "Zawsze" }, nil, "Hold = tylko z klawiszem")
		UI:Dropdown(p, "Styl", "AimbotStyle", { "Wykładniczy", "Liniowy", "Snap" }, nil, "Krzywa dochodzenia do celu")
		UI:Slider(p, "Płynność", "AimbotSmooth", 0.01, 1, 0.01, "", nil, "Niżej = szybciej")
		UI:Slider(p, "Humanizacja", "AimbotHumanize", 0, 2, 0.05, "", nil, "Delikatne drżenie jak u człowieka")
		UI:Slider(p, "Predykcja", "AimbotPredict", 0, 0.6, 0.01, " s", nil, "Wyprzedzenie ruchu celu")
		UI:Slider(p, "FOV", "AimbotFOV", 10, 400, 5, " px", nil, "Stożek aimbota")
		UI:Slider(p, "Zasięg", "AimbotRange", 50, 3000, 25, " st", nil, "Maksymalna odległość celu")
		UI:Dropdown(p, "Punkt celowania", "AimbotPart", { "Head", "UpperTorso", "HumanoidRootPart", "Blisko" }, nil, "W co celuje kamera")
		UI:Toggle(p, "Tylko widoczni", "AimbotVisible", nil, "Pomija cele za ścianami")
		UI:Toggle(p, "Lepki cel", "AimbotSticky", nil, "Trzyma wybrany cel, dopóki nie ucieknie")

		UI:Section(p, "Trigger Bot")
		UI:Toggle(p, "Trigger Bot", "TriggerBot", function(on) if on then TG:Start() else TG:Stop() end end, "Strzela sam, gdy cel jest widoczny")
		UI:Slider(p, "Opóźnienie", "TriggerDelay", 0.01, 0.5, 0.01, " s", nil, "Odstęp między strzałami")
	end)

	tab("Visuals", "✦", function(p)
		UI:Section(p, "ESP")
		UI:Toggle(p, "ESP", "ESP", function(on) if on then ESP:Start() else ESP:Stop() end end, "Główny przełącznik nakładek")
		UI:Dropdown(p, "Styl boxa", "ESPBoxStyle", { "Pełny", "Narożniki", "Wypełniony" }, nil, "Kształt ramki")
		UI:Toggle(p, "Box", "ESPBox", nil, "Ramka wokół gracza")
		UI:Toggle(p, "Szkielet", "ESPSkeleton", nil, "Linie kości")
		UI:Toggle(p, "Nazwa", "ESPName", nil, "Pseudonim nad graczem")
		UI:Toggle(p, "Dystans", "ESPDistance", nil, "Odległość w metrach")
		UI:Toggle(p, "Pasek HP", "ESPHealth", nil, "Pionowy pasek zdrowia")
		UI:Toggle(p, "Liczba HP", "ESPHealthText", nil, "Wartość zdrowia liczbowo")
		UI:Toggle(p, "Kolor od HP", "ESPHealthColor", nil, "Nazwa zmienia kolor wraz ze zdrowiem")
		UI:Toggle(p, "Kropka na głowie", "ESPHeadDot", nil, "Znacznik głowy")
		UI:Toggle(p, "Tracer", "ESPTracer", nil, "Linia od dołu ekranu")
		UI:Toggle(p, "Strzałki poza ekranem", "ESPArrows", nil, "Wskaźnik dla celów poza kadrem")
		UI:Toggle(p, "Chams", "ESPChams", nil, "Podświetlenie sylwetki")
		UI:Toggle(p, "Tęcza", "ESPRainbow", nil, "Cykl kolorów")
		UI:Slider(p, "Krycie", "ESPAlpha", 0.2, 1, 0.05, "", nil, "Przezroczystość nakładek")
		UI:Slider(p, "Skala tekstu", "ESPTextScale", 0.6, 1.8, 0.1, "x", nil, "Rozmiar napisów")
		UI:Slider(p, "Maks. dystans", "ESPMaxDist", 100, 5000, 50, " st", nil, "Powyżej tego dystansu ESP milczy")
		UI:Toggle(p, "Team Check", "ESPTeamCheck", nil, "Pomija drużynę")
		UI:Section(p, "Kolory")
		UI:Color(p, "Wróg", "ColorEnemy")
		UI:Color(p, "Sojusznik", "ColorTeam")
		UI:Color(p, "Szkielet", "ColorSkel")
		UI:Color(p, "Tracer", "ColorTracer")
	end)

	tab("World", "◈", function(p)
		UI:Section(p, "Wallhack")
		UI:Toggle(p, "Wallhack", "Wallhack", function(on) if on then World:Start() else World:Stop() end end, "Podświetla obiekty przez ściany")
		UI:Toggle(p, "Gracze", "WHPlayers")
		UI:Toggle(p, "Boty / NPC", "WHBots")
		UI:Toggle(p, "Obiekty", "WHObjects")
		UI:Dropdown(p, "Widoczność", "WHDepth", { "Zawsze", "Zasłonięte" }, nil, "Zawsze = także przez ściany")
		UI:Slider(p, "Wypełnienie", "WHFill", 0, 1, 0.05, "")
		UI:Slider(p, "Obrys", "WHOutline", 0, 1, 0.05, "")
		UI:Color(p, "Kolor", "ColorWH")
		UI:Section(p, "Światło")
		UI:Toggle(p, "Fullbright", "Fullbright", function() World:Light() end, "Rozjaśnia mapę")
		UI:Toggle(p, "Bez mgły", "NoFog", function() World:Light() end, "Usuwa mgłę")
		UI:Slider(p, "Godzina", "ClockTime", 0, 24, 0.5, "h", function() World:Light() end, "Pora dnia")
		UI:Section(p, "Kamera")
		UI:Slider(p, "FOV kamery", "CamFOV", 40, 120, 1, "", function() World:FOV() end, "Pole widzenia")
		UI:Section(p, "Crosshair")
		UI:Toggle(p, "Własny crosshair", "Crosshair")
		UI:Dropdown(p, "Styl", "CrosshairStyle", { "Krzyż", "X" })
		UI:Color(p, "Kolor", "ColorCross")
	end)

	tab("Hitbox", "⬚", function(p)
		UI:Section(p, "Hitbox Editor")
		UI:Toggle(p, "Hitbox", "Hitbox", function(on)
			HB:Refresh()
			if on then Cfg.Set("HitboxPreview", true) end
		end, "Powiększa części ciała lokalnie")
		UI:Slider(p, "Szerokość", "HitboxW", 0.5, 20, 0.5, "", function() HB:Refresh() end)
		UI:Slider(p, "Wysokość", "HitboxH", 0.5, 20, 0.5, "", function() HB:Refresh() end)
		UI:Slider(p, "Głębokość", "HitboxD", 0.5, 20, 0.5, "", function() HB:Refresh() end)
		UI:Slider(p, "Mnożnik głowy", "HitboxHeadMul", 1, 4, 0.25, "x", function() HB:Refresh() end, "Dodatkowe powiększenie samej głowy")
		UI:Toggle(p, "Podgląd", "HitboxPreview", nil, "Ramki na zmienionych częściach")
		UI:Section(p, "Części")
		for _, n in ipairs({ "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }) do
			local row = UI:Card(p, 30, nil, n)
			U.New("TextLabel", {
				Size = UDim2.new(1, -42, 1, 0), Position = UDim2.fromOffset(13, 0),
				BackgroundTransparency = 1, Text = n, Font = Enum.Font.GothamMedium,
				TextSize = 12, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
			}, row)
			local on = table.find(Cfg.Get("HitboxParts"), n) ~= nil
			local b = U.New("TextButton", {
				Size = UDim2.fromOffset(26, 20), Position = UDim2.new(1, -38, 0.5, -10),
				BackgroundColor3 = on and TH.AccD or TH.Hover, Text = on and "✓" or "",
				Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TH.Acc,
				AutoButtonColor = false, BorderSizePixel = 0,
			}, row)
			U.Corner(b, 6)
			b.MouseButton1Click:Connect(function()
				local list = table.clone(Cfg.Get("HitboxParts"))
				local i = table.find(list, n)
				if i then table.remove(list, i) else table.insert(list, n) end
				Cfg.Set("HitboxParts", list)
				b.BackgroundColor3 = i and TH.Hover or TH.AccD
				b.Text = i and "" or "✓"
				HB:Refresh()
			end)
		end
		UI:Section(p, "Presety")
		UI:Button(p, "Tylko głowa", function()
			Cfg.Set("HitboxParts", { "Head" })
			Cfg.Set("HitboxW", 6) Cfg.Set("HitboxH", 6) Cfg.Set("HitboxD", 6)
			Cfg.Set("Hitbox", true)
			HB:Refresh()
			UI:Toast("Hitbox", "Preset głowy aktywny")
		end)
		UI:Button(p, "Przywróć domyślne", function()
			Cfg.Set("HitboxW", 4) Cfg.Set("HitboxH", 6) Cfg.Set("HitboxD", 4) Cfg.Set("Hitbox", false)
			HB:Refresh()
		end)
	end)

	tab("Fun", "☺", function(p)
		UI:Section(p, "Zabawki")
		UI:Toggle(p, "Tęcza wszędzie", "ESPRainbow")
		UI:Toggle(p, "Wielkie głowy", "BigHead", function(on) Fun:BigHead(on) end, "Powiększa głowy wszystkich")
		UI:Button(p, "Trzęsienie kamery", function() Fun:Shake() end, false, "Krótki wstrząs")
		UI:Button(p, "Obrót kamery", function() Fun:SpinToggle() end, false, "Włącz / wyłącz wirowanie")
		UI:Button(p, "Losowa zaczepka na czacie", function() Fun:Taunt() end, false, "Wysyła tekst na czat")
		UI:Button(p, "Disco (światło)", function()
			Fun:Disco(not Cfg.Get("Disco"))
			UI:Toast("Disco", Cfg.Get("Disco") and "Włączone" or "Wyłączone")
		end)
		UI:Button(p, "Konfetti", function()
			local e = { "✦", "★", "✧", "☆", "✶", "✷" }
			for i = 1, 12 do
				UI:Toast(e[math.random(1, #e)] .. " konfetti", "Ugotowane przez Pstryczka", i % 3 == 0)
				task.wait(0.07)
			end
		end)
	end)

	tab("Config", "⚙", function(p)
		UI:Section(p, "Ustawienia")
		UI:Button(p, "Zapisz konfigurację", function() Cfg.Save() UI:Toast("Konfiguracja", "Zapisano") end)
		UI:Button(p, "Wczytaj konfigurację", function()
			local d = Store.Load()
			if not d then UI:Toast("Konfiguracja", "Brak zapisu", true) return end
			Cfg.Apply(d)
			HB:Refresh() World:Light() applyAccent()
			UI:Toast("Konfiguracja", "Wczytano")
		end)
		UI:Button(p, "Reset", function()
			Cfg.Reset() HB:Refresh() World:Light() applyAccent()
			UI:Toast("Konfiguracja", "Przywrócono domyślne")
		end, true)

		UI:Section(p, "Profile")
		for _, slot in ipairs({ "A", "B", "C" }) do
			local row = UI:Card(p, 32, nil, "Profil " .. slot)
			U.New("TextLabel", {
				Size = UDim2.fromOffset(80, 32), Position = UDim2.fromOffset(13, 0),
				BackgroundTransparency = 1, Text = "Profil " .. slot, Font = Enum.Font.GothamMedium,
				TextSize = 12, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
			}, row)
			local sb = U.New("TextButton", {
				Size = UDim2.fromOffset(54, 22), Position = UDim2.new(1, -118, 0.5, -11),
				BackgroundColor3 = TH.Hover, Text = "zapisz", Font = Enum.Font.GothamBold,
				TextSize = 10, TextColor3 = TH.Acc, AutoButtonColor = false, BorderSizePixel = 0,
			}, row)
			U.Corner(sb, 6)
			sb.MouseButton1Click:Connect(function()
				Store.SaveTo(FILE .. ".prof" .. slot, data)
				UI:Toast("Profil " .. slot, "Zapisano")
			end)
			local lb = U.New("TextButton", {
				Size = UDim2.fromOffset(54, 22), Position = UDim2.new(1, -60, 0.5, -11),
				BackgroundColor3 = TH.Hover, Text = "wczytaj", Font = Enum.Font.GothamBold,
				TextSize = 10, TextColor3 = TH.Text, AutoButtonColor = false, BorderSizePixel = 0,
			}, row)
			U.Corner(lb, 6)
			lb.MouseButton1Click:Connect(function()
				local d = Store.LoadFrom(FILE .. ".prof" .. slot)
				if not d then UI:Toast("Profil " .. slot, "Pusty", true) return end
				Cfg.Apply(d)
				HB:Refresh() World:Light() applyAccent()
				UI:Toast("Profil " .. slot, "Wczytano")
			end)
		end

		UI:Section(p, "Wygląd")
		UI:Color(p, "Kolor akcentu", "ColorAccent", "Kolor całego motywu")
		UI:Slider(p, "Skala UI", "UIScale", 0.8, 1.25, 0.05, "x", function(v)
			local s = UI.Main:FindFirstChildOfClass("UIScale")
			if s then s.Scale = v end
		end, "Wielkość interfejsu")
		UI:Toggle(p, "Watermark", "ShowWM")
		UI:Toggle(p, "Powiadomienia", "ShowToast")
		UI:Button(p, "Wyśrodkuj okno", function()
			UI.Main.Position = UDim2.new(0.5, -UI.Main.AbsoluteSize.X / 2, 0.5, -UI.Main.AbsoluteSize.Y / 2)
			Cfg.Set("WinSet", false)
		end)

		UI:Section(p, "Eksport / import")
		local box = U.New("TextBox", {
			Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = TH.Card, Text = Cfg.Get("ExportStr"),
			PlaceholderText = "wklej tutaj string konfiguracji", PlaceholderColor3 = TH.Dim,
			Font = Enum.Font.Code, TextSize = 10, TextColor3 = TH.Text,
			TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0,
		}, p)
		U.Corner(box, 8)
		UI:Button(p, "Wyeksportuj do pola", function()
			local ok, enc = pcall(function() return Http:JSONEncode(data) end)
			if ok then
				box.Text = enc
				Cfg.Set("ExportStr", enc)
				if Clipboard then pcall(Clipboard, enc) UI:Toast("Eksport", "Skopiowano do schowka") end
			end
		end)
		UI:Button(p, "Importuj z pola", function()
			local ok, dec = pcall(function() return Http:JSONDecode(box.Text) end)
			if not ok or type(dec) ~= "table" then UI:Toast("Import", "Nieprawidłowy string", true) return end
			Cfg.Apply(dec)
			HB:Refresh() World:Light() applyAccent()
			UI:Toast("Import", "Zaimportowano")
		end)

		UI:Section(p, "Wydajność")
		UI:Toggle(p, "Tryb wydajności (40 Hz)", "PerfMode", nil, "Stałe ograniczenie odświeżania ESP")
		UI:Toggle(p, "Auto wydajność", "AutoPerf", nil, "Sam zwalnia przy spadku FPS")
		UI:Section(p, "Klawisze")
		UI:Keybind(p, "Otwórz / zamknij GUI", "UIKey")
		UI:Keybind(p, "Silent Aim (hold)", "AimKey")
		UI:Keybind(p, "Aimbot (hold)", "AimbotKey")
		UI:Keybind(p, "Wyładuj skrypt", "UnloadKey")

		UI:Section(p, "Znajomi")
		local pl = U.New("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, p)
		local pll = Instance.new("UIListLayout")
		pll.Padding = UDim.new(0, 4)
		pll.Parent = pl
		pll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			pl.Size = UDim2.new(1, 0, 0, pll.AbsoluteContentSize.Y)
		end)
		task.spawn(function()
			while CS.Alive do
				for _, ch in ipairs(pl:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
				for _, p2 in ipairs(Players:GetPlayers()) do
					if p2 ~= LP then
						local fr = T.Friend(p2)
						local b = U.New("TextButton", {
							Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = fr and TH.AccD or TH.Card,
							Text = "  " .. (fr and "★  " or "☆  ") .. p2.Name,
							Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = fr and TH.Acc or TH.Dim,
							TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0,
						}, pl)
						U.Corner(b, 7)
						b.MouseButton1Click:Connect(function()
							local list = table.clone(Cfg.Get("Friends"))
							local i = table.find(list, p2.UserId)
							if i then table.remove(list, i) else table.insert(list, p2.UserId) end
							Cfg.Set("Friends", list)
							b.BackgroundColor3 = i and TH.Card or TH.AccD
							b.TextColor3 = i and TH.Dim or TH.Acc
							b.Text = "  " .. (i and "☆  " or "★  ") .. p2.Name
						end)
					end
				end
				task.wait(2)
			end
		end)
	end)

	tab("Diag", "◎", function(p)
		UI:Section(p, "Stan środowiska")
		UI:Label(p, "Sprawdza, co executor realnie potrafi. Czerwone pola to brak funkcji.", true)
		local holder = U.New("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, p)
		local hl = Instance.new("UIListLayout")
		hl.Padding = UDim.new(0, 4)
		hl.Parent = holder
		hl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			holder.Size = UDim2.new(1, 0, 0, hl.AbsoluteContentSize.Y)
		end)
		Diag.Holder = holder
		UI:Button(p, "Uruchom test", function() Diag:Run() end)
		UI:Button(p, "Kopiuj log", function()
			local txt = table.concat(CS.Log, "\n")
			if Clipboard then pcall(Clipboard, txt) UI:Toast("Log", "Skopiowano") end
		end)
		UI:Button(p, "Odśwież GUI", function()
			if UI.Gui then UI.Gui:Destroy() end
			UI.Tabs = {} UI.Ref = {} UI.Search = {}
			build()
		end)
		task.delay(0.3, function() pcall(Diag.Run, Diag) end)
	end)

	tab("Info", "ℹ", function(p)
		UI:Section(p, "CHEŁMSKI SIEKATOR V" .. CS.Version)
		UI:Label(p, "Ugotowane przez Pstryczka", true)
		UI:Label(p, "Silent Aim przechwytuje Mouse.Hit, Mouse.UnitRay, Mouse.Target i Camera.CFrame.")
		UI:Label(p, "Brak hooków? Aimbot nadal pracuje na kamerze.")
		UI:Label(p, "ESP używa Drawing, a bez niego renderera Frame — działa wszędzie.")
		UI:Label(p, "Okno przeciągasz za nagłówek, rozciągasz za róg, dwuklik nagłówka centruje.")
		UI:Section(p, "Skróty domyślne")
		UI:Label(p, "RightShift — GUI · E — silent aim · X — aimbot · Delete — wyładuj", true)
		UI:Button(p, "Wyładuj skrypt", function() CS:Destroy() end, true)
		UI:Section(p, "Podpis")
		UI:Label(p, "Ugotowane przez Pstryczka — v" .. CS.Version, true)
	end)

	if UI.Tabs[1] then UI:Select(UI.Tabs[1]) end
end

--==========================================================
-- 23. CYKL
--==========================================================
function CS:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.Alive = false
	CS.Signal.Unload:Fire()
	pcall(Cfg.Save)

	for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
	self.Conns = {}

	pcall(function() AB:Stop() end)
	pcall(function() ESP:Stop() end)
	pcall(function() World:Stop() end)
	pcall(function() TG:Stop() end)
	pcall(function() Chams:Clear() end)
	pcall(function() Fun:Disco(false) end)
	pcall(function() Fun.Spin = false end)
	pcall(function()
		for p, o in pairs(HB.Orig) do
			if p and p.Parent then
				p.Size = o.Size
				p.CanCollide = o.Collide
			end
		end
	end)
	pcall(Draw.Purge)
	if UI.Gui then pcall(function() UI.Gui:Destroy() end) end
	getgenv().CHELMSKI = nil
end

function CS:Start()
	if not LP then error("brak LocalPlayer") end
	if not Camera then error("brak CurrentCamera") end

	CS:Note("start v" .. CS.Version)

	Draw.Init()
	OV:Init()
	HB:Init()

	if Cfg.Get("ESP") then ESP:Start() end
	if Cfg.Get("Aimbot") then AB:Start() end
	if Cfg.Get("Wallhack") then World:Start() end
	if Cfg.Get("TriggerBot") then TG:Start() end
	if Cfg.Get("Fullbright") or Cfg.Get("NoFog") then World:Light() end

	local okb, errb = pcall(build)
	if not okb then
		CS:Note("build: " .. tostring(errb))
		warn("[SIEKATOR] build: " .. tostring(errb))
	end
	CS.Ready = true

	CS.Signal.Changed:Connect(function(k)
		if k == "__all__" then
			for _, fn in pairs(UI.Ref) do pcall(fn) end
			return
		end
		if k == "ColorAccent" then pcall(applyAccent) end
		local fn = UI.Ref[k]
		if fn then pcall(fn) end
	end)

	local frames, acc = 0, 0
	U.Track(RunService.RenderStepped:Connect(function(dt)
		if not self.Alive then return end
		frames += 1
		acc += dt
		if acc >= 0.5 then CS.FPS = frames / acc frames, acc = 0, 0 end
		pcall(SA.Update, SA)
		pcall(OV.Step, OV)
		pcall(WM.Step, WM)
	end))

	U.Track(task.spawn(function()
		while self.Alive do
			pcall(HB.PreviewStep, HB)
			pcall(Chams.Step, Chams)
			task.wait(0.15)
		end
	end))

	U.Track(task.spawn(function()
		while self.Alive do
			if Workspace.CurrentCamera and Workspace.CurrentCamera ~= Camera then
				Camera = Workspace.CurrentCamera
				if Cfg.Get("CamFOV") ~= 70 then World:FOV() end
			end
			task.wait(0.5)
		end
	end))

	U.Track(Input.InputBegan:Connect(function(i, processed)
		if processed or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local n = i.KeyCode.Name
		if n == Cfg.Get("UIKey") then UI:ToggleOpen()
		elseif n == Cfg.Get("AimKey") then SA.KeyDown = true
		elseif n == Cfg.Get("AimbotKey") then AB.KeyDown = true
		elseif n == Cfg.Get("UnloadKey") then CS:Destroy() end
	end))

	U.Track(Input.InputEnded:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local n = i.KeyCode.Name
		if n == Cfg.Get("AimKey") then SA.KeyDown = false
		elseif n == Cfg.Get("AimbotKey") then AB.KeyDown = false end
	end))

	U.Track(Players.PlayerRemoving:Connect(function(p)
		task.defer(function() if ESP.Pool[p] then ESP:Drop(p) end end)
	end))

	U.Track(game:BindToClose(function() pcall(Cfg.Save) end))

	UI:Toast("CHEŁMSKI SIEKATOR", "Ugotowane przez Pstryczka · " .. Cfg.Get("UIKey"))
end

--==========================================================
-- 24. START
--==========================================================
getgenv().CHELMSKI = CS

local ok, err = xpcall(function() return CS:Start() end, function(e)
	return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)

if not ok then
	fatal(err)
	getgenv().CHELMSKI = nil
end

return CS
