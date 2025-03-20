VERSION = '0.1.5'

local micro = import('micro')
local shell = import('micro/shell')
local config = import('micro/config')
local strings = import('strings')
local runtime = import("runtime")

local lastGitStatusRunTime = nil
local lastGitStatusStr = ""
local minGitStatusTick = 10
local currentBufCount = 1
local lastGitStatusTick = -minGitStatusTick
local gitStatusTick = 0

local currentGitStatus = {
    populatedCounter = 0,
    
    branch = "",
    isBranchDone = false,
    
    conflict = "",
    isConflictDone = false,
    
    behindAhead = "",
    isBehindAheadDone = false,
    
    stash = "",
    isStashDone = false,
    
    stagedModifiedUntracked = "",
    isStagedModifiedUntrackedDone = false
}

function getOS()
  if runtime.GOOS == "windows" then
    return "Windows"
  else
    return "Unix"
  end
end

function runCrossPlatformBackgroundCommand(cmd, exitCallback)
  local cmdSplits = {}
  local currentOS = getOS()
  if currentOS == "Unix" then
    -- table.insert(cmdSplits, 'sh')
    table.insert(cmdSplits, '-c')
    table.insert(cmdSplits, cmd)
    shell.JobSpawn("sh", cmdSplits, nil, nil, exitCallback)
  else
    -- table.insert(cmdSplits, 'cmd')
    -- table.insert(cmdSplits, '/s')
    table.insert(cmdSplits, '/v:on')
    table.insert(cmdSplits, '/c')
    table.insert(cmdSplits, cmd)
    shell.JobSpawn("cmd", cmdSplits, nil, nil, exitCallback)
    -- shell.JobSpawn("git rev-parse --abbrev-ref HEAD", nil, nil, branchDone)
  end
end

function branchDone(output)
  micro.Log("output:", output)
  -- if err == nil then
    currentGitStatus.branch = ('%s %s'):format( config.GetGlobalOption('gitStatus.iconBranch'), 
                                                output:gsub('%s+', ''))
    currentGitStatus.isBranchDone = true
  -- else
    -- currentGitStatus.branch = "error: " .. err:Error()
  -- end
end

function startBranch()
  runCrossPlatformBackgroundCommand("git rev-parse --abbrev-ref HEAD", branchDone)
end

