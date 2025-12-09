local Genmodule = {}

local RS = game:GetService("ReplicatedStorage")
local Tiles = RS.Tiles:GetChildren()
local Promise = require(RS.Packages.WaitForChild("Promise"))
local StartRoom: Model = RS.StartingRoom

local PossibleHallways = {}
local TilesWeight = {}
local totalWeight = 0

for _, Hallway in Tiles do
	if Hallway:IsA("Model") and not Hallway:GetAttribute("Room") then
		table.insert(PossibleHallways, Hallway)
	end
end

for _, Tile in Tiles do
	if Tile:IsA("Model") then
		totalWeight += Tile:GetAttribute("Weight")
		TilesWeight[Tile] = Tile:GetAttribute("Weight")
	end
end

function Genmodule.Genrate(Pos: Vector3, RoomNum: number, Seed: number)
	local Rng = Random.new(Seed)
	local MaxAttempts = 10

	local function TryGenerate(attempt)
		if attempt > MaxAttempts then
			warn("Failed to generate dungeon after max attempts")
			return
		end

		workspace.Dungeon.Rooms:ClearAllChildren()
		workspace.Dungeon.Hallways:ClearAllChildren()

		local CuerrentRoomNum = 0

		local StartRoomClone = StartRoom:Clone()
		StartRoomClone.PrimaryPart.Anchored = true
		StartRoomClone:PivotTo(CFrame.new(Pos))
		StartRoomClone.Parent = workspace.Dungeon.Rooms

		-- Recursive branch function returning a Promise
		local function Branchout(Tile: Model)
			return Promise.new(function(resolve)
				assert(Tile.PrimaryPart, "No prim")
				local childPromises = {}

				for _, Waypoint in Tile:GetChildren() do
					if Waypoint:IsA("BasePart") and Waypoint.Name == "Waypoints" then
						local Look = Vector3.new(Waypoint.CFrame.LookVector.X, 0, Waypoint.CFrame.LookVector.Z).Unit
						local FixedWaypointPos =
							Vector3.new(Waypoint.Position.X, Tile.PrimaryPart.Position.Y, Waypoint.Position.Z)
						local NewCf = CFrame.new(FixedWaypointPos + Look * 4.265)
							* CFrame.Angles(0, math.atan2(Look.X, Look.Z), 0)

						local Parts = workspace:GetPartBoundsInBox(NewCf, Vector3.new(7.8, 4, 7.8))
						if #Parts > 0 or CuerrentRoomNum >= RoomNum then
							Waypoint.Transparency = 0
							continue
						end

						local Clone
						if Tile:GetAttribute("Room") then
							Clone = PossibleHallways[Rng:NextInteger(1, #PossibleHallways)]:Clone()
							Clone.Parent = workspace.Dungeon.Hallways
						else
							local randomNumber = Rng:NextNumber() * totalWeight
							local accumulatedWeight = 0
							local ChoosenTile
							for Tile, Weight in TilesWeight do
								accumulatedWeight = accumulatedWeight + Weight
								if randomNumber <= accumulatedWeight then
									ChoosenTile = Tile
									break
								end
							end

							Clone = ChoosenTile:Clone()
							Clone.Parent = workspace.Dungeon.Hallways
							if Clone:GetAttribute("Room") then
								CuerrentRoomNum += 1
								Clone.Parent = workspace.Dungeon.Rooms
							end
						end
						Clone:SetPrimaryPartCFrame(NewCf)
						Waypoint:Destroy()
						table.insert(
							childPromises,
							Promise.delay(0.01):andThen(function()
								return Branchout(Clone)
							end)
						)
					end
				end

				-- Wait until all children finish
				Promise.all(childPromises):andThen(resolve)
			end)
		end

		-- Start generation from the StartRoomClone
		Branchout(StartRoomClone):andThen(function()
			if CuerrentRoomNum < RoomNum then
				print("Retrying generation attempt:", attempt)
				TryGenerate(attempt + 1)
			end
		end)
	end

	TryGenerate(1)
end

return Genmodule
