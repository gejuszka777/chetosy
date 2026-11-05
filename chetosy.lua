--[[
	CHEŁMSKI SIEKATOR V6 — SHOWCASE
	Roblox Luau PvP toolkit (client / executor)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/gejuszka777/chetosy/main/chetosy.lua?v=6"))()
]]

if getgenv().CHELMSKI then pcall(function() getgenv().CHELMSKI:Destroy() end) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tween      = game:GetService("TweenService")
local Input      = game:GetService("UserInputService")
local Http       = game:GetService("HttpService")
local Workspace  = game:GetService("Workspace")
local Lighting   = game:GetService("Lighting")
local CoreGui    = game:GetService("CoreGui")
local Stats      = game:GetService("Stats")
local RS         = game:GetService("ReplicatedStorage")
local TCS        = game:GetService("TextChatService")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LP:GetMouse()

local newcclosure = newcclosure or function(f) return f end
local gethui = gethui or function() return CoreGui end

local CS = { Version = "6.0", Alive = true, Destroyed = false, Conns = {}, FPS = 60 }
CS.__index = CS

--==========================================================
-- 1. UTIL
--==========================================================
local U = {}

function U.New(c, p, par)
	local i = Instance.new(c)
	for k, v in pairs(p or {}) do if k ~= "Parent" then i[k] = v end end
	if par then i.Parent = par end
	return i
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

function U.Tween(i, t, p, style, dir)
	local tw = Tween:Create(i, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), p)
	tw:Play()
	return tw
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

function U.Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warn("[SIEKATOR] " .. tostring(err)) end
	return ok
end

function U.Col(t)
	if type(t) ~= "table" then return Color3.fromRGB(61, 255, 158) end
	return Color3.fromRGB(t[1] or 61, t[2] or 255, t[3] or 158)
end

function U.Hue(h) return Color3.fromHSV(h % 1, 0.7, 1) end

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
	for _, fn in ipairs(table.clone(self._h)) do task.spawn(fn, ...) end
end

CS.Signal = { Changed = Signal.new(), Unload = Signal.new() }

--==========================================================
-- 3. STORAGE + CONFIG
--==========================================================
local FILE = "ChelmskiSiekatorV6.json"
local Store = {}

function Store.Save(d)
	if not writefile then getgenv().CHELMSKI_CFG = d return end
	local ok, e = pcall(Http.JSONEncode, Http, d)
	if ok then pcall(writefile, FILE, e) end
end

function Store.Load()
	if readfile then
		local ok, raw = pcall(readfile, FILE)
		if ok and raw and raw ~= "" then
			local ok2, d = pcall(Http.JSONDecode, Http, raw)
			if ok2 and type(d) == "table" then return d end
		end
	end
	return getgenv().CHELMSKI_CFG
end

