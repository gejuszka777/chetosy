--[[
	CHEŁMSKI SIEKATOR V5 — HARDENED
	Roblox Luau PvP toolkit (client / executor)
	Uruchomienie:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/gejuszka777/chetosy/main/chetosy.lua?v=5"))()
]]

--==========================================================
-- 0. GUARD + ZALEŻNOŚCI MIĘKKIE
--==========================================================
if getgenv().CHELMSKI then
	pcall(function() getgenv().CHELMSKI:Destroy() end)
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tween      = game:GetService("TweenService")
local Input      = game:GetService("UserInputService")
local Http       = game:GetService("HttpService")
local Workspace  = game:GetService("Workspace")
local Lighting   = game:GetService("Lighting")
local CoreGui    = game:GetService("CoreGui")
local Stats      = game:GetService("Stats")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LP:GetMouse()

local newcclosure = newcclosure or function(f) return f end
local cloneref = cloneref or function(o) return o end
local gethui = gethui or function() return CoreGui end
local writefile = writefile
local readfile = readfile

local CS = {
	Version = "5.0",
	Alive = true,
	Destroyed = false,
	Conns = {},
	FPS = 60,
}
CS.__index = CS

--==========================================================
-- 1. UTIL
--==========================================================
local U = {}

function U.New(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then i[k] = v end
	end
	if parent then i.Parent = parent end
	return i
end

function U.Corner(i, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = i
	return c
end

function U.Stroke(i, c, t, tr)
	local s = Instance.new("UIStroke")
	s.Color = c or Color3.new(1, 1, 1)
	s.Thickness = t or 1
	s.Transparency = tr or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = i
	return s
end

function U.Tween(i, t, p, style, dir)
	local ti = TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local tw = Tween:Create(i, ti, p)
	tw:Play()
	return tw
end

function U.Round(n, step)
	if not step or step <= 0 then return n end
	return math.floor(n / step + 0.5) * step
end

function U.Alive(char)
	if not char then return false end
	local h = char:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

function U.Track(c)
	table.insert(CS.Conns, c)
	return c
end

function U.Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[SIEKATOR] " .. tostring(err))
	end
	return ok
end

function U.Col(t)
	if type(t) ~= "table" then return Color3.fromRGB(61, 255, 158) end
	return Color3.fromRGB(t[1] or 61, t[2] or 255, t[3] or 158)
end

U.Lerp = function(a, b, t) return a + (b - a) * t end

--==========================================================
-- 2. SIGNAL
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
	for _, fn in ipairs(table.clone(self._h)) do
		task.spawn(fn, ...)
	end
end

CS.Signal = { Changed = Signal.new(), Unload = Signal.new() }

--==========================================================
-- 3. STORAGE
--==========================================================
local FILE = "ChelmskiSiekatorV5.json"
local Store = {}

function Store.Save(data)
	if not writefile then
		getgenv().CHELMSKI_CFG = data
		return
	end
	local ok, enc = pcall(Http.JSONEncode, Http, data)
	if ok then pcall(writefile, FILE, enc) end
end

function Store.Load()
	if readfile then
		local ok, raw = pcall(readfile, FILE)
		if ok and raw and raw ~= "" then
			local ok2, dec = pcall(Http.JSONDecode, Http, raw)
			if ok2 and type(dec) == "table" then return dec end
		end
	end
	return getgenv().CHELMSKI_CFG
end

--==========================================================
-- 4. CONFIG
--==========================================================
local DEF = {
	SilentAim = false, SilentFOV = 150, SilentRange = 900, SilentPart = "Head",
	SilentChance = 100, SilentVisible = false, SilentHold = false, SilentViz = true,
	CircleOn = true, CircleStyle = "Cienkie",
	Aimbot = false, AimbotMode = "Hold", AimbotSmooth = 0.18, AimbotStyle = "Wykładniczy",
	AimbotFOV = 120, AimbotRange = 900, AimbotPart = "Head", AimbotVisible = true,
	AimbotHumanize = 0.15,
	ESP = false, ESPBox = true, ESPBoxStyle = "Pełny", ESPSkeleton = true, ESPName = true,
	ESPDistance = true, ESPHealth = true, ESPTracer = false, ESPHeadDot = false,
	ESPArrows = true, ESPAlpha = 1, ESPMaxDist = 1500, ESPTeamCheck = true,
	ColorEnemy = { 61, 255, 158 }, ColorTeam = { 90, 170, 255 },
	ColorSkel = { 255, 255, 255 }, ColorTracer = { 61, 255, 158 },
	Wallhack = false, WHPlayers = true, WHBots = true, WHObjects = false,
	WHFill = 0.55, WHDepth = "Zawsze", ColorWH = { 61, 255, 158 },
	Fullbright = false, NoFog = false, Crosshair = false, CrosshairStyle = "Krzyż",
	ColorCross = { 61, 255, 158 }, CamFOV = 70,
	Hitbox = false, HitboxW = 4, HitboxH = 6, HitboxD = 4, HitboxPreview = true,
	HitboxParts = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
	PerfMode = false, Friends = {},
	UIKey = "RightShift", AimKey = "E", AimbotKey = "X", UnloadKey = "Delete",
}

local Cfg = {}
local data = {}

for k, v in pairs(DEF) do
	data[k] = type(v) == "table" and table.clone(v) or v
end

do
	local saved = Store.Load()
	if type(saved) == "table" then
		for k, v in pairs(saved) do
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
	for k, v in pairs(DEF) do
		data[k] = type(v) == "table" and table.clone(v) or v
	end
	CS.Signal.Changed:Fire("__all__", nil)
end
function Cfg.Save() Store.Save(data) end
function Cfg.Raw() return table.clone(data) end

CS.Cfg = Cfg

--==========================================================
-- 5. DRAW — DWÓCH BACKENDÓW
--==========================================================
local Draw = { Has = false, Layer = nil, Pool = {} }

pcall(function()
	Draw.Has = type(Drawing) == "table" and type(Drawing.new) == "function"
	local probe = Drawing.new("Square")
	probe:Remove()
end)

local AP = {}

local function apply(o, k, v)
	local i = o.Inst
	if k == "Visible" then i.Visible = v
	elseif k == "Position" then
		i.Position = UDim2.fromOffset(v.X, v.Y)
	elseif k == "Size" then
		i.Size = UDim2.fromOffset(math.max(v.X, 0), math.max(v.Y, 0))
	elseif k == "Color" then
		if o.Kind == "Text" then i.TextColor3 = v else i.BackgroundColor3 = v end
		if o.Stroke then o.Stroke.Color = v end
	elseif k == "Transparency" then
		if o.Kind == "Text" then i.TextTransparency = v else i.BackgroundTransparency = v end
		if o.Stroke then o.Stroke.Transparency = v end
	elseif k == "Filled" then
		if o.Kind == "Square" then
			i.BackgroundTransparency = v and 0.35 or 1
			if o.Stroke then o.Stroke.Transparency = v and 1 or 0 end
		end
	elseif k == "Thickness" then
		if o.Stroke then o.Stroke.Thickness = v end
	elseif k == "Text" then
		i.Text = v
	elseif k == "Center" then
		i.TextXAlignment = v and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	elseif k == "Outline" then
		i.TextStrokeTransparency = v and 0 or 1
	elseif k == "Radius" then
		local p = o.P.Get
		i.Position = UDim2.fromOffset(p.X - v, p.Y - v)
		i.Size = UDim2.fromOffset(v * 2, v * 2)
	elseif k == "From" or k == "To" then
		local f = o.P.From or Vector2.new()
		local t = o.P.To or Vector2.new()
		if k == "From" then f = v else t = v end
		local d = t - f
		local mag = d.Magnitude
		i.Position = UDim2.fromOffset(f.X, f.Y)
		i.Size = UDim2.fromOffset(math.max(mag, 0), o.P.Thickness or 1)
		i.Rotation = math.deg(math.atan2(d.Y, d.X))
	end
	o.P.Get[k] = v
end

local MT = {
	__index = function(t, k)
		if k == "Remove" then
			return function(self)
				if self.Inst then self.Inst:Destroy() end
				self.Inst = nil
			end
		end
		if k == "P" then return rawget(t, "Props") end
		return rawget(t, "Props")[k]
	end,
	__newindex = function(t, k, v)
		if rawget(t, "Inst") then apply(t, k, v) else rawget(t, "Props")[k] = v end
	end,
}

local function frameObject(kind)
	local i
	local o = { Kind = kind, Props = {}, Inst = nil }

	if kind == "Text" then
		i = Instance.new("TextLabel")
		i.BackgroundTransparency = 1
		i.Font = Enum.Font.GothamBold
		i.TextSize = 13
		i.Text = ""
		i.Size = UDim2.fromOffset(200, 16)
		i.AnchorPoint = Vector2.new(0.5, 0)
		i.TextXAlignment = Enum.TextXAlignment.Center
		i.TextStrokeTransparency = 0
		i.TextStrokeColor3 = Color3.new(0, 0, 0)
	elseif kind == "Line" then
		i = Instance.new("Frame")
		i.BorderSizePixel = 0
		i.AnchorPoint = Vector2.new(0, 0.5)
		i.BackgroundTransparency = 0
	else
		i = Instance.new("Frame")
		i.BorderSizePixel = 0
		i.BackgroundTransparency = 1
		if kind == "Square" then
			o.Stroke = U.Stroke(i, Color3.new(1, 1, 1), 1, 0)
		elseif kind == "Circle" then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = i
			o.Stroke = U.Stroke(i, Color3.new(1, 1, 1), 1, 0)
		end
	end

	i.Visible = false
	i.Parent = Draw.Layer
	o.Inst = i
	return setmetatable(o, MT)
end

function Draw.Init()
	if Draw.Has then return end
	local g = Instance.new("ScreenGui")
	g.Name = "ChelmskiSiekatorV5_Draw"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 9990
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local ok = pcall(function() g.Parent = gethui() end)
	if not ok then g.Parent = LP:WaitForChild("PlayerGui") end
	Draw.Layer = g
end

function Draw.New(kind, props)
	local o
	if Draw.Has then
		local ok, d = pcall(Drawing.new, kind)
		if ok and d then o = d end
	end
	if not o then
		if not Draw.Layer then Draw.Init() end
		o = frameObject(kind)
	end
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	table.insert(Draw.Pool, o)
	return o
end

function Draw.Purge()
	for _, o in ipairs(Draw.Pool) do
		pcall(function() o:Remove() end)
	end
	Draw.Pool = {}
end

--==========================================================
-- 6. TARGETING
--==========================================================
local T = {}

local CHAIN = {
	Head = { "Head" },
	HumanoidRootPart = { "HumanoidRootPart" },
	UpperTorso = { "UpperTorso", "Torso", "HumanoidRootPart" },
	Blisko = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
}

function T.Part(char, mode)
	if not char then return nil end
	if mode == "Blisko" then
		local best, bd, cp = nil, nil, Camera.CFrame.Position
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				local dist = (d.Position - cp).Magnitude
				if not bd or dist < bd then best, bd = d, dist end
			end
		end
		return best
	end
	for _, n in ipairs(CHAIN[mode] or CHAIN.Head) do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
	return nil
end

local rp = RaycastParams.new()
rp.FilterType = (Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist)

function T.Visible(part)
	if not part then return false end
	rp.FilterDescendantsInstances = { LP.Character, part.Parent }
	local hit = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
	return hit == nil or hit.Instance:IsDescendantOf(part.Parent)
end

function T.IsFriend(plr)
	return table.find(Cfg.Get("Friends"), plr.UserId) ~= nil
end

function T.Best(o)
	local best, bs
	local cp = Camera.CFrame.Position
	local vp = Camera.ViewportSize
	local mid = Vector2.new(vp.X / 2, vp.Y / 2)
	local myTeam = LP.Team

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local char = plr.Character
			if U.Alive(char)
				and not (o.teamCheck and plr.Team == myTeam)
				and not (o.ignoreFriends and T.IsFriend(plr)) then
				local part = T.Part(char, o.part)
				if part then
					local dist = (part.Position - cp).Magnitude
					if dist <= o.range then
						local s, on = Camera:WorldToViewportPoint(part.Position)
						if on and s.Z > 0 then
							local fd = (Vector2.new(s.X, s.Y) - mid).Magnitude
							if fd <= o.fov then
								local score = fd + dist * 0.04
								if o.visible and not T.Visible(part) then score += 400 end
								if not bs or score < bs then
									best, bs = { Player = plr, Part = part, Dist = dist }, score
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

--==========================================================
-- 7. SILENT AIM
--==========================================================
local SA = { Target = nil, Busy = false, Hooked = false, Rolled = false, KeyDown = false }

function SA:Cfg()
	return {
		fov = Cfg.Get("SilentFOV"),
		range = Cfg.Get("SilentRange"),
		part = Cfg.Get("SilentPart"),
		visible = Cfg.Get("SilentVisible"),
		teamCheck = Cfg.Get("ESPTeamCheck"),
		ignoreFriends = true,
	}
end

function SA:Update()
	if not Cfg.Get("SilentAim") or (Cfg.Get("SilentHold") and not self.KeyDown) then
		self.Target = nil
		return
	end
	local t = T.Best(self:Cfg())
	if t then
		if not self.Rolled then
			self.Rolled = math.random(1, 100) <= Cfg.Get("SilentChance")
		end
		if not self.Rolled then t = nil end
	else
		self.Rolled = false
	end
	self.Target = t
end

function SA:Handler(raw)
	return newcclosure(function(self, key)
		local t = SA.Target
		if t and t.Part and t.Part.Parent and not SA.Busy then
			if self == Mouse then
				if key == "Hit" then
					return CFrame.new(t.Part.Position)
				elseif key == "Target" then
					return t.Part.Parent
				elseif key == "UnitRay" then
					local o = raw(Camera, "CFrame").Position
					return Ray.new(o, (t.Part.Position - o).Unit * 2048)
				end
			elseif self == Camera and key == "CFrame" then
				local b = raw(Camera, "CFrame")
				return CFrame.lookAt(b.Position, t.Part.Position)
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
			return true
		end
	end

	return false
end

--==========================================================
-- 8. AIMBOT
--==========================================================
local AB = { Conn = nil, Target = nil, KeyDown = false, Jitter = Vector2.new() }

function AB:Step(dt)
	local mode = Cfg.Get("AimbotMode")
	if not Cfg.Get("Aimbot") or (mode == "Hold" and not self.KeyDown) then
		self.Target = nil
		return
	end

	local t = T.Best({
		fov = Cfg.Get("AimbotFOV"),
		range = Cfg.Get("AimbotRange"),
		part = Cfg.Get("AimbotPart"),
		visible = Cfg.Get("AimbotVisible"),
		teamCheck = Cfg.Get("ESPTeamCheck"),
		ignoreFriends = true,
	})
	self.Target = t
	if not t then return end

	local hum = Cfg.Get("AimbotHumanize")
	if hum > 0 and math.random() < 0.15 then
		local a = math.random() * math.pi * 2
		self.Jitter = Vector2.new(math.cos(a), math.sin(a)) * hum
	end

	local goal = CFrame.lookAt(Camera.CFrame.Position, t.Part.Position)
		* CFrame.Angles(math.rad(self.Jitter.Y * 0.4), math.rad(self.Jitter.X * 0.4), 0)

	local smooth = math.clamp(Cfg.Get("AimbotSmooth"), 0.005, 1)
	local alpha
	if Cfg.Get("AimbotStyle") == "Liniowy" then
		alpha = math.clamp(dt / smooth, 0, 1)
	elseif Cfg.Get("AimbotStyle") == "Snap" then
		alpha = 1
	else
		alpha = 1 - math.exp(-dt / smooth * 6)
	end

	SA.Busy = true
	Camera.CFrame = Camera.CFrame:Lerp(goal, alpha)
	SA.Busy = false
end

function AB:Start()
	if self.Conn then return end
	self.Conn = U.Track(RunService.RenderStepped:Connect(function(dt)
		U.Safe(AB.Step, AB, dt)
	end))
end

function AB:Stop()
	if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
	self.Target = nil
end

--==========================================================
-- 9. ESP
--==========================================================
local ESP = { Pool = {}, Conn = nil, Acc = 0 }

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

local function mk(kind, props)
	return Draw.New(kind, props)
end

function ESP:Entry(plr)
	local e = {
		Box = mk("Square", { Filled = false, Thickness = 1 }),
		Fill = mk("Square", { Filled = true, Thickness = 0 }),
		C1 = mk("Line", { Thickness = 2 }), C2 = mk("Line", { Thickness = 2 }),
		C3 = mk("Line", { Thickness = 2 }), C4 = mk("Line", { Thickness = 2 }),
		C5 = mk("Line", { Thickness = 2 }), C6 = mk("Line", { Thickness = 2 }),
		C7 = mk("Line", { Thickness = 2 }), C8 = mk("Line", { Thickness = 2 }),
		Name = mk("Text", { Center = true, Outline = true }),
		Dist = mk("Text", { Center = true, Outline = true }),
		HpBg = mk("Square", { Filled = true, Thickness = 0 }),
		HpFg = mk("Square", { Filled = true, Thickness = 0 }),
		Dot = mk("Circle", { Thickness = 2, Filled = true }),
		Tracer = mk("Line", { Thickness = 1 }),
		Arrow = mk("Square", { Filled = true, Thickness = 0 }),
		Bones = {},
	}
	self.Pool[plr] = e
	return e
end

function ESP:Drop(plr)
	local e = self.Pool[plr]
	if not e then return end
	for k, v in pairs(e) do
		if k == "Bones" then
			for _, b in ipairs(v) do pcall(function() b:Remove() end) end
		else
			pcall(function() v:Remove() end)
		end
	end
	self.Pool[plr] = nil
end

function ESP:Hide(e)
	e.Box.Visible = false
	e.Fill.Visible = false
	e.Name.Visible = false
	e.Dist.Visible = false
	e.HpBg.Visible = false
	e.HpFg.Visible = false
	e.Dot.Visible = false
	e.Tracer.Visible = false
	e.Arrow.Visible = false
	for _, l in ipairs({ e.C1, e.C2, e.C3, e.C4, e.C5, e.C6, e.C7, e.C8 }) do l.Visible = false end
	for _, b in ipairs(e.Bones) do b.Visible = false end
end

function ESP:Draw(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))

	local on = Cfg.Get("ESP") and U.Alive(char) and head and root
	if on and Cfg.Get("ESPTeamCheck") and plr.Team == LP.Team then on = false end
	if on and (root.Position - Camera.CFrame.Position).Magnitude > Cfg.Get("ESPMaxDist") then on = false end

	local e = self.Pool[plr]
	if not on then
		if e then self:Hide(e) end
		return
	end
	e = e or self:Entry(plr)

	local hs, ho = Camera:WorldToViewportPoint(head.Position)
	local rs, ro = Camera:WorldToViewportPoint(root.Position)
	if not ho or not ro or hs.Z <= 0 then
		self:Hide(e)
		return
	end

	local friend = T.IsFriend(plr)
	local col = friend and U.Col({ 255, 210, 60 })
		or (plr.Team == LP.Team and U.Col(Cfg.Get("ColorTeam")) or U.Col(Cfg.Get("ColorEnemy")))
	local alpha = Cfg.Get("ESPAlpha")

	local h = math.abs(rs.Y - hs.Y) * 2.2
	local w = h * 0.55
	local top = Vector2.new(hs.X, hs.Y - h * 0.25)
	local tl = top - Vector2.new(w / 2, 0)
	local br = tl + Vector2.new(w, h)

	local style = Cfg.Get("ESPBoxStyle")
	local showBox = Cfg.Get("ESPBox")

	e.Box.Visible = showBox and style == "Pełny"
	e.Box.Color = col
	e.Box.Thickness = 1
	e.Box.Transparency = alpha
	e.Box.Size = Vector2.new(w, h)
	e.Box.Position = tl

	e.Fill.Visible = showBox and style == "Wypełniony"
	e.Fill.Color = col
	e.Fill.Size = Vector2.new(w, h)
	e.Fill.Position = tl

	local corners = { e.C1, e.C2, e.C3, e.C4, e.C5, e.C6, e.C7, e.C8 }
	local showCorners = showBox and style == "Narożniki"
	local cl = math.min(w, h) * 0.22
	local segs = {
		{ tl, tl + Vector2.new(cl, 0) }, { tl, tl + Vector2.new(0, cl) },
		{ Vector2.new(br.X, tl.Y), Vector2.new(br.X - cl, tl.Y) },
		{ Vector2.new(br.X, tl.Y), Vector2.new(br.X, tl.Y + cl) },
		{ Vector2.new(tl.X, br.Y), Vector2.new(tl.X + cl, br.Y) },
		{ Vector2.new(tl.X, br.Y), Vector2.new(tl.X, br.Y - cl) },
		{ br, br - Vector2.new(cl, 0) }, { br, br - Vector2.new(0, cl) },
	}
	for i, l in ipairs(corners) do
		l.Visible = showCorners
		if showCorners then
			l.Color = col
			l.From = segs[i][1]
			l.To = segs[i][2]
		end
	end

	e.Name.Visible = Cfg.Get("ESPName")
	e.Name.Color = col
	e.Name.Text = friend and ("★ " .. plr.DisplayName) or plr.DisplayName
	e.Name.Position = top - Vector2.new(0, 18)
	e.Name.Size = 14

	e.Dist.Visible = Cfg.Get("ESPDistance")
	e.Dist.Color = col
	e.Dist.Text = string.format("%d m", math.floor((root.Position - Camera.CFrame.Position).Magnitude / 3))
	e.Dist.Position = br + Vector2.new(0, 2)

	if Cfg.Get("ESPHealth") and hum then
		local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		e.HpBg.Visible = true
		e.HpBg.Color = Color3.fromRGB(14, 18, 22)
		e.HpBg.Size = Vector2.new(3, h)
		e.HpBg.Position = tl - Vector2.new(6, 0)
		e.HpFg.Visible = true
		e.HpFg.Color = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 70)
		e.HpFg.Size = Vector2.new(3, h * pct)
		e.HpFg.Position = tl - Vector2.new(6, 0) + Vector2.new(0, h * (1 - pct))
	else
		e.HpBg.Visible = false
		e.HpFg.Visible = false
	end

	e.Dot.Visible = Cfg.Get("ESPHeadDot")
	e.Dot.Color = col
	e.Dot.Radius = 3
	e.Dot.Position = Vector2.new(hs.X, hs.Y)

	e.Tracer.Visible = Cfg.Get("ESPTracer")
	e.Tracer.Color = U.Col(Cfg.Get("ColorTracer"))
	e.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
	e.Tracer.To = Vector2.new(hs.X, br.Y)

	-- offscreen
	local vp = Camera.ViewportSize
	local arrow = Cfg.Get("ESPArrows") and (hs.X < 0 or hs.X > vp.X or hs.Y < 0 or hs.Y > vp.Y)
	e.Arrow.Visible = arrow
	if arrow then
		local c = Vector2.new(vp.X / 2, vp.Y / 2)
		local dir = (Vector2.new(hs.X, hs.Y) - c)
		if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
		dir = dir.Unit
		local pos = c + dir * math.min(vp.X, vp.Y) * 0.38
		e.Arrow.Color = col
		e.Arrow.Size = Vector2.new(9, 9)
		e.Arrow.Position = pos - Vector2.new(4.5, 4.5)
	end

	local bones = hum.RigType == Enum.HumanoidRigType.R15 and R15 or R6
	local skelOn = Cfg.Get("ESPSkeleton")
	local skelCol = U.Col(Cfg.Get("ColorSkel"))
	for i, pair in ipairs(bones) do
		local l = e.Bones[i]
		if not l then
			l = mk("Line", { Thickness = 1 })
			e.Bones[i] = l
		end
		local a = char:FindFirstChild(pair[1])
		local b = char:FindFirstChild(pair[2])
		if skelOn and a and b then
			local sa, oa = Camera:WorldToViewportPoint(a.Position)
			local sb, ob = Camera:WorldToViewportPoint(b.Position)
			if oa and ob then
				l.Visible = true
				l.Color = skelCol
				l.Transparency = alpha
				l.From = Vector2.new(sa.X, sa.Y)
				l.To = Vector2.new(sb.X, sb.Y)
			else
				l.Visible = false
			end
		else
			l.Visible = false
		end
	end
end

function ESP:Step(dt)
	if Cfg.Get("PerfMode") then
		self.Acc += dt
		if self.Acc < 1 / 40 then return end
		self.Acc = 0
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then U.Safe(ESP.Draw, ESP, plr) end
	end
end

function ESP:Start()
	if self.Conn then return end
	self.Conn = U.Track(RunService.RenderStepped:Connect(function(dt)
		U.Safe(ESP.Step, ESP, dt)
	end))
end

function ESP:Stop()
	if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
	for plr in pairs(self.Pool) do self:Drop(plr) end
end

--==========================================================
-- 10. WORLD (wallhack / światło / crosshair / fov)
--==========================================================
local World = { Pool = {}, Loop = nil }

function World:HL(inst, col, fill, depth)
	if self.Pool[inst] then return end
	local h = Instance.new("Highlight")
	h.Adornee = inst
	h.DepthMode = depth
	h.FillColor = col
	h.FillTransparency = fill
	h.OutlineColor = col
	h.OutlineTransparency = 0.1
	h.Parent = inst
	self.Pool[inst] = h
end

function World:ClearHL()
	for _, h in pairs(self.Pool) do pcall(function() h:Destroy() end) end
	self.Pool = {}
end

function World:WallStep()
	if not Cfg.Get("Wallhack") then
		if next(self.Pool) then self:ClearHL() end
		return
	end
	local col = U.Col(Cfg.Get("ColorWH"))
	local fill = Cfg.Get("WHFill")
	local depth = Cfg.Get("WHDepth") == "Zawsze"
		and Enum.HighlightDepthMode.AlwaysOnTop
		or Enum.HighlightDepthMode.Occluded

	if Cfg.Get("WHPlayers") then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then self:HL(p.Character, col, fill, depth) end
		end
	end
	if Cfg.Get("WHBots") then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(d) then
				self:HL(d, col, fill, depth)
			end
		end
	end
	if Cfg.Get("WHObjects") then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Model") then
				self:HL(d, col, fill, depth)
			end
		end
	end
	for _, h in pairs(self.Pool) do h.FillTransparency = fill end
end

function World:ApplyLight()
	Lighting.Brightness = Cfg.Get("Fullbright") and 3 or 1
	Lighting.ClockTime = Cfg.Get("Fullbright") and 14 or 14.5
	Lighting.GlobalShadows = not Cfg.Get("Fullbright")
	if Cfg.Get("NoFog") then
		Lighting.FogEnd = 100000
		Lighting.FogStart = 0
	end
end

function World:ApplyFOV()
	if Camera then Camera.FieldOfView = Cfg.Get("CamFOV") end
end

function World:Start()
	if self.Loop then return end
	self.Loop = U.Track(task.spawn(function()
		while CS.Alive do
			U.Safe(World.WallStep, World)
			task.wait(0.5)
		end
	end))
	U.Track(Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
		if Cfg.Get("Fullbright") then task.wait(); U.Safe(World.ApplyLight, World) end
	end))
