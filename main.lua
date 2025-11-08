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
local FollowTab = Window:CreateTab("👤 Follow", nil)
local DetectionTab = Window:CreateTab("🔍 Detection", nil)
local SettingsTab = Window:CreateTab("⚙️ Settings", nil)

-- Variables
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local autoTpEnabled = false
local currentStage = 1
local tpDelay = 0.5
local stages = {}
local detectedObjects = {}

-- Follow variables
local followEnabled = false
local targetPlayerName = ""
local targetPlayer = nil
local followDistance = 3
local followConnection = nil

-- より詳細なステージ検出関数
local function findStages()
    stages = {}
    detectedObjects = {}
    local workspace = game:GetService("Workspace")
    
    print("=== ステージ検索開始 ===")
    
    -- パターン1: 数字を含む名前のオブジェクトを検索
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name
            local lowerName = name:lower()
            
            -- 数字を抽出
            local num = tonumber(name:match("%d+"))
            
            if num and num >= 1 and num <= 500 then
                -- 一般的なステージ名パターン
                if lowerName:match("stage") or lowerName:match("checkpoint") or 
                   lowerName:match("cp") or lowerName:match("level") or
                   lowerName:match("check") or name:match("^%d+$") then
                    
                    if not stages[num] then
                        stages[num] = obj
                        table.insert(detectedObjects, {number = num, name = name, object = obj})
                        print("検出: " .. name .. " (ステージ " .. num .. ")")
                    end
                end
            end
        end
    end
    
    -- パターン2: Folder内のステージを検索
    for _, folder in pairs(workspace:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            local folderName = folder.Name:lower()
            if folderName:match("stage") or folderName:match("checkpoint") or 
               folderName:match("obby") or folderName:match("athletic") then
                
                for _, child in pairs(folder:GetChildren()) do
                    local num = tonumber(child.Name:match("%d+"))
                    if num and not stages[num] then
                        stages[num] = child
                        table.insert(detectedObjects, {number = num, name = child.Name, object = child})
                        print("フォルダー内で検出: " .. child.Name .. " (ステージ " .. num .. ")")
                    end
                end
            end
        end
    end
    
    -- パターン3: SpawnLocationを検索
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            local num = tonumber(obj.Name:match("%d+"))
            if num and not stages[num] then
                stages[num] = obj
                table.insert(detectedObjects, {number = num, name = obj.Name, object = obj})
                print("SpawnLocation検出: " .. obj.Name .. " (ステージ " .. num .. ")")
            end
        end
    end
    
    -- 検出されたステージをソート
    table.sort(detectedObjects, function(a, b) return a.number < b.number end)
    
    print("=== 検索完了: " .. #detectedObjects .. " 個のステージ ===")
    
    return #detectedObjects
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
        -- モデルの中心または最初のPartを取得
        local primaryPart = targetStage.PrimaryPart or targetStage:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            targetPos = primaryPart.Position
        else
            targetPos = targetStage:GetPivot().Position
        end
    elseif targetStage:IsA("BasePart") then
        targetPos = targetStage.Position
    end
    
    if targetPos then
        -- キャラクターを更新
        character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            humanoidRootPart = character.HumanoidRootPart
            -- 少し上にテレポートして落下
            humanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 10, 0))
            print("テレポート成功: ステージ " .. stageNumber)
            return true
        end
    end
    
    return false
end

-- プレイヤーリストを取得
local function getPlayerList()
    local players = game:GetService("Players"):GetPlayers()
    local names = {}
    for _, plr in pairs(players) do
        if plr ~= player then
            table.insert(names, plr.Name)
        end
    end
    return names
end