local DEF = {
	SilentAim = false, SilentFOV = 150, SilentRange = 900, SilentPart = "Head",
	SilentChance = 100, SilentVisible = false, SilentHold = false, SilentViz = true,
	CircleOn = true, CircleStyle = "Cienkie",
	Aimbot = false, AimbotMode = "Hold", AimbotSmooth = 0.18, AimbotStyle = "Wykładniczy",
	AimbotFOV = 120, AimbotRange = 900, AimbotPart = "Head", AimbotVisible = true, AimbotHumanize = 0.15,
	ESP = false, ESPBox = true, ESPBoxStyle = "Pełny", ESPSkeleton = true, ESPName = true,
	ESPDistance = true, ESPHealth = true, ESPTracer = false, ESPHeadDot = false,
	ESPArrows = true, ESPAlpha = 0.9, ESPMaxDist = 1500, ESPTeamCheck = true, ESPRainbow = false,
	ColorEnemy = { 61, 255, 158 }, ColorTeam = { 90, 170, 255 },
	ColorSkel = { 255, 255, 255 }, ColorTracer = { 61, 255, 158 },
	Wallhack = false, WHPlayers = true, WHBots = true, WHObjects = false,
	WHFill = 0.55, WHDepth = "Zawsze", ColorWH = { 61, 255, 158 },
	Fullbright = false, NoFog = false, Crosshair = false, CrosshairStyle = "Krzyż",
	ColorCross = { 61, 255, 158 }, CamFOV = 70,
	Hitbox = false, HitboxW = 4, HitboxH = 6, HitboxD = 4, HitboxPreview = true,
	HitboxParts = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
	PerfMode = false, Friends = {}, BigHead = false,
	UIKey = "RightShift", AimKey = "E", AimbotKey = "X", UnloadKey = "Delete",
	ExportStr = "", WinX = 0, WinY = 0, WinSet = false,
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
function Cfg.Set(k, v) data[k] = v CS.Signal.Changed:Fire(k, v) end
function Cfg.Reset()
	for k, v in pairs(DEF) do data[k] = type(v) == "table" and table.clone(v) or v end
	CS.Signal.Changed:Fire("__all__", nil)
end
function Cfg.Save() Store.Save(data) end
CS.Cfg = Cfg

--==========================================================
-- 4. DRAW
--==========================================================
local Draw = { Has = false, Layer = nil, Pool = {} }

pcall(function()
	Draw.Has = type(Drawing) == "table" and type(Drawing.new) == "function"
	local p = Drawing.new("Square")
	p:Remove()
end)

local function apply(o, k, v)
	local i = o.Inst
	if k == "Visible" then i.Visible = v
	elseif k == "Position" then i.Position = UDim2.fromOffset(v.X, v.Y)
	elseif k == "Size" then i.Size = UDim2.fromOffset(math.max(v.X, 0), math.max(v.Y, 0))
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
	elseif k == "Outline" then i.TextStrokeTransparency = v and 0 or 1
	elseif k == "Radius" then
		local p = o.Props
		i.Position = UDim2.fromOffset((p.Position or Vector2.new()).X - v, (p.Position or Vector2.new()).Y - v)
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
				if self.Inst then self.Inst:Destroy() end
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
		i.Size = UDim2.fromOffset(220, 16)
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
	i.Parent = Draw.Layer
	o.Inst = i
	return setmetatable(o, MT)
end

function Draw.Init()
	if Draw.Has then return end
	local g = Instance.new("ScreenGui")
	g.Name = "ChelmskiSiekatorV6_Draw"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 9990
	local ok = pcall(function() g.Parent = gethui() end)
	if not ok then g.Parent = LP:WaitForChild("PlayerGui") end
	Draw.Layer = g
end

function Draw.New(kind, props, noPool)
	local o
	if Draw.Has then
		local ok, d = pcall(Drawing.new, kind)
		if ok and d then o = d end
	end
	if not o then
		if not Draw.Layer then Draw.Init() end
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
-- 5. TARGETING
--==========================================================
local T = {}
local CHAIN = {
	Head = { "Head" },
	HumanoidRootPart = { "HumanoidRootPart" },
	UpperTorso = { "UpperTorso", "Torso", "HumanoidRootPart" },
	Blisko = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
}

function T.Part(ch, mode)
	if not ch then return nil end
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

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist

function T.Visible(part)
	if not part then return false end
	local f = {}
	if LP.Character then table.insert(f, LP.Character) end
	if part.Parent then table.insert(f, part.Parent) end
	rp.FilterDescendantsInstances = f
	local hit = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
	return hit == nil or hit.Instance:IsDescendantOf(part.Parent)
end

function T.Friend(p) return table.find(Cfg.Get("Friends"), p.UserId) ~= nil end

function T.Best(o)
	local best, bs
	local cp = Camera.CFrame.Position
	local vp = Camera.ViewportSize
	local mid = Vector2.new(vp.X / 2, vp.Y / 2)
	local myTeam = LP.Team

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local ch = p.Character
			if U.Alive(ch) and not (o.teamCheck and p.Team == myTeam) and not T.Friend(p) then
				local part = T.Part(ch, o.part)
				if part then
					local dist = (part.Position - cp).Magnitude
					if dist <= o.range then
						local s, on = Camera:WorldToViewportPoint(part.Position)
						if on and s.Z > 0 then
							local fd = (Vector2.new(s.X, s.Y) - mid).Magnitude
							if fd <= o.fov then
								local sc = fd + dist * 0.04
								if o.visible and not T.Visible(part) then sc += 400 end
								if not bs or sc < bs then best, bs = { Player = p, Part = part }, sc end
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
-- 6. SILENT AIM / AIMBOT
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
	})
	if t then
		if not self.Rolled then self.Rolled = math.random(1, 100) <= Cfg.Get("SilentChance") end
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
				if key == "Hit" then return CFrame.new(t.Part.Position)
				elseif key == "Target" then return t.Part.Parent
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
		if ok then self.Hooked = true return true end
	end
	if hookmetamethod then
		local ok = pcall(function()
			local old
			old = hookmetamethod(game, "__index", SA:Handler(function(s, k) return old(s, k) end))
		end)
		if ok then self.Hooked = true return true end
	end
	return false
end

local AB = { Conn = nil, Target = nil, KeyDown = false, Jit = Vector2.new() }

function AB:Step(dt)
	if not Cfg.Get("Aimbot") or (Cfg.Get("AimbotMode") == "Hold" and not self.KeyDown) then
		self.Target = nil
		return
	end
	local t = T.Best({
		fov = Cfg.Get("AimbotFOV"), range = Cfg.Get("AimbotRange"), part = Cfg.Get("AimbotPart"),
		visible = Cfg.Get("AimbotVisible"), teamCheck = Cfg.Get("ESPTeamCheck"),
	})
	self.Target = t
	if not t then return end

	local hum = Cfg.Get("AimbotHumanize")
	if hum > 0 and math.random() < 0.15 then
		local a = math.random() * math.pi * 2
		self.Jit = Vector2.new(math.cos(a), math.sin(a)) * hum
	end

	local goal = CFrame.lookAt(Camera.CFrame.Position, t.Part.Position)
		* CFrame.Angles(math.rad(self.Jit.Y * 0.4), math.rad(self.Jit.X * 0.4), 0)

	local sm = math.clamp(Cfg.Get("AimbotSmooth"), 0.005, 1)
	local a
	if Cfg.Get("AimbotStyle") == "Liniowy" then a = math.clamp(dt / sm, 0, 1)
	elseif Cfg.Get("AimbotStyle") == "Snap" then a = 1
	else a = 1 - math.exp(-dt / sm * 6) end

	SA.Busy = true
	Camera.CFrame = Camera.CFrame:Lerp(goal, a)
	SA.Busy = false
end

function AB:Start()
	if self.Conn then return end
	self.Conn = U.Track(RunService.RenderStepped:Connect(function(dt) U.Safe(AB.Step, AB, dt) end))
end

function AB:Stop()
	if self.Conn then self.Conn:Disconnect() self.Conn = nil end
	self.Target = nil
end

--==========================================================
-- 7. ESP
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

