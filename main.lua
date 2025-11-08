local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Athletic Stage Auto TP",
   LoadingTitle = "Athletic Helper",
   LoadingSubtitle = "by Script",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "AthleticTP"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false,
})

local MainTab = Window:CreateTab("🏃 Main", nil)
local SettingsTab = Window:CreateTab("⚙️ Settings", nil)

-- Variables
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local autoTpEnabled = false
local currentStage = 1
local tpDelay = 0.5
local stages = {}

-- ステージを検出する関数
local function findStages()
    stages = {}
    local workspace = game:GetService("Workspace")
    
    -- 一般的なステージの名前パターンを検索
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower()
            -- "stage", "checkpoint", "cp" などのパターンを検索
            if name:match("stage") or name:match("checkpoint") or name:match("cp") then
                -- 数字を抽出
                local num = tonumber(name:match("%d+"))
                if num and not stages[num] then
                    stages[num] = obj
                end
            end
        end
    end
    
    -- ステージが見つからない場合の代替検索
    if #stages == 0 then
        for i = 1, 100 do
            local stage = workspace:FindFirstChild("Stage" .. i) 
                or workspace:FindFirstChild("stage" .. i)
                or workspace:FindFirstChild("Checkpoint" .. i)
                or workspace:FindFirstChild("CP" .. i)
            if stage then
                stages[i] = stage
            end
        end
    end
    
    return #stages
end

-- テレポート関数
local function teleportToStage(stageNumber)
    if not stages[stageNumber] then
        Rayfield:Notify({
           Title = "エラー",
           Content = "ステージ " .. stageNumber .. " が見つかりません",
           Duration = 3,
           Image = 4483362458,
        })
        return false
    end
    
    local targetStage = stages[stageNumber]
    local targetPos
    
    -- ステージの位置を取得
    if targetStage:IsA("Model") then
        targetPos = targetStage:GetPivot().Position
    elseif targetStage:IsA("BasePart") then
        targetPos = targetStage.Position
    end
    
    if targetPos then
        -- キャラクターを更新
        character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            humanoidRootPart = character.HumanoidRootPart
            humanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
            return true
        end
    end
    
    return false
end

-- UI要素
local Section = MainTab:CreateSection("ステージテレポート")

local StageInput = MainTab:CreateInput({
   Name = "ステージ番号",
   PlaceholderText = "1-" .. findStages(),
   RemoveTextAfterFocusLost = false,
   Callback = function(text)
      local stageNum = tonumber(text)
      if stageNum then
         currentStage = stageNum
      end
   end,
})

local TpButton = MainTab:CreateButton({
   Name = "選択したステージにTP",
   Callback = function()
      if teleportToStage(currentStage) then
         Rayfield:Notify({
            Title = "テレポート成功",
            Content = "ステージ " .. currentStage .. " にテレポートしました",
            Duration = 2,
            Image = 4483362458,
         })
      end
   end,
})

local AutoSection = MainTab:CreateSection("自動テレポート")

local AutoTpToggle = MainTab:CreateToggle({
   Name = "全ステージ自動TP",
   CurrentValue = false,
   Flag = "AutoTp",
   Callback = function(value)
      autoTpEnabled = value
      if value then
         Rayfield:Notify({
            Title = "自動TP開始",
            Content = "ステージ1から順にテレポートします",
            Duration = 3,
            Image = 4483362458,
         })
         
         task.spawn(function()
            local stage = 1
            while autoTpEnabled and stage <= #stages do
               if teleportToStage(stage) then
                  currentStage = stage
                  wait(tpDelay)
                  stage = stage + 1
               else
                  wait(0.5)
               end
            end
            
            if autoTpEnabled then
               Rayfield:Notify({
                  Title = "完了",
                  Content = "全ステージのテレポートが完了しました",
                  Duration = 3,
                  Image = 4483362458,
               })
               autoTpEnabled = false
            end
         end)
      end
   end,
})

-- Settings Tab
local SettingsSection = SettingsTab:CreateSection("設定")

local DelaySlider = SettingsTab:CreateSlider({
   Name = "TP間隔 (秒)",
   Range = {0.1, 5},
   Increment = 0.1,
   Suffix = "秒",
   CurrentValue = 0.5,
   Flag = "TpDelay",
   Callback = function(value)
      tpDelay = value
   end,
})

local RefreshButton = SettingsTab:CreateButton({
   Name = "ステージを再検索",
   Callback = function()
      local count = findStages()
      Rayfield:Notify({
         Title = "検索完了",
         Content = count .. " 個のステージが見つかりました",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

local InfoSection = SettingsTab:CreateSection("情報")

local InfoLabel = SettingsTab:CreateLabel("検出されたステージ数: " .. #stages)

-- 初期化
Rayfield:Notify({
   Title = "Athletic Stage Auto TP",
   Content = #stages .. " 個のステージが検出されました",
   Duration = 5,
   Image = 4483362458,
})