-- 尾行開始関数
local function startFollowing(targetName)
    -- 既存の接続を切断
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end
    
    -- プレイヤーを検索
    targetPlayer = game:GetService("Players"):FindFirstChild(targetName)
    
    if not targetPlayer then
        Rayfield:Notify({
           Title = "エラー",
           Content = "プレイヤー " .. targetName .. " が見つかりません",
           Duration = 3,
           Image = 4483362458,
        })
        followEnabled = false
        return false
    end
    
    Rayfield:Notify({
       Title = "尾行開始",
       Content = targetName .. " を尾行しています",
       Duration = 3,
       Image = 4483362458,
    })
    
    -- 尾行ループ
    followConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not followEnabled then
            if followConnection then
                followConnection:Disconnect()
                followConnection = nil
            end
            return
        end
        
        -- ターゲットプレイヤーのキャラクターを取得
        if targetPlayer and targetPlayer.Character then
            local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            character = player.Character
            
            if targetHRP and character and character:FindFirstChild("HumanoidRootPart") then
                humanoidRootPart = character.HumanoidRootPart
                local targetPos = targetHRP.Position
                local offset = Vector3.new(0, 0, followDistance)
                
                -- ターゲットの後ろに位置する
                local targetLook = targetHRP.CFrame.LookVector
                humanoidRootPart.CFrame = CFrame.new(targetPos - targetLook * followDistance, targetPos)
            end
        else
            -- ターゲットが存在しない場合
            followEnabled = false
            Rayfield:Notify({
               Title = "尾行終了",
               Content = targetName .. " が存在しません",
               Duration = 3,
               Image = 4483362458,
            })
        end
    end)
    
    return true
end

-- 尾行停止関数
local function stopFollowing()
    followEnabled = false
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end
    Rayfield:Notify({
       Title = "尾行停止",
       Content = "尾行を停止しました",
       Duration = 2,
       Image = 4483362458,
    })
end

-- Main Tab UI
local Section = MainTab:CreateSection("ステージテレポート")

