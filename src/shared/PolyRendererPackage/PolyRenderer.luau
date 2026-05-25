--!optimize 2
--!nonstrict

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local PlayerGUI = script.Parent
local ScreenGUI = Instance.new("ScreenGui", PlayerGUI)
ScreenGUI.Name = "PolyRenderer"
ScreenGUI.ScreenInsets = Enum.ScreenInsets.None

local Viewport = Instance.new("ViewportFrame")
Viewport.CurrentCamera = workspace.CurrentCamera
Viewport.Size = UDim2.fromScale(1, 1)
Viewport.BackgroundTransparency = 1
Viewport.Parent = ScreenGUI
Viewport.ZIndex = -99

Viewport.Ambient = Color3.fromRGB(200,200,200)
Viewport.LightColor = game.Lighting.OutdoorAmbient
Viewport.LightDirection = Vector3.new(-0.5,-1,-0.5)

local World = Instance.new("WorldModel")
World.Parent = Viewport

local Camera = Instance.new("Camera")
Viewport.CurrentCamera = Camera

local PolyRenderer = {}

local REMOVED = {
	Attachment = true,
	BallSocketConstraint = true
}

local ObjectMap = {}
type RenderedInstance = {
	Original: Instance,
	Clone: Instance
}

local Instances: {RenderedInstance} = {}
local FRAME_RATE = 10
local accumulated = 0

PolyRenderer.SyncCameraWithFPS = true

local function UpdateCamera()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		Camera.CFrame = currentCamera.CFrame
	end
end

local function UpdateViewportLighting()
	Viewport.Ambient = Lighting.Ambient
	Viewport.LightColor = Lighting.OutdoorAmbient
end

-- Adds an instance to the renderer viewport.
-- Currently supports Models and BaseParts
function PolyRenderer.Add(instance: Instance)
	assert(World, "WorldModel does not exist")
	
	if not (instance:IsA("Model") or instance:IsA("BasePart")) then
        warn("[PolyRenderer] Invalid instance! Only Models and BaseParts are supported.")
        return
    end
        
	-- Assign IDs
	local id = 0
	local function assign(obj)
		id += 1
		obj:SetAttribute("__PolyID", id)

		for _, child : Instance in ipairs(obj:GetDescendants()) do
			id += 1
			child:SetAttribute("__PolyID", id)
		end
	end

	assign(instance)

	local cloned : Instance = instance:Clone()

	for _, obj in ipairs(cloned:GetDescendants()) do
		if obj:IsA("BaseScript") then
			obj.Disabled = true
		end
	end

	cloned.Parent = World

	-- bbuild lookup for clone IDs
	local cloneLookup = {}
	cloneLookup[cloned:GetAttribute("__PolyID")] = cloned
	for _, obj in ipairs(cloned:GetDescendants()) do
		local ID = obj:GetAttribute("__PolyID")

		if ID then
			cloneLookup[ID] = obj
		end
	end

	-- object map to replicate correctly
	ObjectMap[instance] = cloned
	for _, originalObj in ipairs(instance:GetDescendants()) do
		local ID = originalObj:GetAttribute("__PolyID")

		if ID then
			ObjectMap[originalObj] = cloneLookup[ID]
		end
	end
	
	for _, child in ipairs(cloned:GetDescendants()) do
		if REMOVED[child.ClassName] then
			child:Destroy()
		end
	end
    
	table.insert(Instances,{
		Original = instance,
		Clone = cloned
	})
end

-- Adds multiple objects to the renderer at once without needing to loop through each of them
-- Supports list of Instances or a folder.
function PolyRenderer.Adds(instances: {Instance} | Folder)
	if (instances :: Folder):IsA("Folder") then
		for _, child in ipairs((instances :: Folder):GetChildren()) do
			PolyRenderer.Add(child)
		end
	else
		for _, child in ipairs(instances :: {Instance}) do
			PolyRenderer.Add(child)
		end
	end
end


function PolyRenderer.SetFPS(FPS: number)
	FRAME_RATE = math.max(FPS, 1)
end

function PolyRenderer.GetAllInstances(): {RenderedInstance}
	return Instances
end


-- Main Renderer Loop
RunService.RenderStepped:Connect(function(dt)
	accumulated += dt
	
	if not PolyRenderer.SyncCameraWithFPS then
		UpdateCamera()
	end
	
	if accumulated >= (1 / FRAME_RATE) then
		accumulated = 0

		UpdateCamera()

		for original, clone in pairs(ObjectMap) do
			if not original or not clone then continue end
			if original:IsA("BasePart") then
				clone.CFrame = original.CFrame
				clone.Size = original.Size
			end
		end
	end
end)

Lighting:GetPropertyChangedSignal("Ambient"):Connect(UpdateViewportLighting)
Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(UpdateViewportLighting)

return PolyRenderer