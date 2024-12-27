--@native

-- The main sprite type
export type ScriptedImageSprite = {
    -- properties -- removed: spriteCount, columnCount
    adornee:            ImageLabel|ImageButton?;    -- [nil] the image label/button to apply the sprite to, sprite does nothing if nil
    spriteSheetId:      string;                     -- [""] the assed id of the sprite sheet, sprite does nothing if ""
    currentFrame:       Vector2;   --MODIFIED       -- READONLY [1,1] position of the frame that is currently visible (starts from 1,1)
    spriteSize:         Vector2;                    -- [0,0] the size of the individual sprites represented by the sprite sheet in pixels
    spriteOffset:       Vector2;                    -- [0,0] offset between individual sprites in pixels
    edgeOffset:         Vector2;                    -- [0,0] offset from the image's top-left edge in pixels
    frameRate:          number;                     -- [30] max frame rate the sprite can achieve when playing (can be any number, but will be clamped by RenderStepped frame rate)
    isPlaying:          boolean;                    -- READONLY [false] whether the sprite is playing or not
    -- methods -- removed: Stop, 
    Play:   (self:ScriptedImageSprite)->(boolean); --MODIFIED          -- plays the animation
    Pause:  (self:ScriptedImageSprite)->(boolean);                     -- pauses the animation
    SetFrame:(self:ScriptedImageSprite, frame:Vector2)->(); --MODIFIED -- manually sets the current frame
    Advance:(self:ScriptedImageSprite)->();   --MODIFIED               -- manually advances to the next frame, or 1 if last
    GetSignal:(self:ScriptedImageSprite, signalType:SignalType)->(RBXScriptSignal);
    -- callbacks
    onRenderCallback: (self:ScriptedImageSprite)->()?;   --ADDED       
};

-- format: "signalName" | -- (callback arguments) - description
type SignalType =
    "FrameChanged" |-- () - fires on frame change
    "PlayCalled" |  -- () - fires when :Play() is called if the sprite isn't playing
    "PauseCalled" | -- () - fires when :Pause() is called if the sprite is playing
    "StaticChanged" -- (propName:string) - fires when a static property has changed, such as: such as: adornee, spriteSheetId, spriteSize, spriteOffset, edgeOffset, frameRate


-- Properties parsed to Sprite.new(props), most are optional (aka. can be nil)
export type ScriptedImageSpriteProps = {
    adornee:            ImageLabel|ImageButton?;
    spriteSheetId:      string?;
    currentFrame:       number?;
    spriteSize:         Vector2?;
    spriteOffset:       Vector2?;
    edgeOffset:         Vector2?;
    frameRate:          number?;
    onRenderCallback:   (self:ScriptedImageSprite)->()?;
}

-- Don't touch anything below unless you know what you're doing
local Scheduler = require(script.Parent.Scheduler);
local _export = {};

-- Internal type with hidden values
export type ScriptedImageSpriteInternal = {
    __raw:ScriptedImageSpriteInternal;
    __stopcon:RBXScriptConnection?;
    __playcon:RBXScriptConnection?;
    __signalcache:{[string]:BindableEvent};
} & ScriptedImageSprite;