local StageInput = MainTab:CreateInput({
   Name = "ステージ番号",
   PlaceholderText = "番号を入力",
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

local QuickSection = MainTab:CreateSection("クイックテレポート")

local NextButton = MainTab:CreateButton({
   Name = "次のステージへ",
   Callback = function()
      currentStage = currentStage + 1
      if teleportToStage(currentStage) then
         Rayfield:Notify({
            Title = "テレポート",
            Content = "ステージ " .. currentStage,
            Duration = 1.5,
            Image = 4483362458,
         })
      else
         currentStage = currentStage - 1
      end
   end,
})

local PrevButton = MainTab:CreateButton({
   Name = "前のステージへ",
   Callback = function()
      if currentStage > 1 then
         currentStage = currentStage - 1
         if teleportToStage(currentStage) then
            Rayfield:Notify({
               Title = "テレポート",
               Content = "ステージ " .. currentStage,
               Duration = 1.5,
               Image = 4483362458,
            })
         else
            currentStage = currentStage + 1
         end
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
            local maxStage = 0
            for num, _ in pairs(stages) do
               if num > maxStage then maxStage = num end
            end
            
            while autoTpEnabled and stage <= maxStage do
               if stages[stage] then
                  if teleportToStage(stage) then
                     currentStage = stage
                     wait(tpDelay)
                  end
               end
               stage = stage + 1
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

-- Follow Tab UI
local FollowSection = FollowTab:CreateSection("プレイヤー尾行")

local PlayerInput = FollowTab:CreateInput({
   Name = "プレイヤー名",
   PlaceholderText = "尾行するプレイヤー名を入力",
   RemoveTextAfterFocusLost = false,
   Callback = function(text)
      targetPlayerName = text
   end,
})

local FollowToggle = FollowTab:CreateToggle({
   Name = "尾行を有効化",
   CurrentValue = false,
   Flag = "FollowToggle",
   Callback = function(value)
      followEnabled = value
      if value then
         if targetPlayerName ~= "" then
            startFollowing(targetPlayerName)
         else
            Rayfield:Notify({
               Title = "エラー",
               Content = "プレイヤー名を入力してください",
               Duration = 3,
               Image = 4483362458,
            })
            followEnabled = false
         end
      else
         stopFollowing()
      end
   end,
})

local FollowSettingsSection = FollowTab:CreateSection("尾行設定")

local DistanceSlider = FollowTab:CreateSlider({
   Name = "尾行距離",
   Range = {1, 20},
   Increment = 0.5,
   Suffix = " studs",
   CurrentValue = 3,
   Flag = "FollowDistance",
   Callback = function(value)
      followDistance = value
   end,
})

local PlayerListSection = FollowTab:CreateSection("サーバー内のプレイヤー")

local PlayerListLabel = FollowTab:CreateLabel("プレイヤーリストを更新してください")

local RefreshPlayersButton = FollowTab:CreateButton({
   Name = "プレイヤーリストを更新",
   Callback = function()
      local players = getPlayerList()
      if #players > 0 then
         local listText = "サーバー内のプレイヤー:\n\n"
         for i, name in ipairs(players) do
            listText = listText .. "• " .. name .. "\n"
            if i >= 15 then
               listText = listText .. "...他 " .. (#players - 15) .. " 人"
               break
            end
         end
         PlayerListLabel:Set(listText)
         
         Rayfield:Notify({
            Title = "更新完了",
            Content = #players .. " 人のプレイヤーが見つかりました",
            Duration = 2,
            Image = 4483362458,
         })
      else
         PlayerListLabel:Set("他のプレイヤーが見つかりません")
      end
   end,
})

local QuickFollowSection = FollowTab:CreateSection("クイック選択")

-- 動的にプレイヤーボタンを生成
local function createPlayerButtons()
   local players = getPlayerList()
   for i = 1, math.min(5, #players) do
      FollowTab:CreateButton({
         Name = "📍 " .. players[i],
         Callback = function()
            targetPlayerName = players[i]
            PlayerInput:Set(players[i])
            Rayfield:Notify({
               Title = "選択",
               Content = players[i] .. " を選択しました",
               Duration = 2,
               Image = 4483362458,
            })
         end,
      })
   end
end

-- 初期ボタン生成
task.spawn(createPlayerButtons)

-- プレイヤー退出時の処理
game:GetService("Players").PlayerRemoving:Connect(function(removedPlayer)
   if targetPlayer == removedPlayer and followEnabled then
      stopFollowing()
   end
end)

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

-- Detection Tab
local DetectionSection = DetectionTab:CreateSection("ステージ検出")

local DetectButton = DetectionTab:CreateButton({
   Name = "🔍 ステージを検出",
   Callback = function()
      Rayfield:Notify({
         Title = "検索中...",
         Content = "ワークスペースをスキャンしています",
         Duration = 2,
         Image = 4483362458,
      })
      
      local count = findStages()
      
      Rayfield:Notify({
         Title = "検索完了",
         Content = count .. " 個のステージが見つかりました",
         Duration = 4,
         Image = 4483362458,
      })
   end,
})

local InfoSection = DetectionTab:CreateSection("検出されたステージ")

local StageListLabel = DetectionTab:CreateLabel("「ステージを検出」ボタンを押してください")

-- リストを更新する関数
local function updateStageList()
   if #detectedObjects > 0 then
      local listText = "検出: " .. #detectedObjects .. " 個\n\n"
      for i = 1, math.min(10, #detectedObjects) do
         local obj = detectedObjects[i]
         listText = listText .. "Stage " .. obj.number .. ": " .. obj.name .. "\n"
      end
      if #detectedObjects > 10 then
         listText = listText .. "\n...他 " .. (#detectedObjects - 10) .. " 個"
      end
      StageListLabel:Set(listText)
   end
end

local ShowListButton = DetectionTab:CreateButton({
   Name = "検出リストを表示",
   Callback = function()
      updateStageList()
   end,
})

local DebugSection = DetectionTab:CreateSection("デバッグ情報")

local PrintButton = DetectionTab:CreateButton({
   Name = "コンソールに詳細を出力",
   Callback = function()
      print("\n=== 検出されたステージ一覧 ===")
      for i, obj in ipairs(detectedObjects) do
         print(i .. ". ステージ " .. obj.number .. ": " .. obj.name .. " | Path: " .. obj.object:GetFullName())
      end
      print("=== 合計: " .. #detectedObjects .. " 個 ===\n")
      
      Rayfield:Notify({
         Title = "デバッグ",
         Content = "コンソール(F9)を確認してください",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

-- 初期化
local initialCount = findStages()
Rayfield:Notify({
   Title = "Athletic Stage Auto TP",
   Content = initialCount .. " 個のステージが検出されました",
   Duration = 5,
   Image = 4483362458,
})

if initialCount == 0 then
   Rayfield:Notify({
      Title = "警告",
      Content = "Detectionタブでステージを再検索してください",
      Duration = 5,
      Image = 4483362458,
   })
end
