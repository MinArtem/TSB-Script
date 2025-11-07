-- =================================================================
-- | AWS v33 - Ping Optimizer Module |
-- | To be hosted on GitHub and loaded remotely. |
-- =================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Module table to be returned
local Optimizer = {}

-- ================== CONFIGURATION ==================
local OPTIMIZE_DISTANCE = 150 -- (in studs) Players further than this will be optimized.
local PARTS_PER_YIELD = 20 -- How many parts to process before waiting, to prevent lag spikes.

-- ================== LOCAL VARIABLES ==================
local originalStates = {} -- Stores the original properties of parts we modify.
local optimizationLoopConnection = nil -- Stores the RunService connection to be able to disconnect it.

-- This function applies or reverts optimization for a specific object (part, particle emitter, sound).
local function processDescendant(descendant, shouldOptimize)
    if shouldOptimize then
        -- If the object is not already in our records, save its current state before changing it.
        if not originalStates[descendant] then
            originalStates[descendant] = {}
            if descendant:IsA("BasePart") then
                originalStates[descendant].CanCollide = descendant.CanCollide
                descendant.CanCollide = false
            elseif descendant:IsA("ParticleEmitter") then
                originalStates[descendant].Enabled = descendant.Enabled
                descendant.Enabled = false
            elseif descendant:IsA("Sound") then
                originalStates[descendant].Playing = descendant.IsPlaying
                if descendant.IsPlaying then
                    descendant:Stop()
                end
            end
        end
    else
        -- If the object is in our records, restore its saved state.
        if originalStates[descendant] then
            pcall(function()
                for property, value in pairs(originalStates[descendant]) do
                    descendant[property] = value
                end
            end)
            -- Remove it from records since it's now restored.
            originalStates[descendant] = nil
        end
    end
end

-- The main loop that checks player distances and applies optimizations.
local function onHeartbeat()
    if not localPlayer or not localPlayer.Character then return end
    local playerRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not playerRoot then return end

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= localPlayer and otherPlayer.Character then
            local targetRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local distance = (playerRoot.Position - targetRoot.Position).Magnitude
                local shouldOptimize = distance > OPTIMIZE_DISTANCE
                
                local partsProcessed = 0
                for _, descendant in ipairs(otherPlayer.Character:GetDescendants()) do
                    -- We only care about these types of objects for optimization.
                    if descendant:IsA("BasePart") or descendant:IsA("ParticleEmitter") or descendant:IsA("Sound") then
                        processDescendant(descendant, shouldOptimize)
                        partsProcessed = partsProcessed + 1
                        -- Wait for a frame if we've processed a lot of parts, to spread the load.
                        if partsProcessed >= PARTS_PER_YIELD then
                            RunService.Heartbeat:Wait()
                            partsProcessed = 0
                        end
                    end
                end
            end
        end
    end
end

-- Function to start the optimizer
function Optimizer:Start()
    if optimizationLoopConnection then return end -- Already running
    print("Ping Optimizer: Started.")
    -- Connect the main loop to the Heartbeat event, which runs every frame.
    optimizationLoopConnection = RunService.Heartbeat:Connect(onHeartbeat)
end

-- Function to stop the optimizer and clean up
function Optimizer:Stop()
    if not optimizationLoopConnection then return end -- Already stopped
    
    -- Disconnect the loop so it stops running.
    optimizationLoopConnection:Disconnect()
    optimizationLoopConnection = nil
    
    -- Restore all changes that were made.
    print("Ping Optimizer: Reverting changes...")
    for descendant, savedState in pairs(originalStates) do
        if descendant and descendant.Parent then -- Make sure the object still exists
             pcall(function()
                for property, value in pairs(savedState) do
                    descendant[property] = value
                end
            end)
        end
    end
    -- Clear the state table.
    originalStates = {}
    print("Ping Optimizer: Stopped and cleaned up.")
end

return Optimizer