local ScriptedImageSprite = {}; do
    ScriptedImageSprite.__tostring = function() return "ScriptedImageSprite"; end
    ScriptedImageSprite.__index = ScriptedImageSprite;
    function ScriptedImageSprite.Play(self:ScriptedImageSpriteInternal)
        local raw = self.__raw;
        if (raw.isPlaying) then return false; end
        raw.isPlaying = true;
        raw.__playcon = Scheduler:GetOnRenderSignal(raw.frameRate):Connect(function()
            self:Advance();
        end);
        local _ev = self.__signalcache["PlayCalled"]; _ = _ev and _ev:Fire();
        return true;
    end
    function ScriptedImageSprite.Pause(self:ScriptedImageSpriteInternal)
        local raw = self.__raw;
        if (not raw.isPlaying) then return false; end
        raw.isPlaying = false;
        (raw.__playcon::RBXScriptConnection):Disconnect();
        raw.__playcon = nil;
        local _ev = self.__signalcache["PauseCalled"]; _ = _ev and _ev:Fire();
        return true;
    end
    function ScriptedImageSprite.Advance(self:ScriptedImageSpriteInternal)
        local call = self.onRenderCallback;
        if (call) then call(self); end
    end

    function ScriptedImageSprite.SetFrame(self:ScriptedImageSpriteInternal, newframe:Vector2)
        local raw = self.__raw;
        local oldFrame = raw.currentFrame;
        raw.currentFrame = newframe;
        local adornee = raw.adornee :: ImageLabel;
        if (not adornee) then return; end
        local edgeoff = raw.edgeOffset;
        local sprtoff = raw.spriteOffset;
        local size = raw.spriteSize;
        local posx = edgeoff.X + (newframe.X-1)*(size.X + sprtoff.X);
        local posy = edgeoff.Y + (newframe.Y-1)*(size.Y + sprtoff.Y);
        adornee.ImageRectOffset = Vector2.new(posx, posy);
        local _ev = oldFrame ~= newframe and raw.__signalcache["FrameChanged"]; _ = _ev and _ev:Fire();
    end

    -- create a signalType:bool hash to quickly check if the requested signalType is valid
    local validSignalTypes = {"FrameChanged","PlayCalled","PauseCalled","StaticChanged"};
    for _,i in pairs(validSignalTypes) do
        validSignalTypes[i]=true;
    end

    function ScriptedImageSprite.GetSignal(self:ScriptedImageSpriteInternal, signalType)
        local evcache = self.__signalcache;
        local evbind = evcache[signalType];
        if (not evbind) then
            if (not validSignalTypes[signalType]) then
                error("Invalid signal type "..signalType);
            end
            evbind = Instance.new("BindableEvent");
            evcache[signalType] = evbind;
        end
        return evbind.Event;
    end
end

local ProxyMetaNewIndex = function(self:ScriptedImageSpriteInternal, i:string, v1:any)
    local raw = self.__raw;
    local v0 = raw[i];
    if (v0==v1) then return; end
    if (i=="isLooped" or i=="currentFrame") then
        error(`Property {i} is read-only`);
    end
    raw[i] = v1;
    -- behavior
    if (i=="frameRate") then
        if (raw.isPlaying) then
            self:Pause(); self:Play();
        end
    elseif (i=="spriteSize") then
        local adornee = raw.adornee;
        if (adornee) then
            if (raw.spriteSheetId~="") then
                adornee.Image = raw.spriteSheetId;
            end
            adornee.ImageRectSize = raw.spriteSize;
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="adornee") then
        if (v1) then
            if (raw.spriteSheetId~="") then
                v1.Image = raw.spriteSheetId;
            end
            v1.ImageRectSize = raw.spriteSize;
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="edgeOffset" or i=="spriteOffset") then
        if (raw.adornee) then
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="spriteSheetId") then
        local adornee = raw.adornee;
        if (adornee) then
            adornee.Image = v1;
        end
    end
    local _ev = raw.__signalcache["StaticChanged"]; _ = _ev and _ev:Fire(i);
end

_export.new = function(props:ScriptedImageSpriteProps)
    local raw = {} :: ScriptedImageSpriteInternal;
    raw.adornee = props.adornee;
    raw.spriteSheetId = props.spriteSheetId or "";
    raw.currentFrame = props.currentFrame or Vector2.one;
    raw.spriteSize = props.spriteSize or Vector2.zero;
    raw.spriteOffset = props.spriteOffset or Vector2.zero;
    raw.edgeOffset = props.edgeOffset or Vector2.zero;
    raw.frameRate = props.frameRate or 30;
    raw.isPlaying = false;
    raw.onRenderCallback = props.onRenderCallback;
    raw.__signalcache = {};
    raw.__raw = raw;
    setmetatable(raw, ScriptedImageSprite);
    
    local proxy = newproxy(true);
    local meta = getmetatable(proxy);
    meta.__tostring = function() return "ScriptedImageSprite"; end
    meta.__index = raw;
    meta.__newindex = ProxyMetaNewIndex;

    if (raw.adornee and raw.spriteSheetId~="") then
        raw.adornee.Image = raw.spriteSheetId;
        raw.adornee.ImageRectSize = raw.spriteSize;
        proxy:SetFrame(raw.currentFrame);
    end
    return proxy::ScriptedImageSprite;
end

return _export;