function conflictDone(output)
  local res = strings.Split(strings.TrimSpace(output), '\n')
  
  if #res ~= 0 and res[1] ~= '' then
    if  config.GetGlobalOption('gitStatus.iconConflict') ~= 
        config.GetGlobalOption('gitStatus.gitStatus.iconConflit') then
      if config.GetGlobalOption('gitStatus.iconConflict') ~= '' then
        currentGitStatus.conflict = 
          (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconConflict'), #res)
      else
        currentGitStatus.conflict = 
          (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconConflit'), #res)
      end
    else
      currentGitStatus.conflict = 
        (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconConflict'), #res)
    end
  else
    currentGitStatus.conflict = ''
  end
  
  currentGitStatus.isConflictDone = true
end

function startConflict()
  runCrossPlatformBackgroundCommand('git diff --name-only --diff-filter=U', conflictDone)
end

function behindOrAheadDone(output)
  -- micro.Log("output:", output)
  local res = strings.Split(strings.TrimSpace(output), '')
  
  if res ~= nil and #res >= 3 and #res <= 5 then
    behindCount = strings.Split(strings.TrimSpace(output), '')[1]
    aheadCount = strings.Split(strings.TrimSpace(output), '')[3]
    
    if behindCount ~= nil and behindCount ~= '0' then
      currentGitStatus.behindAhead = 
        (' %s%s'):format(config.GetGlobalOption('gitStatus.iconBehind'), behindCount)
    elseif aheadCount ~= nil and aheadCount ~= '0' then
      currentGitStatus.behindAhead = 
        (' %s%s'):format(config.GetGlobalOption('gitStatus.iconAhead'), aheadCount)
    else
      currentGitStatus.behindAhead = ''
    end
  else
    currentGitStatus.behindAhead = ''
  end
  
  currentGitStatus.isBehindAheadDone = true
end

function startBehindOrAhead()
  runCrossPlatformBackgroundCommand('git rev-list --left-right --count @{upstream}...HEAD', behindOrAheadDone)
end

function stashDone(output)
  local _, count = output:gsub('@', '')
  if count ~= nil and count ~= 0 then
    currentGitStatus.stash = (' {%s}'):format(count)
  else
    currentGitStatus.stash = ''
  end
  currentGitStatus.isStashDone = true
end

function startStash()
  runCrossPlatformBackgroundCommand('git stash list', stashDone)
end

function getStagedModifiedUntrackCount(output)
  local stagedCount = 0
  local modifiedCount = 0
  local untrackCount = 0
  for line in output:gmatch("[^\r\n]+") do
    local _, curAddCount = string.gsub(line, '^A  .*$', '')
    if curAddCount == nil then curAddCount = 0 end
    local _, curStagedCount = string.gsub(line, '^M  .*$', '')
    if curStagedCount == nil then curStagedCount = 0 end
    local _, curModCount = string.gsub(line, '^.M .*$', '')
    if curModCount == nil then curModCount = 0 end
    local _, curUntrackCount = string.gsub(output, '^?? .*$', '')
    if curUntrackCount == nil then curUntrackCount = 0 end
    
    stagedCount = stagedCount + curAddCount + curStagedCount
    modifiedCount = modifiedCount + curModCount
    untrackCount = untrackCount + curUntrackCount
  end
  
  return stagedCount, modifiedCount, untrackCount
end

function stagedModifiedUntrackedDone(output)
  local staged, mod, untracked = getStagedModifiedUntrackCount(output)
  local returnStr = ''
  
  if staged ~= 0 then
    returnStr = returnStr .. (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconStage'), staged)
  end
  
  if mod ~= 0 then
    returnStr = returnStr .. (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconModified'), mod)
  end

  if untracked ~= nil and untracked ~= 0 then
    if config.GetGlobalOption('gitStatus.iconUnstage') ~= config.GetGlobalOption('gitStatus.iconUntracked') then
      if config.GetGlobalOption('gitStatus.iconUnstage') == 'U' then
        returnStr = returnStr .. (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconUntracked'), untracked)
      else
        returnStr = returnStr .. (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconUntracked'), untracked)
      end
    else
      returnStr = returnStr .. (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconUnstage'), untracked)
    end
  end
  
  currentGitStatus.stagedModifiedUntracked = returnStr
  currentGitStatus.isStagedModifiedUntrackedDone = true
end

function startStagedModifiedUntracked()
  runCrossPlatformBackgroundCommand('git status --porcelain --branch', stagedModifiedUntrackedDone)
end

function symbol(branch, stageModifiedUntracked)
  local symbol = ''
  if branch ~= config.GetGlobalOption('gitStatus.iconNoGit') then
    if stageModifiedUntracked ~= '' then
      symbol = ' ' .. config.GetGlobalOption('gitStatus.iconBranchNoOK')
    else
      symbol = ' ' .. config.GetGlobalOption('gitStatus.iconBranchOK')
    end
  end
  return symbol
end

function gitStatusToStr()
  return  currentGitStatus.branch .. 
          currentGitStatus.conflict .. 
          currentGitStatus.behindAhead .. 
          currentGitStatus.stash .. 
          currentGitStatus.stagedModifiedUntracked ..
          symbol( currentGitStatus.branch, 
                  currentGitStatus.stagedModifiedUntracked)
end

function updateCurrentBufferCount()
  currentBufCount = 0
  local bp = micro.CurPane()
  if bp == nil then
    currentBufCount = 1
    return
  end
  
  currentBufCount = #bp:Tab().Panes
  
  if currentBufCount <= 0 then
    currentBufCount = 1
  end
end

function halftick()
  -- micro.InfoBar():Message("halftick(): ", gitStatusTick)
  gitStatusTick = gitStatusTick + 1
  lastGitStatusTick = gitStatusTick
  updateCurrentBufferCount()
end

function fulltick(doLog)
  -- if doLog then
  --   micro.InfoBar():Message("fulltick(): ", gitStatusTick)
  -- end
  gitStatusTick = gitStatusTick + 1
  lastGitStatusTick = gitStatusTick
  lastGitStatusRunTime = os.time()
  updateCurrentBufferCount()
end

function updateLastGitStatusStrIfPossible()
  if  currentGitStatus.isBranchDone and
      currentGitStatus.isConflictDone and
      currentGitStatus.isBehindAheadDone  and
      currentGitStatus.isStashDone and
      currentGitStatus.isStagedModifiedUntrackedDone then
  
    currentGitStatus.isBranchDone = false
    currentGitStatus.isConflictDone = false
    currentGitStatus.isBehindAheadDone  = false
    currentGitStatus.isStashDone = false
    currentGitStatus.isStagedModifiedUntrackedDone = false
    currentGitStatus.populatedCounter = 0
    
    lastGitStatusStr = gitStatusToStr()
    
    -- micro.InfoBar():Message("Called")
  else
    -- micro.InfoBar():Message("Called 2")
  end
end

function info(buf)
  if gitStatusTick - lastGitStatusTick < minGitStatusTick * currentBufCount then
    gitStatusTick = gitStatusTick + 1
    return lastGitStatusStr
  end
  
  if lastGitStatusRunTime ~= nil then 
    local lastRunTimeDiff = os.difftime(os.time(), lastGitStatusRunTime)
    -- micro.InfoBar():Message("local lastRunTimeDiff = os.difftime(os.time(), lastGitStatusRunTime)")
    if lastRunTimeDiff < config.GetGlobalOption('gitStatus.commandInterval') then
      halftick()
      return lastGitStatusStr
    end
  end
  
  if gitStatusTick == 0 then
    -- currentGitStatus.branch = branch()
    startBranch()
    startConflict()
    startBehindOrAhead()
    startStash()
    startStagedModifiedUntracked()
    
    -- lastGitStatusStr = gitStatusToStr()
    -- micro.InfoBar():Message("gitStatusFirstRun")
    currentGitStatus.populatedCounter = 3
    fulltick(true)
    return lastGitStatusStr
  end
  
  if currentGitStatus.populatedCounter == 0 then
    startBranch()
    startBehindOrAhead()
    startStash()
    fulltick(true)
  elseif currentGitStatus.populatedCounter == 1 then
    startConflict()
  elseif currentGitStatus.populatedCounter == 2 then
    startStagedModifiedUntracked()
    fulltick(true)
  end
  
  if currentGitStatus.populatedCounter < 3 then
    currentGitStatus.populatedCounter = currentGitStatus.populatedCounter + 1
  else
    updateLastGitStatusStrIfPossible()
  end
  
  return lastGitStatusStr
end

function init()
  config.RegisterCommonOption('gitStatus', 'iconBranch', '')
  config.RegisterCommonOption('gitStatus', 'iconNoGit', '?')
  config.RegisterCommonOption('gitStatus', 'iconConflit', '')
  config.RegisterCommonOption('gitStatus', 'iconConflict', '')
  config.RegisterCommonOption('gitStatus', 'iconBehind', '↓')
  config.RegisterCommonOption('gitStatus', 'iconAhead', '↑')
  config.RegisterCommonOption('gitStatus', 'iconStage', 'S')
  config.RegisterCommonOption('gitStatus', 'iconModified', 'M')
  config.RegisterCommonOption('gitStatus', 'iconUnstage', 'U')
  config.RegisterCommonOption('gitStatus', 'iconUntracked', 'U')
  config.RegisterCommonOption('gitStatus', 'iconBranchOK', '✓')
  config.RegisterCommonOption('gitStatus', 'iconBranchNoOK', '✗')
  
  config.RegisterCommonOption('gitStatus', 'commandInterval', 3)

  micro.SetStatusInfoFn('gitStatus.info')

  config.AddRuntimeFile('gitStatus', config.RTHelp, 'help/gitStatus.md')
end