end

function World:Stop()
	if self.Loop then self.Loop:Disconnect(); self.Loop = nil end
	self:ClearHL()
end

--==========================================================
-- 11. HITBOX
--==========================================================
local HB = { Orig = {}, Done = {}, Preview = {} }

local PARTS = { "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart",
	"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }

function HB:Apply(char)
	if not char or self.Done[char] then return end
	self.Done[char] = true
	local w, h, d = Cfg.Get("HitboxW"), Cfg.Get("HitboxH"), Cfg.Get("HitboxD")
	local sel = Cfg.Get("HitboxParts")
	for _, n in ipairs(PARTS) do
		if table.find(sel, n) then
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				self.Orig[p] = self.Orig[p] or p.Size
				p.Size = Vector3.new(w, h, d)
				p.CanCollide = false
			end
		end
	end
end

function HB:Restore(char)
	if not char then return end
	self.Done[char] = nil
	for p, s in pairs(self.Orig) do
		if p and p.Parent and p:IsDescendantOf(char) then
			p.Size = s
			self.Orig[p] = nil
		end
	end
end

function HB:Refresh()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			if Cfg.Get("Hitbox") then self:Apply(p.Character) else self:Restore(p.Character) end
		end
	end
	if LP.Character then
		if Cfg.Get("Hitbox") then self:Apply(LP.Character) else self:Restore(LP.Character) end
	end
end

function HB:PreviewStep()
	for _, d in pairs(self.Preview) do pcall(function() d:Remove() end) end
	self.Preview = {}
	if not Cfg.Get("Hitbox") or not Cfg.Get("HitboxPreview") then return end
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
						local box = Draw.New("Square", { Thickness = 1, Filled = false, Color = col })
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
	local function hook(p)
		p.CharacterAdded:Connect(function(ch)
			ch:WaitForChild("Humanoid", 10)
			task.wait(0.25)
			if Cfg.Get("Hitbox") then U.Safe(HB.Apply, HB, ch) end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do hook(p) end
	U.Track(Players.PlayerAdded:Connect(hook))
end

--==========================================================
-- 12. OVERLAY (FOV / wizualizacja / crosshair / watermark)
--==========================================================
local OV = { Circle = nil, Box = nil, Line = nil, Info = nil, Dots = {}, Cross = {} }

function OV:Init()
	self.Circle = Draw.New("Circle", { Thickness = 1, Filled = false, NumSides = 96 })
	self.Box = Draw.New("Square", { Thickness = 2, Filled = false })
	self.Line = Draw.New("Line", { Thickness = 1 })
	self.Info = Draw.New("Text", { Center = true, Outline = true, Size = 13 })
	for i = 1, 40 do
		self.Dots[i] = Draw.New("Square", { Filled = true, Thickness = 0, Size = Vector2.new(3, 3) })
	end
	for i = 1, 4 do
		self.Cross[i] = Draw.New("Line", { Thickness = 2 })
	end
end

function OV:Step()
	local vp = Camera.ViewportSize
	local c = Vector2.new(vp.X / 2, vp.Y / 2)
	local acc = Color3.fromRGB(61, 255, 158)

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
		local s, o = Camera:WorldToViewportPoint(t.Part.Position)
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
		end
	else
		self.Box.Visible = false
		self.Line.Visible = false
		self.Info.Visible = false
	end

	local cross = Cfg.Get("Crosshair")
	for _, l in ipairs(self.Cross) do l.Visible = false end
	if cross then
		local col = U.Col(Cfg.Get("ColorCross"))
		local gap, len = 6, 10
		local st = Cfg.Get("CrosshairStyle")
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
		if st == "Krzyż" then
			seg(c - Vector2.new(gap + len, 0), c - Vector2.new(gap, 0))
			seg(c + Vector2.new(gap, 0), c + Vector2.new(gap + len, 0))
			seg(c - Vector2.new(0, gap + len), c - Vector2.new(0, gap))
			seg(c + Vector2.new(0, gap), c + Vector2.new(0, gap + len))
		else
			local s = 5
			seg(c - Vector2.new(s, s), c + Vector2.new(s, s))
			seg(c + Vector2.new(s, -s), c + Vector2.new(-s, s))
		end
	end
end

--==========================================================
-- 13. THEME
--==========================================================
local TH = {
	Bg = Color3.fromRGB(10, 13, 17),
	Panel = Color3.fromRGB(16, 20, 26),
	Card = Color3.fromRGB(22, 27, 34),
	Hover = Color3.fromRGB(31, 38, 46),
	Line = Color3.fromRGB(38, 46, 55),
	Text = Color3.fromRGB(234, 242, 238),
	Dim = Color3.fromRGB(124, 138, 148),
	Acc = Color3.fromRGB(61, 255, 158),
	AccD = Color3.fromRGB(20, 84, 55),
	Red = Color3.fromRGB(255, 96, 96),
}

--==========================================================
-- 14. UI LIBRARY
--==========================================================
local UI = { Tabs = {}, Refreshers = {}, Toasts = {} }

function UI:Bind(key, fn) self.Refreshers[key] = fn end

function UI:Root()
	local g = Instance.new("ScreenGui")
	g.Name = "ChelmskiSiekatorV5"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 10000
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local ok = pcall(function() g.Parent = gethui() end)
	if not ok then g.Parent = LP:WaitForChild("PlayerGui") end
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(g) end end)

	local holder = Instance.new("CanvasGroup")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = g

	local main = U.New("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(660, 452),
		Position = UDim2.fromOffset(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = TH.Bg,
		BorderSizePixel = 0,
	}, holder)
	U.Corner(main, 16)
	U.Stroke(main, TH.Line, 1, 0.35)
	main.ClipsDescendants = true

	local glow = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = TH.Acc,
		BorderSizePixel = 0,
	}, main)
	glow.BackgroundTransparency = 0.25

	-- header
	local bar = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = TH.Panel,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, main)

	local logo = U.New("Frame", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(16, 13),
		BackgroundColor3 = TH.Acc,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, bar)
	U.Corner(logo, 10)
	U.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "◤",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = TH.Bg,
		ZIndex = 5,
	}, logo)
	U.Tween(logo, 1.6, { BackgroundColor3 = Color3.fromRGB(120, 255, 195) },
		Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	task.spawn(function()
		while CS.Alive do
			U.Tween(logo, 0.9, { BackgroundColor3 = Color3.fromRGB(120, 255, 195) }, Enum.EasingStyle.Sine)
			task.wait(0.95)
			U.Tween(logo, 0.9, { BackgroundColor3 = TH.Acc }, Enum.EasingStyle.Sine)
			task.wait(0.95)
		end
	end)

	U.New("TextLabel", {
		Size = UDim2.fromOffset(240, 20),
		Position = UDim2.fromOffset(58, 10),
		BackgroundTransparency = 1,
		Text = "CHEŁMSKI SIEKATOR",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, bar)

	U.New("TextLabel", {
		Size = UDim2.fromOffset(240, 16),
		Position = UDim2.fromOffset(58, 29),
		BackgroundTransparency = 1,
		Text = "XYZ PVP  ·  v" .. CS.Version,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = TH.Acc,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, bar)

	local function barBtn(glyph, x, cb)
		local b = U.New("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, x, 0, 15),
			BackgroundColor3 = TH.Card,
			Text = glyph,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = TH.Dim,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, bar)
		U.Corner(b, 9)
		b.MouseEnter:Connect(function() U.Tween(b, 0.12, { BackgroundColor3 = TH.Hover, TextColor3 = TH.Text }) end)
		b.MouseLeave:Connect(function() U.Tween(b, 0.12, { BackgroundColor3 = TH.Card, TextColor3 = TH.Dim }) end)
		b.MouseButton1Click:Connect(function() U.Safe(cb) end)
		return b
	end
	barBtn("–", -72, function() UI:Minimize() end)
	barBtn("✕", -40, function() UI:Close() end)

	-- sidebar
	local side = U.New("Frame", {
		Size = UDim2.new(0, 168, 1, -58),
		Position = UDim2.fromOffset(0, 58),
		BackgroundColor3 = TH.Panel,
		BorderSizePixel = 0,
	}, main)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = side
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = side

	local content = U.New("Frame", {
		Size = UDim2.new(1, -168, 1, -58),
		Position = UDim2.fromOffset(168, 58),
		BackgroundTransparency = 1,
	}, main)

	-- drag
	local drag, start, base = false, nil, nil
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = true
			start = i.Position
			base = main.Position
		end
	end)
	Input.InputChanged:Connect(function(i)
		if not drag then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - start
			main.Position = UDim2.fromOffset(base.X.Offset + d.X, base.Y.Offset + d.Y)
		end
	end)
	Input.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = false
		end
	end)

	return g, holder, main, side, content
end

function UI:Init()
	self.Gui, self.Holder, self.Main, self.Side, self.Content = self:Root()
	self.Main.Size = UDim2.fromOffset(660, 300)
	self.Holder.GroupTransparency = 1
	U.Tween(self.Main, 0.42, { Size = UDim2.fromOffset(660, 452) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	U.Tween(self.Holder, 0.25, { GroupTransparency = 0 })
end

function UI:Ripple(btn)
	btn.MouseButton1Click:Connect(function()
		local m = Input:GetMouseLocation()
		local r = U.New("Frame", {
			Size = UDim2.fromOffset(0, 0),
			Position = UDim2.fromOffset(m.X - btn.AbsolutePosition.X, m.Y - btn.AbsolutePosition.Y),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, btn)
		U.Corner(r, 999)
		U.Tween(r, 0.45, { Size = UDim2.fromOffset(160, 160), BackgroundTransparency = 1 })
		task.delay(0.5, function() if r.Parent then r:Destroy() end end)
	end)
end

function UI:Tab(name, glyph)
	local btn = U.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = TH.Card,
		BackgroundTransparency = 1,
		Text = "   " .. glyph .. "   " .. name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = TH.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, self.Side)
	U.Corner(btn, 9)

	local marker = U.New("Frame", {
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.fromOffset(0, 17),
		BackgroundColor3 = TH.Acc,
		BorderSizePixel = 0,
	}, btn)
	U.Corner(marker, 2)

	local page = U.New("ScrollingFrame", {
		Size = UDim2.new(1, -26, 1, -26),
		Position = UDim2.fromOffset(14, 13),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = TH.AccD,
		CanvasSize = UDim2.new(),
		Visible = false,
	}, self.Content)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = page
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 24)
	end)

	local tab = { Btn = btn, Page = page, Marker = marker }
	table.insert(self.Tabs, tab)

	btn.MouseEnter:Connect(function()
		if self.Active ~= tab then U.Tween(btn, 0.12, { TextColor3 = TH.Text, BackgroundTransparency = 0.85 }) end
	end)
	btn.MouseLeave:Connect(function()
		if self.Active ~= tab then U.Tween(btn, 0.12, { TextColor3 = TH.Dim, BackgroundTransparency = 1 }) end
	end)
	btn.MouseButton1Click:Connect(function() self:Select(tab) end)
	return tab
end

function UI:Select(tab)
	if self.Active == tab then return end
	if self.Active then
		self.Active.Page.Visible = false
		U.Tween(self.Active.Btn, 0.12, { TextColor3 = TH.Dim, BackgroundTransparency = 1 })
		U.Tween(self.Active.Marker, 0.15, { Size = UDim2.new(0, 3, 0, 0) })
	end
	self.Active = tab
	tab.Page.Visible = true
	U.Tween(tab.Btn, 0.12, { TextColor3 = TH.Acc, BackgroundTransparency = 0.72 })
	U.Tween(tab.Marker, 0.2, { Size = UDim2.new(0, 3, 0, 20) }, Enum.EasingStyle.Back)
end

function UI:Section(page, text)
	U.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = text:upper(),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = TH.Acc,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
end

function UI:Card(page, height)
	local f = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, height or 36),
		BackgroundColor3 = TH.Card,
		BorderSizePixel = 0,
	}, page)
	U.Corner(f, 9)
	return f