function ESP:Entry(p)
	local e = {
		Box = Draw.New("Square", { Filled = false, Thickness = 1 }),
		Fill = Draw.New("Square", { Filled = true, Thickness = 0 }),
		Name = Draw.New("Text", { Center = true, Outline = true }),
		Dist = Draw.New("Text", { Center = true, Outline = true }),
		HpBg = Draw.New("Square", { Filled = true, Thickness = 0 }),
		HpFg = Draw.New("Square", { Filled = true, Thickness = 0 }),
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
	for _, k in ipairs({ "Box", "Fill", "Name", "Dist", "HpBg", "HpFg", "Dot", "Tracer", "Arrow" }) do
		e[k].Visible = false
	end
	for _, l in ipairs(e.C) do l.Visible = false end
	for _, l in ipairs(e.Bones) do l.Visible = false end
end

function ESP:Draw(p)
	local ch = p.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local head = ch and ch:FindFirstChild("Head")
	local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))

	local on = Cfg.Get("ESP") and U.Alive(ch) and head and root
	if on and Cfg.Get("ESPTeamCheck") and p.Team == LP.Team then on = false end
	if on and (root.Position - Camera.CFrame.Position).Magnitude > Cfg.Get("ESPMaxDist") then on = false end

	local e = self.Pool[p]
	if not on then if e then self:Hide(e) end return end
	e = e or self:Entry(p)

	local hs, ho = Camera:WorldToViewportPoint(head.Position)
	local rs, ro = Camera:WorldToViewportPoint(root.Position)
	if not ho or not ro or hs.Z <= 0 then self:Hide(e) return end

	local col
	if Cfg.Get("ESPRainbow") then
		col = U.Hue(os.clock() * 0.35 + (p.UserId % 100) / 100)
	elseif T.Friend(p) then
		col = Color3.fromRGB(255, 210, 60)
	elseif p.Team == LP.Team then
		col = U.Col(Cfg.Get("ColorTeam"))
	else
		col = U.Col(Cfg.Get("ColorEnemy"))
	end

	local tr = 1 - Cfg.Get("ESPAlpha")
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

	e.Name.Visible = Cfg.Get("ESPName")
	e.Name.Color = col
	e.Name.Transparency = tr
	e.Name.Text = T.Friend(p) and ("★ " .. p.DisplayName) or p.DisplayName
	e.Name.Position = top - Vector2.new(0, 18)

	e.Dist.Visible = Cfg.Get("ESPDistance")
	e.Dist.Color = col
	e.Dist.Transparency = tr
	e.Dist.Text = string.format("%d m", math.floor((root.Position - Camera.CFrame.Position).Magnitude / 3))
	e.Dist.Position = br + Vector2.new(0, 2)

	if Cfg.Get("ESPHealth") and hum then
		local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
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
	if Cfg.Get("PerfMode") then
		self.Acc += dt
		if self.Acc < 1 / 40 then return end
		self.Acc = 0
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then U.Safe(ESP.Draw, ESP, p) end
	end
end

function ESP:Start()
	if self.Conn then return end
	self.Conn = U.Track(RunService.RenderStepped:Connect(function(dt) U.Safe(ESP.Step, ESP, dt) end))
end

function ESP:Stop()
	if self.Conn then self.Conn:Disconnect() self.Conn = nil end
	for p in pairs(self.Pool) do self:Drop(p) end
end

--==========================================================
-- 8. WORLD
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

function World:Step()
	if not Cfg.Get("Wallhack") then
		if next(self.Pool) then self:ClearHL() end
		return
	end
	local col = Cfg.Get("ESPRainbow") and U.Hue(os.clock() * 0.35) or U.Col(Cfg.Get("ColorWH"))
	local fill = Cfg.Get("WHFill")
	local depth = Cfg.Get("WHDepth") == "Zawsze"
		and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded

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
	for _, h in pairs(self.Pool) do
		h.FillTransparency = fill
		if Cfg.Get("ESPRainbow") then h.FillColor = col h.OutlineColor = col end
	end
end

function World:Light()
	Lighting.Brightness = Cfg.Get("Fullbright") and 3 or 1
	Lighting.GlobalShadows = not Cfg.Get("Fullbright")
	if Cfg.Get("NoFog") then Lighting.FogEnd = 100000 Lighting.FogStart = 0 end
end

function World:FOV() if Camera then Camera.FieldOfView = Cfg.Get("CamFOV") end end

function World:Start()
	if self.Loop then return end
	self.Loop = U.Track(task.spawn(function()
		while CS.Alive do
			U.Safe(World.Step, World)
			task.wait(0.5)
		end
	end))
end

function World:Stop()
	if self.Loop then self.Loop:Disconnect() self.Loop = nil end
	self:ClearHL()
end

