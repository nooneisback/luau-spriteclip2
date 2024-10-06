--@native

--[[
    A more advanced version of SimpleSprite that doesn't apply currentFrame automatically,
    instead it allows you to manually select the sprite's position on each render tick.
    To do so, give it an onRenderCallback function through props or directly, which can call SetFrame
    on each render tick.

    Check type definitions below for detailed explanation
        format: [default] description
]]

-- The main sprite type
export type ScriptedSimpleSprite = {
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
    Play:   (self:ScriptedSimpleSprite)->(boolean); --MODIFIED          -- plays the animation
    Pause:  (self:ScriptedSimpleSprite)->(boolean);                     -- pauses the animation
    SetFrame:(self:ScriptedSimpleSprite, frame:Vector2)->(); --MODIFIED -- manually sets the current frame
    Advance:(self:ScriptedSimpleSprite)->();   --MODIFIED               -- manually advances to the next frame, or 1 if last
    -- callbacks
    onRenderCallback: (self:ScriptedSimpleSprite)->()?;   --ADDED       
};

-- Properties parsed to Sprite.new(props), most are optional (aka. can be nil)
export type ScriptedSimpleSpriteProps = {
    adornee:            ImageLabel|ImageButton?;
    spriteSheetId:      string?;
    currentFrame:       number?;
    spriteSize:         Vector2?;
    spriteOffset:       Vector2?;
    edgeOffset:         Vector2?;
    frameRate:          number?;
    isLooped:           boolean?;
    onRenderCallback:   (self:ScriptedSimpleSprite)->()?;
}

-- Don't touch anything below unless you know what you're doing
local Scheduler = require(script.Parent.Scheduler);
local _export = {};

-- Internal type with hidden values
export type ScriptedSimpleSpriteInternal = {
    __raw:ScriptedSimpleSprite;
    __stopcon:RBXScriptConnection?;
    __playcon:RBXScriptConnection?;
} & ScriptedSimpleSprite;

local ScriptedSimpleSprite = {}; do
    ScriptedSimpleSprite.__index = ScriptedSimpleSprite;
    function ScriptedSimpleSprite.Play(self:ScriptedSimpleSpriteInternal)
        if (self.isPlaying) then return false; end
        local raw = self.__raw;
        raw.isPlaying = true;
        raw.__playcon = Scheduler:GetSignal(tostring(self.frameRate)):Connect(function()
            self:Advance();
        end);
        return true;
    end
    function ScriptedSimpleSprite.Pause(self:ScriptedSimpleSpriteInternal)
        if (not self.isPlaying) then return false; end
        local raw = self.__raw;
        raw.isPlaying = false;
        (raw.__playcon::RBXScriptConnection):Disconnect();
        return true;
    end
    function ScriptedSimpleSprite.Advance(self:ScriptedSimpleSpriteInternal)
        local call = self.onRenderCallback;
        if (call) then call(self); end
    end

    function ScriptedSimpleSprite.SetFrame(self:ScriptedSimpleSpriteInternal, newframe:Vector2)
        self.__raw.currentFrame = newframe;
        local adornee = self.adornee :: ImageLabel;
        if (not adornee) then return; end
        local posx = self.edgeOffset.X + (newframe.X-1)*(self.spriteSize.X + self.spriteOffset.X);
        local posy = self.edgeOffset.Y + (newframe.Y-1)*(self.spriteSize.Y + self.spriteOffset.Y);
        adornee.ImageRectOffset = Vector2.new(posx, posy);
    end
end

local ProxyMetaNewIndex = function(self:ScriptedSimpleSpriteInternal, i:string, v1:any)
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
    elseif (i=="spriteSize" or i=="adornee") then
        local adornee = raw.adornee;
        if (adornee) then
            if (self.spriteSheetId~="") then
                adornee.spriteSheetId = self.spriteSheetId;
            end
            adornee.ImageRectSize = raw.spriteSize;
            self:SetFrame(self.currentFrame);
        end
    elseif (i=="edgeOffset" or i=="spriteOffset") then
        if (self.adornee) then
            self:SetFrame(self.currentFrame);
        end
    elseif (i=="spriteSheetId") then
        local adornee = raw.adornee;
        if (adornee) then
            adornee.Image = v1;
        end
    end
end

_export.new = function(props:ScriptedSimpleSpriteProps)
    local raw = {} :: ScriptedSimpleSpriteInternal;
    raw.adornee = props.adornee;
    raw.spriteSheetId = props.spriteSheetId or "";
    raw.currentFrame = props.currentFrame or Vector2.one;
    raw.spriteSize = props.spriteSize or Vector2.zero;
    raw.spriteOffset = props.spriteOffset or Vector2.zero;
    raw.edgeOffset = props.edgeOffset or Vector2.zero;
    raw.frameRate = props.frameRate or 30;
    raw.isLooped = if props.isLooped ~= nil then props.isLooped else true;
    raw.isPlaying = false;
    raw.onRenderCallback = props.onRenderCallback;
    raw.__raw = raw;
    setmetatable(raw, ScriptedSimpleSprite);
    
    local proxy = newproxy(true);
    local meta = getmetatable(proxy);
    meta.__index = raw;
    meta.__newindex = ProxyMetaNewIndex;

    if (raw.adornee and raw.spriteSheetId~="") then
        raw.adornee.Image = raw.spriteSheetId;
        raw.adornee.ImageRectSize = raw.spriteSize;
        proxy:SetFrame(raw.currentFrame);
    end
    return proxy::ScriptedSimpleSprite;
end

return _export;