end

function UI:Toggle(page, label, key, cb)
	local row = self:Card(page, 36)
	U.New("TextLabel", {
		Size = UDim2.new(1, -62, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local pill = U.New("Frame", {
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = TH.Hover,
		BorderSizePixel = 0,
	}, row)
	U.Corner(pill, 10)

	local knob = U.New("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = TH.Dim,
		BorderSizePixel = 0,
	}, pill)
	U.Corner(knob, 7)

	local btn = U.New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
	}, row)

	local function paint(on, anim)
		local bg = on and TH.AccD or TH.Hover
		local kc = on and TH.Acc or TH.Dim
		local kp = on and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3)
		if anim then
			U.Tween(pill, 0.18, { BackgroundColor3 = bg }, Enum.EasingStyle.Back)
			U.Tween(knob, 0.18, { Position = kp, BackgroundColor3 = kc }, Enum.EasingStyle.Back)
		else
			pill.BackgroundColor3 = bg
			knob.BackgroundColor3 = kc
			knob.Position = kp
		end
	end

	paint(Cfg.Get(key), false)
	self:Bind(key, function() paint(Cfg.Get(key), true) end)

	btn.MouseButton1Click:Connect(function()
		local v = not Cfg.Get(key)
		Cfg.Set(key, v)
		paint(v, true)
		if cb then task.spawn(cb, v) end
	end)