--==========================================================
-- 9. HITBOX
--==========================================================
local HB = { Orig = {}, Done = {}, Preview = {} }
local PARTS = { "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart",
	"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }

function HB:Apply(ch)
	if not ch or self.Done[ch] then return end
	self.Done[ch] = true
	local w, h, d = Cfg.Get("HitboxW"), Cfg.Get("HitboxH"), Cfg.Get("HitboxD")
	local sel = Cfg.Get("HitboxParts")
	for _, n in ipairs(PARTS) do
		if table.find(sel, n) then
			local p = ch:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				self.Orig[p] = self.Orig[p] or p.Size
				p.Size = Vector3.new(w, h, d)
				p.CanCollide = false
			end
		end
	end
end

function HB:Restore(ch)
	if not ch then return end
	self.Done[ch] = nil
	for p, s in pairs(self.Orig) do
		if p and p.Parent and p:IsDescendantOf(ch) then
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
	for _, d in ipairs(self.Preview) do pcall(function() d:Remove() end) end
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
-- 10. FUN
--==========================================================
local Fun = { Disco = false }

local LINES = {
	"gg ez", "ale wpierdol", "aim diff", "to był lag", "oddajcie hp",
	"siekator mode on", "l2p", "1v1?", "no i po co było", "siema cieniasy",
	"kręci się w głowie", "nie da się ze mną grać",
}

function Fun:Say(msg)
	pcall(function()
		local ev = RS:FindFirstChild("DefaultChatSystemChatEvents")
		if ev and ev:FindFirstChild("SayMessageRequest") then
			ev.SayMessageRequest:FireServer(msg, "All")
			return
		end
		error("no event")
	end)
	pcall(function()
		if TCS.ChatInputBarConfiguration and TCS.ChatInputBarConfiguration.TargetTextChannel then
			TCS.ChatInputBarConfiguration.TargetTextChannel:SendAsync(msg)
		end
	end)
end

function Fun:Taunt()
	self:Say(LINES[math.random(1, #LINES)])
end

function Fun:BigHead(on)
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
	local t0 = os.clock()
	local c = RunService.RenderStepped:Connect(function()
		if os.clock() - t0 > 0.7 then c:Disconnect() return end
		Camera.CFrame = Camera.CFrame * CFrame.new(
			(math.random() - 0.5) * 0.9,
			(math.random() - 0.5) * 0.9,
			0
		)
	end)
end

function Fun:Disco(on)
	self.Disco = on
	if not on then
		Lighting.Ambient = Color3.fromRGB(70, 70, 70)
		return
	end
	task.spawn(function()
		while self.Disco and CS.Alive do
			Lighting.Ambient = U.Hue(os.clock() * 0.9)
			Lighting.OutdoorAmbient = U.Hue(os.clock() * 0.9 + 0.5)
			task.wait(0.08)
		end
		Lighting.Ambient = Color3.fromRGB(70, 70, 70)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end)
end

--==========================================================
-- 11. THEME
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

--==========================================================
-- 12. UI
--==========================================================
local UI = { Tabs = {}, Ref = {}, Toasts = {}, Min = false }

function UI:Bind(k, fn) self.Ref[k] = fn end

function UI:Root()
	local g = Instance.new("ScreenGui")
	g.Name = "ChelmskiSiekatorV6"
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
		Size = UDim2.fromOffset(680, 470),
		Position = UDim2.new(0.5, -340, 0.5, -235),
		BackgroundColor3 = TH.Bg,
		BorderSizePixel = 0,
	}, holder)
	U.Corner(main, 18)
	local mainStroke = U.Stroke(main, TH.Line, 1, 0.3)
	main.ClipsDescendants = true

	-- dekoracyjne bloby
	for i = 1, 3 do
		local b = U.New("Frame", {
			Size = UDim2.fromOffset(200 + i * 45, 200 + i * 45),
			Position = UDim2.fromOffset(-70 + i * 190, -90 + i * 40),
			BackgroundColor3 = TH.Acc,
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, main)
		U.Corner(b, 999)
	end

	-- pasek akcentu
	local accent = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = TH.Acc,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, main)
	U.Grad(accent, TH.Acc, Color3.fromRGB(120, 255, 200), 0)

	-- nagłówek
	local bar = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = TH.Panel,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, main)
	U.Grad(bar, Color3.fromRGB(24, 31, 39), TH.Bg, 90)

	local logo = U.New("Frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(18, 15),
		BackgroundColor3 = TH.Acc,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, bar)
	U.Corner(logo, 11)
	U.New("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "◤",
		Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = TH.Bg, ZIndex = 6,
	}, logo)

	local title = U.New("TextLabel", {
		Size = UDim2.fromOffset(280, 20), Position = UDim2.fromOffset(62, 13),
		BackgroundTransparency = 1, Text = "CHEŁMSKI SIEKATOR",
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	}, bar)

	local sub = U.New("TextLabel", {
		Size = UDim2.fromOffset(280, 16), Position = UDim2.fromOffset(62, 33),
		BackgroundTransparency = 1, Text = "XYZ PVP   ·   v" .. CS.Version .. " showcase",
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
		b.MouseButton1Click:Connect(function() U.Safe(cb) end)
		return b
	end
	barBtn("–", -74, function() UI:Minimize() end)
	barBtn("✕", -42, function() UI:Close() end, true)

	-- sidebar
	local side = U.New("Frame", {
		Size = UDim2.new(0, 176, 1, -90),
		Position = UDim2.fromOffset(0, 64),
		BackgroundColor3 = TH.Panel,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, main)
	U.Grad(side, Color3.fromRGB(18, 23, 30), TH.Bg, 90)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 11)
	pad.PaddingRight = UDim.new(0, 11)
	pad.Parent = side
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 5)
	lay.Parent = side

	local content = U.New("Frame", {
		Size = UDim2.new(1, -176, 1, -90),
		Position = UDim2.fromOffset(176, 64),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, main)

	-- stopka
	local foot = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -26),
		BackgroundColor3 = TH.Panel,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, main)
	U.Grad(foot, TH.Bg, Color3.fromRGB(20, 26, 33), 90)
	local fdot = U.New("Frame", {
		Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(18, 10),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0, ZIndex = 4,
	}, foot)
	U.Corner(fdot, 3)
	U.New("TextLabel", {
		Size = UDim2.fromOffset(300, 26), Position = UDim2.fromOffset(30, 0),
		BackgroundTransparency = 1, Text = "gotowy  ·  hardened build",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = TH.Dim,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
	}, foot)
	U.New("TextLabel", {
		Size = UDim2.fromOffset(120, 26), Position = UDim2.new(1, -132, 0, 0),
		BackgroundTransparency = 1, Text = "VENICE",
		Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = TH.AccD,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
	}, foot)

	-- pulsowanie logo + kropki
	task.spawn(function()
		while CS.Alive do
			U.Tween(logo, 0.9, { BackgroundColor3 = Color3.fromRGB(130, 255, 200) }, Enum.EasingStyle.Sine)
			U.Tween(fdot, 0.9, { BackgroundTransparency = 0.7 }, Enum.EasingStyle.Sine)
			task.wait(0.95)
			U.Tween(logo, 0.9, { BackgroundColor3 = TH.Acc }, Enum.EasingStyle.Sine)
			U.Tween(fdot, 0.9, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
			task.wait(0.95)
		end
	end)

	-- przeciąganie (cały ekran, z clampem)
	local drag, startPos, basePos = false, nil, nil

	local function begin(i)
		drag = true
		startPos = i.Position
		basePos = main.AbsolutePosition
	end

	for _, h in ipairs({ bar, logo, title, sub }) do
		h.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				begin(i)
			end
		end)
	end

	Input.InputChanged:Connect(function(i)
		if not drag then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			local d = i.Position - startPos
			local x = math.clamp(basePos.X + d.X, 0, math.max(vp.X - main.AbsoluteSize.X, 0))
			local y = math.clamp(basePos.Y + d.Y, 0, math.max(vp.Y - main.AbsoluteSize.Y, 0))
			main.Position = UDim2.fromOffset(x, y)
			Cfg.Set("WinX", math.floor(x))
			Cfg.Set("WinY", math.floor(y))
			Cfg.Set("WinSet", true)
		end
	end)

	Input.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			if drag then
				drag = false
				U.Tween(mainStroke, 0.25, { Transparency = 0.3 })
			end
		end
	end)

	return g, holder, main, side, content
