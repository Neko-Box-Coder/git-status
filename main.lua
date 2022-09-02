VERSION = "0.0.1"

local micro = import("micro")
local shell = import("micro/shell")
local strings = import("strings")


function branch()
    local branch, err = shell.ExecCommand("git", "rev-parse", "--abbrev-ref", "HEAD")
    if err ~= nil then
        return "*"
    end
    return (" %s"):format(branch:gsub("%s+", ""))
end

function conflit()
    local res, err = shell.ExecCommand("git", "diff", "--name-only", "--diff-filter=U")
    if err ~= nil or res == nil then
        return ""
    end

    res = strings.Split(strings.TrimSpace(res), "\n")
    if #res ~= 0 and res[1] ~= "" then
        return ("  :%s"):format(#res)
    end
    return ""
end

function behind()
    local res, err = shell.ExecCommand("git", "rev-list", "--left-right", "--count", "@{upstream}...HEAD")
    if err ~= nil then
        return ""
    end
    count = strings.Split(strings.TrimSpace(res), "")[1]
    if count ~= "0" then
        return (" ↓%s"):format(count)
    end

    return ""
end

function ahead()
    local res, err = shell.ExecCommand("git", "rev-list", "--left-right", "--count", "@{upstream}...HEAD")
    if err ~= nil then
        return ""
    end

    count = strings.Split(strings.TrimSpace(res), "")[3]
    if count ~= "0" then
        return (" ↑%s"):format(count)
    end

    return ""
end

function stash()
    local res, err = shell.ExecCommand("git", "stash", "list")
    if err ~= nil then
        return ""
    end

    local _, count = res:gsub("@", "")
    if count ~= nil and count ~= 0 then
        return (" {%s}"):format(count)
    end

    return ""
end

function stage()
    local result, err = shell.ExecCommand("git", "status", "--porcelain", "--branch")

    if err ~= nil then
        return ""
    end

    if result == nil then
        return ""
    end

    local _, count = string.gsub(result, "A", "*")

    if count ~= nil and count ~= 0 then
        return (" S:%s"):format(tostring(count))
    end

    return ""
end

function modified()
    local result, err = shell.ExecCommand("git", "status", "--porcelain", "--branch")
    if err ~= nil or result == nil then
        return ""
    end

    local _, count = string.gsub(result, "M", "*")
    if count ~= nil and count ~= 0 then
        return (" U:%s"):format(tostring(count))
    end

    return ""
end

function unstage()
    local result, err = shell.ExecCommand("git", "status", "--porcelain", "--branch")

    if err ~= nil or result == nil then
        return ""
    end

    local _, count = string.gsub(result, "?\\?", "*")
    count = math.floor(count / 2)

    if count ~= nil and count ~= 0 then
        return (" ?:%s"):format(tostring(count))
    end

    return ""
end

function symbol(branch, stage, modified, unstage)
    local symbol = ""
    if branch ~= "*" then
        symbol = " ✓"
        if stage ~= "" or modified ~= "" or unstage ~= "" then
            symbol = " ✗"
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

    return branch..conflit..ahead..behind..stash..stage..modified..unstage..symbol(branch, stage, modified, unstage)
end

function init()
    micro.SetStatusInfoFn("gitStatus.info")
end