end

function UI:Slider(page, label, key, min, max, step, suffix, cb)
	local row = self:Card(page, 50)
	U.New("TextLabel", {
		Size = UDim2.new(1, -90, 0, 20),
		Position = UDim2.fromOffset(12, 6),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local val = U.New("TextLabel", {
		Size = UDim2.fromOffset(70, 20),
		Position = UDim2.new(1, -82, 0, 6),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = TH.Acc,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)

	local track = U.New("Frame", {
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.fromOffset(12, 36),
		BackgroundColor3 = TH.Hover,
		BorderSizePixel = 0,
	}, row)
	U.Corner(track, 2)

	local fill = U.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = TH.Acc,
		BorderSizePixel = 0,
	}, track)
	U.Corner(fill, 2)

	local knob = U.New("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(0, -6, 0.5, -6),
		BackgroundColor3 = TH.Text,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, track)
	U.Corner(knob, 6)

	local dragging = false

	local function set(v, fire)
		v = math.clamp(U.Round(v, step), min, max)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.new(a, -6, 0.5, -6)
		val.Text = tostring(v) .. (suffix or "")
		Cfg.Set(key, v)
		if fire and cb then task.spawn(cb, v) end
	end

	set(Cfg.Get(key), false)
	self:Bind(key, function() set(Cfg.Get(key), false) end)

	local function from(i)
		local r = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		set(min + (max - min) * r, true)
	end

	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			U.Tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
			from(i)
		end
	end)
	Input.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			from(i)
		end
	end)
	Input.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			U.Tween(knob, 0.12, { Size = UDim2.fromOffset(12, 12) })
		end
	end)