end

function UI:Init()
	self.Gui, self.Holder, self.Main, self.Side, self.Content = self:Root()
	self.Main.Size = UDim2.fromOffset(680, 300)
	self.Holder.GroupTransparency = 1
	U.Tween(self.Main, 0.45, { Size = UDim2.fromOffset(680, 470) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	U.Tween(self.Holder, 0.28, { GroupTransparency = 0 })

	if Cfg.Get("WinSet") then
		local vp = Camera.ViewportSize
		local x = math.clamp(Cfg.Get("WinX"), 0, math.max(vp.X - 680, 0))
		local y = math.clamp(Cfg.Get("WinY"), 0, math.max(vp.Y - 470, 0))
		self.Main.Position = UDim2.fromOffset(x, y)
	end
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
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = TH.Card, BackgroundTransparency = 1,
		Text = "", Font = Enum.Font.GothamMedium, TextSize = 13,
		TextColor3 = TH.Dim, AutoButtonColor = false, BorderSizePixel = 0,
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
	U.New("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(36, 0),
		BackgroundTransparency = 1, Text = name, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = TH.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
	}, btn)

	local marker = U.New("Frame", {
		Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, -1, 0.5, -10),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0, ZIndex = 4,
	}, btn)
	U.Corner(marker, 2)

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

	local tab = { Btn = btn, Page = page, Marker = marker, Badge = badge, Name = btn:FindFirstChildOfClass("TextLabel") }
	table.insert(self.Tabs, tab)

	btn.MouseEnter:Connect(function()
		if self.Active ~= tab then
			U.Tween(btn, 0.12, { TextColor3 = TH.Text, BackgroundTransparency = 0.88 })
			U.Tween(badge, 0.12, { BackgroundColor3 = TH.AccD })
		end
	end)
	btn.MouseLeave:Connect(function()
		if self.Active ~= tab then
			U.Tween(btn, 0.12, { TextColor3 = TH.Dim, BackgroundTransparency = 1 })
			U.Tween(badge, 0.12, { BackgroundColor3 = TH.Hover })
		end
	end)
	btn.MouseButton1Click:Connect(function() self:Select(tab) end)

	-- wejście
	btn.Position = UDim2.fromOffset(-40, 0)
	task.delay(#self.Tabs * 0.05, function()
		if btn.Parent then U.Tween(btn, 0.35, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back) end
	end)

	return tab
end

function UI:Select(tab)
	if self.Active == tab then return end
	if self.Active then
		self.Active.Page.Visible = false
		U.Tween(self.Active.Btn, 0.12, { TextColor3 = TH.Dim, BackgroundTransparency = 1 })
		U.Tween(self.Active.Badge, 0.12, { BackgroundColor3 = TH.Hover })
		U.Tween(self.Active.Marker, 0.15, { Size = UDim2.new(0, 3, 0, 0) })
	end
	self.Active = tab
	tab.Page.Visible = true
	U.Tween(tab.Btn, 0.12, { TextColor3 = TH.Acc, BackgroundTransparency = 0.7 })
	U.Tween(tab.Badge, 0.12, { BackgroundColor3 = TH.AccD })
	U.Tween(tab.Marker, 0.2, { Size = UDim2.new(0, 3, 0, 20) }, Enum.EasingStyle.Back)
	tab.Page.Position = UDim2.fromOffset(30, 13)
	U.Tween(tab.Page, 0.22, { Position = UDim2.fromOffset(16, 13) })
end

