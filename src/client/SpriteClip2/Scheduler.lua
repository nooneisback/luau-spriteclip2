local _export = {};

-- use this instead
local foldPreRenderSignals = script:FindFirstChild("PreRenderSignals");
local foldOnRenderSigs = script:FindFirstChild("OnRenderSignals");
local foldPostRenderSigs = script:FindFirstChild("PostRenderSignals");
if (not foldOnRenderSigs) then
    foldPreRenderSignals = Instance.new("Folder"); foldPreRenderSignals.Name="PreRenderSignals"; foldPreRenderSignals.Parent = script;
    foldOnRenderSigs = Instance.new("Folder"); foldOnRenderSigs.Name="OnRenderSignals"; foldOnRenderSigs.Parent = script;
    foldPostRenderSigs = Instance.new("Folder"); foldPostRenderSigs.Name="OnRenderSignals"; foldPostRenderSigs.Parent = script;
end

-- deprecated, replaced with GetOnRenderSignal
function _export:GetSignal(framerate:number)
    return _export:GetOnRenderSignal(framerate);
end

function _export:GetPreRenderSignal(framerate:number)
    local gname = tostring(framerate);
    local bind:BindableEvent = foldPreRenderSignals:FindFirstChild(gname);
    if (not bind) then
        local _bind = Instance.new("BindableEvent") :: BindableEvent;
        bind = _bind;
        _bind.Name = gname;
        _bind.Parent = foldPreRenderSignals;
    end
    return bind.Event;
end

function _export:GetOnRenderSignal(framerate:number)
    local gname = tostring(framerate);
    local bind:BindableEvent = foldOnRenderSigs:FindFirstChild(gname);
    if (not bind) then
        local _bind = Instance.new("BindableEvent") :: BindableEvent;
        bind = _bind;
        _bind.Name = gname;
        _bind.Parent = foldOnRenderSigs;
    end
    return bind.Event;
end

function _export:GetPostRenderSignal(framerate:number)
    local gname = tostring(framerate);
    local bind:BindableEvent = foldPostRenderSigs:FindFirstChild(gname);
    if (not bind) then
        local _bind = Instance.new("BindableEvent") :: BindableEvent;
        bind = _bind;
        _bind.Name = gname;
        _bind.Parent = foldPostRenderSigs;
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

    local GroupPreBinds:{[string]:BindableEvent} = {};
    local GroupOnBinds:{[string]:BindableEvent} = {};
    local GroupPostBinds:{[string]:BindableEvent} = {};
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
        if (bind.Parent == foldOnRenderSigs) then
            local gname = bind.Name;
            GroupOnBinds[gname] = bind;
            local delta = 1 / tonumber(gname)::number;
            GroupLastTimes[gname] = os.clock();
            GroupDeltaTimes[gname] = delta;
        elseif (bind.Parent == foldPostRenderSigs) then
            local gname = bind.Name;
            GroupPostBinds[gname] = bind;
        else
            local gname = bind.Name;
            GroupPreBinds[gname] = bind;
        end
    end
    for _,v in ipairs(foldPreRenderSignals:GetChildren()) do LoadGroup(v); end
    for _,v in ipairs(foldOnRenderSigs:GetChildren()) do LoadGroup(v); end
    for _,v in ipairs(foldPostRenderSigs:GetChildren()) do LoadGroup(v); end
    foldPreRenderSignals.ChildAdded:Connect(LoadGroup);
    foldOnRenderSigs.ChildAdded:Connect(LoadGroup);
    foldPostRenderSigs.ChildAdded:Connect(LoadGroup);

    game:GetService("RunService").RenderStepped:Connect(function(d)
        currtime += d;
        if (ispaused) then return; end
        local tocall = {};
        for gname, onbind in pairs(GroupOnBinds) do
            local glast = GroupLastTimes[gname];
            local gdelta = GroupDeltaTimes[gname];
            if ((currtime-glast)<gdelta) then return; end
            GroupLastTimes[gname] = currtime;
            table.insert(tocall, gname);
            local bind = GroupPreBinds[gname];
            if (bind) then bind:Fire(gdelta); end
        end
        for _, gname in ipairs(tocall) do
            local bind = GroupOnBinds[gname];
            local gdelta = GroupDeltaTimes[gname];
            bind:Fire(gdelta);
        end
        for _, gname in ipairs(tocall) do
            local bind = GroupPostBinds[gname];
            if (bind) then
                local gdelta = GroupDeltaTimes[gname];
                bind:Fire(gdelta);
            end
        end
    end);
end

return _export;