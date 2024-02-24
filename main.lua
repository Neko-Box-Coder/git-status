VERSION = '0.1.2'

local micro = import('micro')
local shell = import('micro/shell')
local config = import('micro/config')
local strings = import('strings')

function branch()
  local branch, err = shell.ExecCommand('git', 'rev-parse', '--abbrev-ref', 'HEAD')
  if err ~= nil then
    return config.GetGlobalOption('gitStatus.iconNoGit')
  end

  return ('%s %s'):format(config.GetGlobalOption('gitStatus.iconBranch'), branch:gsub('%s+', ''))
end

function conflit()
  local res, err = shell.ExecCommand('git', 'diff', '--name-only', '--diff-filter=U')
  if err ~= nil or res == nil then
    return ''
  end

  res = strings.Split(strings.TrimSpace(res), '\n')
  if #res ~= 0 and res[1] ~= '' then
    return (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconConflit'), #res)
  end
  return ''
end

function behind()
  local res, err = shell.ExecCommand('git', 'rev-list', '--left-right', '--count', '@{upstream}...HEAD')
  if err ~= nil then
    return ''
  end
  count = strings.Split(strings.TrimSpace(res), '')[1]
  if count ~= '0' then
    return (' %s%s'):format(config.GetGlobalOption('gitStatus.iconBehind'), count)
  end

  return ''
end

function ahead()
  local res, err = shell.ExecCommand('git', 'rev-list', '--left-right', '--count', '@{upstream}...HEAD')
  if err ~= nil then
    return ''
  end

  count = strings.Split(strings.TrimSpace(res), '')[3]
  if count ~= '0' then
    return (' %s%s'):format(config.GetGlobalOption('gitStatus.iconAhead'), count)
  end

  return ''
end

function stash()
  local res, err = shell.ExecCommand('git', 'stash', 'list')
  if err ~= nil then
    return ''
  end

  local _, count = res:gsub('@', '')
  if count ~= nil and count ~= 0 then
    return (' {%s}'):format(count)
  end

  return ''
end

function stage()
  local result, err = shell.ExecCommand('git', 'status', '--porcelain', '--branch')

  if err ~= nil then
    return ''
  end

  if result == nil then
    return ''
  end

  local _, count = string.gsub(result, 'A%s', '')

  if count ~= nil and count ~= 0 then
    return (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconStage'), count)
  end

  return ''
end

function modified()
  local result, err = shell.ExecCommand('git', 'status', '--porcelain', '--branch')
  if err ~= nil or result == nil then
    return ''
  end

  local _, count = string.gsub(result, 'M%s', '')
  if count ~= nil and count ~= 0 then
    return (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconModified'), count)
  end

  return ''
end

function unstage()
  local result, err = shell.ExecCommand('git', 'status', '--porcelain', '--branch')

  if err ~= nil or result == nil then
    return ''
  end

  local _, count = string.gsub(result, '?%s', '')

  if count ~= nil and count ~= 0 then
    return (' %s:%s'):format(config.GetGlobalOption('gitStatus.iconUnstage'), count)
  end

  return ''
end

function symbol(branch, stage, modified, unstage)
  local symbol = ''
  if branch ~= config.GetGlobalOption('gitStatus.iconNoGit') then
    symbol = ' ' .. config.GetGlobalOption('gitStatus.iconBranchOK')
    if stage ~= '' or modified ~= '' or unstage ~= '' then
      symbol = ' ' .. config.GetGlobalOption('gitStatus.iconBranchNoOK')
    end
  end
  return symbol
end

function info(buf)
  local branch = branch()
  local conflit = conflit()
  local behind = behind()
  local ahead = ahead()
  local stash = stash()
  local stage = stage()
  local modified = modified()
  local unstage = unstage()

  return branch
    .. conflit
    .. ahead
    .. behind
    .. stash
    .. stage
    .. modified
    .. unstage
    .. symbol(branch, stage, modified, unstage)
end

function init()
  config.RegisterCommonOption('gitStatus', 'iconBranch', '')
  config.RegisterCommonOption('gitStatus', 'iconNoGit', '*')
  config.RegisterCommonOption('gitStatus', 'iconConflit', '')
  config.RegisterCommonOption('gitStatus', 'iconBehind', '↓')
  config.RegisterCommonOption('gitStatus', 'iconAhead', '↑')
  config.RegisterCommonOption('gitStatus', 'iconStage', 'S')
  config.RegisterCommonOption('gitStatus', 'iconModified', 'U')
  config.RegisterCommonOption('gitStatus', 'iconUnstage', '?')
  config.RegisterCommonOption('gitStatus', 'iconBranchOK', '✓')
  config.RegisterCommonOption('gitStatus', 'iconBranchNoOK', '✗')

  micro.SetStatusInfoFn('gitStatus.info')

  config.AddRuntimeFile('gitStatus', config.RTHelp, 'help/gitStatus.md')
end