function UI:Section(page, text)
	local f = U.New("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }, page)
	U.New("Frame", {
		Size = UDim2.fromOffset(3, 11), Position = UDim2.fromOffset(0, 3),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0,
	}, f)
	U.New("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(11, 0),
		BackgroundTransparency = 1, Text = text:upper(), Font = Enum.Font.GothamBold,
		TextSize = 10, TextColor3 = TH.Acc, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
end

function UI:Card(page, h)
	local f = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, h or 36), BackgroundColor3 = TH.Card, BorderSizePixel = 0,
	}, page)
	U.Corner(f, 10)
	local s = U.Stroke(f, TH.Line, 1, 0.55)
	U.Grad(f, Color3.fromRGB(27, 33, 41), TH.Card, 90)
	f.MouseEnter:Connect(function() U.Tween(s, 0.15, { Transparency = 0.2, Color = TH.AccD }) end)
	f.MouseLeave:Connect(function() U.Tween(s, 0.15, { Transparency = 0.55, Color = TH.Line }) end)
	return f
end

function UI:Toggle(page, label, key, cb)
	local row = self:Card(page, 36)
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
end

function UI:Slider(page, label, key, min, max, step, suffix, cb)
	local row = self:Card(page, 50)
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
	U.Grad(fill, TH.AccD, TH.Acc, 0)

	local knob = U.New("Frame", {
		Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, -6, 0.5, -6),
		BackgroundColor3 = TH.Text, BorderSizePixel = 0, ZIndex = 2,
	}, track)
	U.Corner(knob, 6)

	local dragging = false

	local function set(v, fire, silent)
		v = math.clamp(U.Round(v, step), min, max)
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
		local r = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		set(min + (max - min) * r, true, false)
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

function UI:Dropdown(page, label, key, opts, cb)
	local row = U.New("Frame", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = TH.Card,
		BorderSizePixel = 0, ClipsDescendants = true,
	}, page)
	U.Corner(row, 10)
	U.Stroke(row, TH.Line, 1, 0.55)

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
end

local SWATCH = {
	{ 61, 255, 158 }, { 90, 170, 255 }, { 255, 96, 96 }, { 255, 200, 60 },
	{ 200, 120, 255 }, { 255, 255, 255 }, { 255, 120, 200 }, { 120, 255, 255 },
}

