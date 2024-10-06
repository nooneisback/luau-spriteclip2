local _export = {};

function _export:GetSignal(framerate:number)
    local gname = tostring(framerate);
    local bind:BindableEvent = script:FindFirstChild(gname);
    if (not bind) then
        local _bind = Instance.new("BindableEvent") :: BindableEvent;
        bind = _bind;
        _bind.Name = gname;
        _bind.Parent = script;
    end
    return bind.Event;
end

function _export:Pause()
    script.__bind_Pause:Invoke();
end

function _export:Resume()
    script.__bind_Resume:Invoke();
end

function _export:IsPaused()
    return script:GetAttribute("IsPaused")::boolean;
end

-- run only if first require
if (script:GetAttribute("paracheck")==nil) then
    local currtime = os.clock();

    local GroupBinds:{[string]:BindableEvent} = {};
    local GroupLastTimes:{[string]:number} = {};
    local GroupDeltaTimes:{[string]:number} = {};

    -- Pause and resume
    local ispaused = false;
    script:SetAttribute("IsPaused", false);
    local bindPause = Instance.new("BindableFunction");
        bindPause.Name = "__bind_Pause";
        bindPause.Parent = script;
    bindPause.OnInvoke = function()
        ispaused = true;
        script:SetAttribute("IsPaused", true);
    end
    local bindResume = Instance.new("BindableFunction");
        bindResume.Name = "__bind_Resume";
        bindResume.Parent = script;
    bindResume.OnInvoke = function()
        ispaused = false;
        script:SetAttribute("IsPaused", false);
    end
    
    -- Render group management
    local function LoadGroup(bind:BindableEvent)
        if (not bind:IsA("BindableEvent")) then return; end
        GroupBinds[bind.Name] = bind;
        local delta = 1 / tonumber(bind.Name)::number;
        GroupLastTimes[bind.Name] = os.clock();
        GroupDeltaTimes[bind.Name] = delta;
    end
    for _,v in ipairs(script:GetChildren()) do LoadGroup(v); end
    script.ChildAdded:Connect(LoadGroup);

    game:GetService("RunService").RenderStepped:Connect(function(d)
        currtime += d;
        if (ispaused) then return; end
        for gname, gbind in pairs(GroupBinds) do
            local glast = GroupLastTimes[gname];
            local gdelta = GroupDeltaTimes[gname];
            if ((currtime-glast)<gdelta) then return; end
            GroupLastTimes[gname] = currtime;
            gbind:Fire();
        end
    end);
end

return _export;