end

function UI:Dropdown(page, label, key, options, cb)
	local row = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = TH.Card,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, page)
	U.Corner(row, 9)

	local head = U.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, row)

	U.New("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, head)

	local cur = U.New("TextLabel", {
		Size = UDim2.fromOffset(90, 36),
		Position = UDim2.new(1, -98, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(Cfg.Get(key)) .. "  ▾",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = TH.Acc,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, head)

	local holder = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
	}, row)
	local hl = Instance.new("UIListLayout")
	hl.Padding = UDim.new(0, 4)
	hl.Parent = holder

	local open = false
	for _, opt in ipairs(options) do
		local b = U.New("TextButton", {
			Size = UDim2.new(1, -18, 0, 28),
			BackgroundColor3 = TH.Hover,
			Text = "   " .. opt,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = TH.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, holder)
		U.Corner(b, 7)
		b.MouseEnter:Connect(function() U.Tween(b, 0.1, { TextColor3 = TH.Text }) end)
		b.MouseLeave:Connect(function() U.Tween(b, 0.1, { TextColor3 = TH.Dim }) end)
		b.MouseButton1Click:Connect(function()
			Cfg.Set(key, opt)
			cur.Text = opt .. "  ▾"
			open = false
			holder.Visible = false
			U.Tween(row, 0.16, { Size = UDim2.new(1, 0, 0, 36) })
			if cb then task.spawn(cb, opt) end
		end)
	end
	holder.Visible = false

	head.MouseButton1Click:Connect(function()
		open = not open
		holder.Visible = open
		U.Tween(row, 0.2, { Size = UDim2.new(1, 0, 0, open and (40 + #options * 32) or 36) }, Enum.EasingStyle.Quad)
	end)

	self:Bind(key, function() cur.Text = tostring(Cfg.Get(key)) .. "  ▾" end)
end

local SWATCH = {
	{ 61, 255, 158 }, { 90, 170, 255 }, { 255, 96, 96 }, { 255, 200, 60 },
	{ 200, 120, 255 }, { 255, 255, 255 }, { 255, 120, 200 }, { 120, 255, 255 },
}

function UI:Color(page, label, key)
	local row = self:Card(page, 32)
	U.New("TextLabel", {
		Size = UDim2.fromOffset(130, 32),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local prev = U.New("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -32, 0.5, -9),
		BackgroundColor3 = U.Col(Cfg.Get(key)),
		BorderSizePixel = 0,
	}, row)
	U.Corner(prev, 9)
	U.Stroke(prev, TH.Line, 1)

	for i, rgb in ipairs(SWATCH) do
		local s = U.New("TextButton", {
			Size = UDim2.fromOffset(17, 17),
			Position = UDim2.fromOffset(140 + (i - 1) * 21, 7),
			BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, row)
		U.Corner(s, 9)
		s.MouseButton1Click:Connect(function()
			Cfg.Set(key, table.clone(rgb))
			prev.BackgroundColor3 = U.Col(rgb)
		end)
	end
end

function UI:Keybind(page, label, key)
	local row = self:Card(page, 36)
	U.New("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local b = U.New("TextButton", {
		Size = UDim2.fromOffset(70, 22),
		Position = UDim2.new(1, -80, 0.5, -11),
		BackgroundColor3 = TH.Hover,
		Text = Cfg.Get(key),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = TH.Acc,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, row)
	U.Corner(b, 6)

	local waiting = false
	b.MouseButton1Click:Connect(function()
		waiting = true
		b.Text = "…"
		b.TextColor3 = TH.Red
	end)
	U.Track(Input.InputBegan:Connect(function(i)
		if not waiting then return end
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		waiting = false
		Cfg.Set(key, i.KeyCode.Name)
		b.Text = i.KeyCode.Name
		b.TextColor3 = TH.Acc
	end))
	self:Bind(key, function() b.Text = Cfg.Get(key) end)
end

function UI:Button(page, label, cb, danger)
	local b = U.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = danger and Color3.fromRGB(64, 26, 30) or TH.Card,
		Text = label,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = danger and TH.Red or TH.Text,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, page)
	U.Corner(b, 9)
	b.MouseEnter:Connect(function() U.Tween(b, 0.12, { BackgroundColor3 = TH.Hover }) end)
	b.MouseLeave:Connect(function()
		U.Tween(b, 0.12, { BackgroundColor3 = danger and Color3.fromRGB(64, 26, 30) or TH.Card })
	end)
	b.MouseButton1Click:Connect(function() task.spawn(cb) end)
	self:Ripple(b)
	return b
end

function UI:Textbox(page, placeholder, key)
	local box = U.New("TextBox", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = TH.Card,
		Text = Cfg.Get(key) or "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = TH.Dim,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, page)
	U.Corner(box, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.Parent = box
	box.FocusLost:Connect(function() Cfg.Set(key, box.Text) end)
	self:Bind(key, function() box.Text = Cfg.Get(key) or "" end)
	return box
end

function UI:Label(page, text, dim)
	U.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 15),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = dim and TH.Dim or TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, page)
end

function UI:Minimize()
	self.Min = not self.Min
	local goal = self.Min and UDim2.fromOffset(660, 58) or UDim2.fromOffset(660, 452)
	U.Tween(self.Main, 0.26, { Size = goal }, Enum.EasingStyle.Quart)
	self.Side.Visible = not self.Min
	self.Content.Visible = not self.Min
end

function UI:Close()
	U.Tween(self.Holder, 0.2, { GroupTransparency = 1 })
	U.Tween(self.Main, 0.2, { Size = UDim2.fromOffset(620, 420) }, Enum.EasingStyle.Quart)
	task.delay(0.21, function() if self.Gui then self.Gui.Enabled = false end end)
end

function UI:Open()
	if not self.Gui then return end
	self.Gui.Enabled = true
	self.Main.Size = UDim2.fromOffset(620, 420)
	self.Holder.GroupTransparency = 1
	U.Tween(self.Main, 0.34, { Size = UDim2.fromOffset(660, 452) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	U.Tween(self.Holder, 0.2, { GroupTransparency = 0 })
end

function UI:ToggleOpen()
	if not self.Gui then return end
	if self.Gui.Enabled then self:Close() else self:Open() end
end

function UI:Toast(title, body, danger)
	if not self.Gui then return end
	local t = U.New("Frame", {
		Size = UDim2.fromOffset(240, 46),
		Position = UDim2.new(1, 12, 0, 12),
		BackgroundColor3 = TH.Card,
		BorderSizePixel = 0,
	}, self.Gui)
	U.Corner(t, 10)
	U.Stroke(t, danger and TH.Red or TH.Acc, 1, 0.5)

	U.New("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = danger and TH.Red or TH.Acc,
		BorderSizePixel = 0,
	}, t)
	U.New("TextLabel", {
		Size = UDim2.new(1, -18, 0, 16),
		Position = UDim2.fromOffset(12, 6),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, t)
	U.New("TextLabel", {
		Size = UDim2.new(1, -18, 0, 14),
		Position = UDim2.fromOffset(12, 24),
		BackgroundTransparency = 1,
		Text = body,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = TH.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, t)

	for i, o in ipairs(self.Toasts) do
		U.Tween(o, 0.2, { Position = UDim2.new(1, 12, 0, 12 + i * 54) })
	end
	table.insert(self.Toasts, t)
	U.Tween(t, 0.3, { Position = UDim2.new(1, -252, 0, 12) }, Enum.EasingStyle.Back)

	task.delay(3.2, function()
		local i = table.find(self.Toasts, t)
		if i then table.remove(self.Toasts, i) end
		U.Tween(t, 0.25, { Position = UDim2.new(1, 12, 0, t.Position.Y.Offset), BackgroundTransparency = 1 })
		task.delay(0.3, function() if t.Parent then t:Destroy() end end)
	end)
end

--==========================================================
-- 15. WATERMARK
--==========================================================
local WM = {}

function WM:Init()
	self.Frame = U.New("Frame", {
		Size = UDim2.fromOffset(196, 26),
		Position = UDim2.fromOffset(12, -40),
		BackgroundColor3 = Color3.fromRGB(10, 13, 17),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, UI.Gui)
	U.Corner(self.Frame, 8)
	U.Stroke(self.Frame, TH.Acc, 1, 0.6)

	self.Dot = U.New("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromOffset(9, 10),
		BackgroundColor3 = TH.Acc,
		BorderSizePixel = 0,
	}, self.Frame)
	U.Corner(self.Dot, 3)

	self.Text = U.New("TextLabel", {
		Size = UDim2.new(1, -22, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		BackgroundTransparency = 1,
		Text = "SIEKATOR v" .. CS.Version,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.Frame)

	U.Tween(self.Frame, 0.4, { Position = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back)
	task.spawn(function()
		while CS.Alive do
			U.Tween(self.Dot, 0.5, { BackgroundTransparency = 0.7 })
			task.wait(0.55)
			U.Tween(self.Dot, 0.5, { BackgroundTransparency = 0 })
			task.wait(0.55)
		end
	end)
end

function WM:Step()
	if not self.Text then return end
	local ping = 0
	pcall(function()
		ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
	end)
	self.Text.Text = string.format("SIEKATOR v%s  ·  %d FPS  ·  %d ms", CS.Version, math.floor(CS.FPS), ping)
end

--==========================================================
-- 16. BUILD GUI
--==========================================================
local function build()
	UI:Init()
	WM:Init()

	-- AIM
	local a = UI:Tab("Aim", "⌖")
	UI:Section(a.Page, "Silent Aim")
	UI:Toggle(a.Page, "Silent Aim", "SilentAim", function(on)
		if on and not SA:Install() then
			UI:Toast("Silent Aim", "Brak wsparcia hooków — tryb kamery", true)
		end
	end)
	UI:Slider(a.Page, "Szansa trafienia", "SilentChance", 0, 100, 1, "%")
	UI:Slider(a.Page, "FOV", "SilentFOV", 20, 500, 5, " px")
	UI:Slider(a.Page, "Zasięg", "SilentRange", 50, 3000, 25, " st")
	UI:Dropdown(a.Page, "Część ciała", "SilentPart", { "Head", "UpperTorso", "HumanoidRootPart", "Blisko" })
	UI:Toggle(a.Page, "Tylko widoczni", "SilentVisible")
	UI:Toggle(a.Page, "Tylko przy trzymaniu klawisza", "SilentHold")
	UI:Toggle(a.Page, "Koło FOV", "CircleOn")
	UI:Dropdown(a.Page, "Styl koła", "CircleStyle", { "Cienkie", "Grube", "Kropkowane" })
	UI:Toggle(a.Page, "Wizualizacja celu", "SilentViz")

	UI:Section(a.Page, "Aimbot")
	UI:Toggle(a.Page, "Aimbot", "Aimbot", function(on)
		if on then AB:Start() else AB:Stop() end
	end)
	UI:Dropdown(a.Page, "Tryb", "AimbotMode", { "Hold", "Zawsze" })
	UI:Dropdown(a.Page, "Styl", "AimbotStyle", { "Wykładniczy", "Liniowy", "Snap" })
	UI:Slider(a.Page, "Płynność", "AimbotSmooth", 0.01, 1, 0.01, "")
	UI:Slider(a.Page, "Humanizacja", "AimbotHumanize", 0, 2, 0.05, "")
	UI:Slider(a.Page, "FOV", "AimbotFOV", 10, 400, 5, " px")
	UI:Slider(a.Page, "Zasięg", "AimbotRange", 50, 3000, 25, " st")
	UI:Dropdown(a.Page, "Punkt celowania", "AimbotPart", { "Head", "UpperTorso", "HumanoidRootPart", "Blisko" })
	UI:Toggle(a.Page, "Tylko widoczni", "AimbotVisible")

	-- VISUALS
	local v = UI:Tab("Visuals", "✦")
	UI:Section(v.Page, "ESP")
	UI:Toggle(v.Page, "ESP", "ESP", function(on)
		if on then ESP:Start() else ESP:Stop() end
	end)
	UI:Dropdown(v.Page, "Styl boxa", "ESPBoxStyle", { "Pełny", "Narożniki", "Wypełniony" })
	UI:Toggle(v.Page, "Box", "ESPBox")
	UI:Toggle(v.Page, "Szkielet", "ESPSkeleton")
	UI:Toggle(v.Page, "Nazwa", "ESPName")
	UI:Toggle(v.Page, "Dystans", "ESPDistance")
	UI:Toggle(v.Page, "Pasek HP", "ESPHealth")
	UI:Toggle(v.Page, "Kropka na głowie", "ESPHeadDot")
	UI:Toggle(v.Page, "Tracer", "ESPTracer")
	UI:Toggle(v.Page, "Strzałki poza ekranem", "ESPArrows")
	UI:Slider(v.Page, "Krycie", "ESPAlpha", 0.2, 1, 0.05, "")
	UI:Slider(v.Page, "Maks. dystans", "ESPMaxDist", 100, 5000, 50, " st")
	UI:Toggle(v.Page, "Team Check", "ESPTeamCheck")
	UI:Section(v.Page, "Kolory")
	UI:Color(v.Page, "Wróg", "ColorEnemy")
	UI:Color(v.Page, "Sojusznik", "ColorTeam")
	UI:Color(v.Page, "Szkielet", "ColorSkel")
	UI:Color(v.Page, "Tracer", "ColorTracer")

	-- WORLD
	local w = UI:Tab("World", "◈")
	UI:Section(w.Page, "Wallhack")
	UI:Toggle(w.Page, "Wallhack", "Wallhack", function(on)
		if on then World:Start() else World:Stop() end
	end)
	UI:Toggle(w.Page, "Gracze", "WHPlayers")
	UI:Toggle(w.Page, "Boty / NPC", "WHBots")
	UI:Toggle(w.Page, "Obiekty", "WHObjects")
	UI:Dropdown(w.Page, "Widoczność", "WHDepth", { "Zawsze", "Zasłonięte" })
	UI:Slider(w.Page, "Przezroczystość", "WHFill", 0, 1, 0.05, "")
	UI:Color(w.Page, "Kolor", "ColorWH")
	UI:Section(w.Page, "Światło")
	UI:Toggle(w.Page, "Fullbright", "Fullbright", function() World:ApplyLight() end)
	UI:Toggle(w.Page, "Bez mgły", "NoFog", function() World:ApplyLight() end)
	UI:Slider(w.Page, "FOV kamery", "CamFOV", 40, 120, 1, "", function() World:ApplyFOV() end)
	UI:Section(w.Page, "Crosshair")
	UI:Toggle(w.Page, "Własny crosshair", "Crosshair")
	UI:Dropdown(w.Page, "Styl", "CrosshairStyle", { "Krzyż", "X" })
	UI:Color(w.Page, "Kolor", "ColorCross")

	-- HITBOX
	local h = UI:Tab("Hitbox", "⬚")
	UI:Section(h.Page, "Hitbox Editor")
	UI:Toggle(h.Page, "Hitbox", "Hitbox", function(on)
		HB:Refresh()
		if on then Cfg.Set("HitboxPreview", true) end
	end)
	UI:Slider(h.Page, "Szerokość", "HitboxW", 0.5, 20, 0.5, "", function() HB:Refresh() end)
	UI:Slider(h.Page, "Wysokość", "HitboxH", 0.5, 20, 0.5, "", function() HB:Refresh() end)
	UI:Slider(h.Page, "Głębokość", "HitboxD", 0.5, 20, 0.5, "", function() HB:Refresh() end)
	UI:Toggle(h.Page, "Podgląd", "HitboxPreview")
	UI:Section(h.Page, "Części")
	for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }) do
		local row = UI:Card(h.Page, 30)
		U.New("TextLabel", {
			Size = UDim2.new(1, -40, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			BackgroundTransparency = 1,
			Text = name,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = TH.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local b = U.New("TextButton", {
			Size = UDim2.fromOffset(26, 20),
			Position = UDim2.new(1, -38, 0.5, -10),
			BackgroundColor3 = table.find(Cfg.Get("HitboxParts"), name) and TH.AccD or TH.Hover,
			Text = table.find(Cfg.Get("HitboxParts"), name) and "✓" or "",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = TH.Acc,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, row)
		U.Corner(b, 6)
		b.MouseButton1Click:Connect(function()
			local list = table.clone(Cfg.Get("HitboxParts"))
			local i = table.find(list, name)
			if i then table.remove(list, i) else table.insert(list, name) end
			Cfg.Set("HitboxParts", list)
			b.BackgroundColor3 = i and TH.Hover or TH.AccD
			b.Text = i and "" or "✓"
			HB:Refresh()
		end)
	end
	UI:Button(h.Page, "Przywróć domyślne", function()
		Cfg.Set("HitboxW", 4); Cfg.Set("HitboxH", 6); Cfg.Set("HitboxD", 4)
		Cfg.Set("Hitbox", false)
		HB:Refresh()
	end)

	-- CONFIG
	local c = UI:Tab("Config", "⚙")
	UI:Section(c.Page, "Ustawienia")
	UI:Button(c.Page, "Zapisz konfigurację", function()
		Cfg.Save()
		UI:Toast("Konfiguracja", "Zapisano pomyślnie")
	end)
	UI:Button(c.Page, "Wczytaj konfigurację", function()
		local d = Store.Load()
		if not d then UI:Toast("Konfiguracja", "Brak zapisanego pliku", true) return end
		for k, val in pairs(d) do
			if DEF[k] ~= nil and type(val) == type(DEF[k]) then data[k] = val end
		end
		CS.Signal.Changed:Fire("__all__", nil)
		HB:Refresh()
		World:ApplyLight()
		UI:Toast("Konfiguracja", "Wczytano")
	end)
	UI:Button(c.Page, "Reset", function()
		Cfg.Reset()
		HB:Refresh()
		World:ApplyLight()
		UI:Toast("Konfiguracja", "Przywrócono domyślne")
	end, true)
	UI:Section(c.Page, "Wydajność")
	UI:Toggle(c.Page, "Tryb wydajności (40 Hz)", "PerfMode")
	UI:Section(c.Page, "Klawisze")
	UI:Keybind(c.Page, "Otwórz / zamknij GUI", "UIKey")
	UI:Keybind(c.Page, "Silent Aim (hold)", "AimKey")
	UI:Keybind(c.Page, "Aimbot (hold)", "AimbotKey")
	UI:Keybind(c.Page, "Wyładuj skrypt", "UnloadKey")
	UI:Section(c.Page, "Znajomi")
	local pl = U.New("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, c.Page)
	local pll = Instance.new("UIListLayout")
	pll.Padding = UDim.new(0, 4)
	pll.Parent = pl
	pll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		pl.Size = UDim2.new(1, 0, 0, pll.AbsoluteContentSize.Y)
	end)
	task.spawn(function()
		while CS.Alive do
			for _, ch in ipairs(pl:GetChildren()) do
				if ch:IsA("TextButton") then ch:Destroy() end
			end
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LP then
					local fr = T.IsFriend(p)
					local b = U.New("TextButton", {
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundColor3 = fr and TH.AccD or TH.Card,
						Text = "  " .. (fr and "★  " or "☆  ") .. p.Name,
						Font = Enum.Font.Gotham,
						TextSize = 11,
						TextColor3 = fr and TH.Acc or TH.Dim,
						TextXAlignment = Enum.TextXAlignment.Left,
						AutoButtonColor = false,
						BorderSizePixel = 0,
					}, pl)
					U.Corner(b, 7)
					b.MouseButton1Click:Connect(function()
						local list = table.clone(Cfg.Get("Friends"))
						local i = table.find(list, p.UserId)
						if i then table.remove(list, i) else table.insert(list, p.UserId) end
						Cfg.Set("Friends", list)
						b.BackgroundColor3 = i and TH.Card or TH.AccD
						b.TextColor3 = i and TH.Dim or TH.Acc
						b.Text = "  " .. (i and "☆  " or "★  ") .. p.Name
					end)
				end
			end
			task.wait(2)
		end
	end)

	-- INFO
	local i = UI:Tab("Info", "ℹ")
	UI:Section(i.Page, "CHEŁMSKI SIEKATOR V5")
	UI:Label(i.Page, "Wersja " .. CS.Version .. " · hardened build", true)
	UI:Label(i.Page, "Silent Aim przechwytuje Mouse.Hit, Mouse.UnitRay, Mouse.Target oraz Camera.CFrame.")
	UI:Label(i.Page, "Jeśli executor nie wspiera hooków, aimbot nadal działa kamerowo.")
	UI:Label(i.Page, "ESP korzysta z Drawing, a przy jego braku z renderera Frame — działa wszędzie.")
	UI:Label(i.Page, "Hitbox zmienia części lokalnie; w grach z walidacją serwerową potrzebny jest skrypt serwera.")
	UI:Section(i.Page, "Skróty domyślne")
	UI:Label(i.Page, "RightShift — GUI · E — silent aim · X — aimbot · Delete — wyładuj", true)
	UI:Button(i.Page, "Wyładuj skrypt", function() CS:Destroy() end, true)

	UI:Select(UI.Tabs[1])
end

--==========================================================
-- 17. CYKL ŻYCIA
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
	pcall(function() for _, p in pairs(HB.Orig) do if p.Parent then p.Size = p end end end)
	pcall(Draw.Purge)

	if UI.Gui then pcall(function() UI.Gui:Destroy() end) end
	getgenv().CHELMSKI = nil
end

function CS:Start()
	Draw.Init()
	OV:Init()
	HB:Init()

	if Cfg.Get("ESP") then ESP:Start() end
	if Cfg.Get("Aimbot") then AB:Start() end
	if Cfg.Get("Wallhack") then World:Start() end
	if Cfg.Get("Fullbright") or Cfg.Get("NoFog") then World:ApplyLight() end

	U.Safe(build)

	CS.Signal.Changed:Connect(function(key)
		if key == "__all__" then
			for _, fn in pairs(UI.Refreshers) do pcall(fn) end
			return
		end
		local fn = UI.Refreshers[key]
		if fn then pcall(fn) end
	end)

	-- pętla główna
	local frames, acc = 0, 0
	U.Track(RunService.RenderStepped:Connect(function(dt)
		if not self.Alive then return end
		frames += 1
		acc += dt
		if acc >= 0.5 then
			CS.FPS = frames / acc
			frames, acc = 0, 0
		end
		U.Safe(SA.Update, SA)
		U.Safe(OV.Step, OV)
		U.Safe(WM.Step, WM)
	end))

	U.Track(task.spawn(function()
		while self.Alive do
			U.Safe(HB.PreviewStep, HB)
			task.wait(0.1)
		end
	end))

	U.Track(task.spawn(function()
		while self.Alive do
			if Workspace.CurrentCamera and Workspace.CurrentCamera ~= Camera then
				Camera = Workspace.CurrentCamera
				if Cfg.Get("CamFOV") ~= 70 then World:ApplyFOV() end
			end
			task.wait(0.5)
		end
	end))

	-- klawisze
	U.Track(Input.InputBegan:Connect(function(i, processed)
		if processed or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local n = i.KeyCode.Name
		if n == Cfg.Get("UIKey") then
			UI:ToggleOpen()
		elseif n == Cfg.Get("AimKey") then
			SA.KeyDown = true
		elseif n == Cfg.Get("AimbotKey") then
			AB.KeyDown = true
		elseif n == Cfg.Get("UnloadKey") then
			CS:Destroy()
		end
	end))

	U.Track(Input.InputEnded:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local n = i.KeyCode.Name
		if n == Cfg.Get("AimKey") then SA.KeyDown = false
		elseif n == Cfg.Get("AimbotKey") then AB.KeyDown = false
		end
	end))

	U.Track(Players.PlayerRemoving:Connect(function(p)
		task.defer(function() if ESP.Pool[p] then ESP:Drop(p) end end)
	end))

	U.Track(game:BindToClose(function() pcall(Cfg.Save) end))

	UI:Toast("CHEŁMSKI SIEKATOR", "v" .. CS.Version .. " gotowy · " .. Cfg.Get("UIKey"))
end

getgenv().CHELMSKI = CS
U.Safe(CS.Start, CS)

return CS