function UI:Color(page, label, key)
	local row = self:Card(page, 32)
	U.New("TextLabel", {
		Size = UDim2.fromOffset(126, 32), Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
		TextSize = 12, TextColor3 = TH.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local prev = U.New("Frame", {
		Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -32, 0.5, -9),
		BackgroundColor3 = U.Col(Cfg.Get(key)), BorderSizePixel = 0,
	}, row)
	U.Corner(prev, 9)
	U.Stroke(prev, TH.Line, 1)
	for i, rgb in ipairs(SWATCH) do
		local s = U.New("TextButton", {
			Size = UDim2.fromOffset(17, 17), Position = UDim2.fromOffset(140 + (i - 1) * 21, 7),
			BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
			Text = "", AutoButtonColor = false, BorderSizePixel = 0,
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
end

function UI:Button(page, label, cb, danger)
	local b = U.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = danger and Color3.fromRGB(64, 26, 30) or TH.Card,
		Text = label, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = danger and TH.Red or TH.Text, AutoButtonColor = false,
		BorderSizePixel = 0, ClipsDescendants = true,
	}, page)
	U.Corner(b, 10)
	U.Stroke(b, TH.Line, 1, 0.6)
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
	U.Tween(self.Main, 0.26, { Size = self.Min and UDim2.fromOffset(680, 64) or UDim2.fromOffset(680, 470) }, Enum.EasingStyle.Quart)
	self.Side.Visible = not self.Min
	self.Content.Visible = not self.Min
end

function UI:Close()
	U.Tween(self.Holder, 0.2, { GroupTransparency = 1 })
	U.Tween(self.Main, 0.2, { Size = UDim2.fromOffset(640, 440) }, Enum.EasingStyle.Quart)
	task.delay(0.21, function() if self.Gui then self.Gui.Enabled = false end end)
end

function UI:Open()
	if not self.Gui then return end
	self.Gui.Enabled = true
	self.Main.Size = UDim2.fromOffset(640, 440)
	self.Holder.GroupTransparency = 1
	U.Tween(self.Main, 0.34, { Size = UDim2.fromOffset(680, 470) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	U.Tween(self.Holder, 0.2, { GroupTransparency = 0 })
end

function UI:ToggleOpen()
	if not self.Gui then return end
	if self.Gui.Enabled then self:Close() else self:Open() end
end

function UI:Toast(title, body, danger)
	if not self.Gui then return end
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
-- 13. WATERMARK
--==========================================================
local WM = {}

function WM:Init()
	self.F = U.New("Frame", {
		Size = UDim2.fromOffset(210, 26), Position = UDim2.fromOffset(12, -40),
		BackgroundColor3 = TH.Bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}, UI.Gui)
	U.Corner(self.F, 8)
	U.Stroke(self.F, TH.Acc, 1, 0.6)
	self.D = U.New("Frame", {
		Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = TH.Acc, BorderSizePixel = 0,
	}, self.F)
	U.Corner(self.D, 3)
	self.T = U.New("TextLabel", {
		Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(22, 0),
		BackgroundTransparency = 1, Text = "SIEKATOR v" .. CS.Version,
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
	local ping = 0
	pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
	self.T.Text = string.format("SIEKATOR v%s  ·  %d FPS  ·  %d ms", CS.Version, math.floor(CS.FPS), ping)
end

--==========================================================
-- 14. BUILD
--==========================================================
local function build()
	UI:Init()
	WM:Init()

	local a = UI:Tab("Aim", "⌖")
	UI:Section(a.Page, "Silent Aim")
	UI:Toggle(a.Page, "Silent Aim", "SilentAim", function(on)
		if on and not SA:Install() then UI:Toast("Silent Aim", "Brak hooków — tryb kamerowy", true) end
	end)
	UI:Slider(a.Page, "Szansa trafienia", "SilentChance", 0, 100, 1, "%")
	UI:Slider(a.Page, "FOV", "SilentFOV", 20, 500, 5, " px")
	UI:Slider(a.Page, "Zasięg", "SilentRange", 50, 3000, 25, " st")
	UI:Dropdown(a.Page, "Część ciała", "SilentPart", { "Head", "UpperTorso", "HumanoidRootPart", "Blisko" })
	UI:Toggle(a.Page, "Tylko widoczni", "SilentVisible")
	UI:Toggle(a.Page, "Tylko na trzymanie", "SilentHold")
	UI:Toggle(a.Page, "Koło FOV", "CircleOn")
	UI:Dropdown(a.Page, "Styl koła", "CircleStyle", { "Cienkie", "Grube", "Kropkowane" })
	UI:Toggle(a.Page, "Wizualizacja celu", "SilentViz")

	UI:Section(a.Page, "Aimbot")
	UI:Toggle(a.Page, "Aimbot", "Aimbot", function(on) if on then AB:Start() else AB:Stop() end end)
	UI:Dropdown(a.Page, "Tryb", "AimbotMode", { "Hold", "Zawsze" })
	UI:Dropdown(a.Page, "Styl", "AimbotStyle", { "Wykładniczy", "Liniowy", "Snap" })
	UI:Slider(a.Page, "Płynność", "AimbotSmooth", 0.01, 1, 0.01, "")
	UI:Slider(a.Page, "Humanizacja", "AimbotHumanize", 0, 2, 0.05, "")
	UI:Slider(a.Page, "FOV", "AimbotFOV", 10, 400, 5, " px")
	UI:Slider(a.Page, "Zasięg", "AimbotRange", 50, 3000, 25, " st")
	UI:Dropdown(a.Page, "Punkt celowania", "AimbotPart", { "Head", "UpperTorso", "HumanoidRootPart", "Blisko" })
	UI:Toggle(a.Page, "Tylko widoczni", "AimbotVisible")

	local v = UI:Tab("Visuals", "✦")
	UI:Section(v.Page, "ESP")
	UI:Toggle(v.Page, "ESP", "ESP", function(on) if on then ESP:Start() else ESP:Stop() end end)
	UI:Dropdown(v.Page, "Styl boxa", "ESPBoxStyle", { "Pełny", "Narożniki", "Wypełniony" })
	UI:Toggle(v.Page, "Box", "ESPBox")
	UI:Toggle(v.Page, "Szkielet", "ESPSkeleton")
	UI:Toggle(v.Page, "Nazwa", "ESPName")
	UI:Toggle(v.Page, "Dystans", "ESPDistance")
	UI:Toggle(v.Page, "Pasek HP", "ESPHealth")
	UI:Toggle(v.Page, "Kropka na głowie", "ESPHeadDot")
	UI:Toggle(v.Page, "Tracer", "ESPTracer")
	UI:Toggle(v.Page, "Strzałki poza ekranem", "ESPArrows")
	UI:Toggle(v.Page, "Tęcza", "ESPRainbow")
	UI:Slider(v.Page, "Krycie", "ESPAlpha", 0.2, 1, 0.05, "")
	UI:Slider(v.Page, "Maks. dystans", "ESPMaxDist", 100, 5000, 50, " st")
	UI:Toggle(v.Page, "Team Check", "ESPTeamCheck")
	UI:Section(v.Page, "Kolory")
	UI:Color(v.Page, "Wróg", "ColorEnemy")
	UI:Color(v.Page, "Sojusznik", "ColorTeam")
	UI:Color(v.Page, "Szkielet", "ColorSkel")
	UI:Color(v.Page, "Tracer", "ColorTracer")

	local w = UI:Tab("World", "◈")
	UI:Section(w.Page, "Wallhack")
	UI:Toggle(w.Page, "Wallhack", "Wallhack", function(on) if on then World:Start() else World:Stop() end end)
	UI:Toggle(w.Page, "Gracze", "WHPlayers")
	UI:Toggle(w.Page, "Boty / NPC", "WHBots")
	UI:Toggle(w.Page, "Obiekty", "WHObjects")
	UI:Dropdown(w.Page, "Widoczność", "WHDepth", { "Zawsze", "Zasłonięte" })
	UI:Slider(w.Page, "Przezroczystość", "WHFill", 0, 1, 0.05, "")
	UI:Color(w.Page, "Kolor", "ColorWH")
	UI:Section(w.Page, "Światło")
	UI:Toggle(w.Page, "Fullbright", "Fullbright", function() World:Light() end)
	UI:Toggle(w.Page, "Bez mgły", "NoFog", function() World:Light() end)
	UI:Slider(w.Page, "FOV kamery", "CamFOV", 40, 120, 1, "", function() World:FOV() end)
	UI:Section(w.Page, "Crosshair")
	UI:Toggle(w.Page, "Własny crosshair", "Crosshair")
	UI:Dropdown(w.Page, "Styl", "CrosshairStyle", { "Krzyż", "X" })
	UI:Color(w.Page, "Kolor", "ColorCross")

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
	for _, n in ipairs({ "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }) do
		local row = UI:Card(h.Page, 30)
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
	UI:Button(h.Page, "Przywróć domyślne", function()
		Cfg.Set("HitboxW", 4) Cfg.Set("HitboxH", 6) Cfg.Set("HitboxD", 4) Cfg.Set("Hitbox", false)
		HB:Refresh()
	end)

	local f = UI:Tab("Fun", "☺")
	UI:Section(f.Page, "Zabawki")
	UI:Toggle(f.Page, "Tęcza wszędzie", "ESPRainbow")
	UI:Toggle(f.Page, "Wielkie głowy", "BigHead", function(on) Fun:BigHead(on) end)
	UI:Button(f.Page, "Trzęsienie kamery", function() Fun:Shake() end)
	UI:Button(f.Page, "Losowa zaczepka na czacie", function() Fun:Taunt() end)
	UI:Button(f.Page, "Disco (światło)", function()
		Fun:Disco(not Fun.Disco)
		UI:Toast("Disco", Fun.Disco and "Włączone" or "Wyłączone")
	end)
	UI:Button(f.Page, "Konfetti", function()
		local e = { "✦", "★", "✧", "☆", "✶", "✷" }
		for i = 1, 14 do
			UI:Toast(e[math.random(1, #e)] .. " konfetti", "siekator pozdrawia", i % 3 == 0)
			task.wait(0.07)
		end
	end)

	local c = UI:Tab("Config", "⚙")
	UI:Section(c.Page, "Ustawienia")
	UI:Button(c.Page, "Zapisz konfigurację", function() Cfg.Save() UI:Toast("Konfiguracja", "Zapisano") end)
	UI:Button(c.Page, "Wczytaj konfigurację", function()
		local d = Store.Load()
		if not d then UI:Toast("Konfiguracja", "Brak zapisu", true) return end
		for k, val in pairs(d) do if DEF[k] ~= nil and type(val) == type(DEF[k]) then data[k] = val end end
		CS.Signal.Changed:Fire("__all__", nil)
		HB:Refresh() World:Light()
		UI:Toast("Konfiguracja", "Wczytano")
	end)
	UI:Button(c.Page, "Reset", function()
		Cfg.Reset() HB:Refresh() World:Light()
		UI:Toast("Konfiguracja", "Przywrócono domyślne")
	end, true)
	UI:Section(c.Page, "Eksport / import")
	local box = U.New("TextBox", {
		Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = TH.Card, Text = Cfg.Get("ExportStr"),
		PlaceholderText = "wklej tutaj string konfiguracji", PlaceholderColor3 = TH.Dim,
		Font = Enum.Font.Code, TextSize = 10, TextColor3 = TH.Text,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0,
	}, c.Page)
	U.Corner(box, 8)
	UI:Button(c.Page, "Wyeksportuj do pola", function()
		local ok, enc = pcall(Http.JSONEncode, Http, data)
		if ok then box.Text = enc Cfg.Set("ExportStr", enc) end
	end)
	UI:Button(c.Page, "Importuj z pola", function()
		local ok, dec = pcall(Http.JSONDecode, Http, box.Text)
		if not ok or type(dec) ~= "table" then UI:Toast("Import", "Nieprawidłowy string", true) return end
		for k, val in pairs(dec) do if DEF[k] ~= nil and type(val) == type(DEF[k]) then data[k] = val end end
		CS.Signal.Changed:Fire("__all__", nil)
		HB:Refresh() World:Light()
		UI:Toast("Import", "Zaimportowano")
	end)
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
			for _, ch in ipairs(pl:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LP then
					local fr = T.Friend(p)
					local b = U.New("TextButton", {
						Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = fr and TH.AccD or TH.Card,
						Text = "  " .. (fr and "★  " or "☆  ") .. p.Name,
						Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = fr and TH.Acc or TH.Dim,
						TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0,
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

	local i = UI:Tab("Info", "ℹ")
	UI:Section(i.Page, "CHEŁMSKI SIEKATOR V6")
	UI:Label(i.Page, "Wersja " .. CS.Version .. " · hardened showcase", true)
	UI:Label(i.Page, "Silent Aim przechwytuje Mouse.Hit, Mouse.UnitRay, Mouse.Target i Camera.CFrame.")
	UI:Label(i.Page, "Brak hooków? Aimbot nadal pracuje na kamerze.")
	UI:Label(i.Page, "ESP używa Drawing, a bez niego renderera Frame — działa wszędzie.")
	UI:Label(i.Page, "Okno przeciągasz za nagłówek w dowolne miejsce ekranu; pozycja się zapisuje.")
	UI:Section(i.Page, "Skróty domyślne")
	UI:Label(i.Page, "RightShift — GUI · E — silent aim · X — aimbot · Delete — wyładuj", true)
	UI:Button(i.Page, "Wyładuj skrypt", function() CS:Destroy() end, true)

	UI:Select(UI.Tabs[1])
end

--==========================================================
-- 15. CYKL
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
	pcall(function() Fun:Disco(false) end)
	pcall(function()
		for p, s in pairs(HB.Orig) do
			if p and p.Parent then p.Size = s end
		end
	end)
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
	if Cfg.Get("Fullbright") or Cfg.Get("NoFog") then World:Light() end

	U.Safe(build)

	CS.Signal.Changed:Connect(function(k)
		if k == "__all__" then
			for _, fn in pairs(UI.Ref) do pcall(fn) end
			return
		end
		local fn = UI.Ref[k]
		if fn then pcall(fn) end
	end)

	local frames, acc = 0, 0
	U.Track(RunService.RenderStepped:Connect(function(dt)
		if not self.Alive then return end
		frames += 1
		acc += dt
		if acc >= 0.5 then CS.FPS = frames / acc frames, acc = 0, 0 end
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

	UI:Toast("CHEŁMSKI SIEKATOR", "v" .. CS.Version .. " gotowy · " .. Cfg.Get("UIKey"))
end

getgenv().CHELMSKI = CS
U.Safe(CS.Start, CS)

return CS
