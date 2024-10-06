--@native

--[[
    The classic sprite, similar to how the original module worked
    Directly applies offset to the adornee image label/button
    Check type definitions below for detailed explanation
        format: [default] description
]]

-- The main sprite type
export type ImageSprite = {
    -- properties
    adornee:            ImageLabel|ImageButton?;    -- [nil] the image label/button to apply the sprite to, sprite does nothing if nil
    spriteSheetId:      string;                     -- [""] the assed id of the sprite sheet, sprite does nothing if ""
    currentFrame:       number;                     -- READONLY [1] index of the frame that is currently visible (starts from 1)
    spriteSize:         Vector2;                    -- [0,0] the size of the individual sprites represented by the sprite sheet in pixels
    spriteOffset:       Vector2;                    -- [0,0] offset between individual sprites in pixels
    edgeOffset:         Vector2;                    -- [0,0] offset from the image's top-left edge in pixels
    spriteCount:        number;                     -- [0] total number of sprites
    columnCount:        number;                     -- [0] total number of sprite columns (left-to-right sprite count)
    frameRate:          number;                     -- [30] max frame rate the sprite can achieve when playing (can be any number, but will be clamped by RenderStepped frame rate)
    isLooped:           boolean;                    -- [true] if the sprite loops while playing (stops at last frame otherwise)
    isPlaying:          boolean;                    -- READONLY [false] whether the sprite is playing or not
    -- methods
    Play:   (self:ImageSprite, playFrom:number?)->(boolean);   -- plays the animation
    Pause:  (self:ImageSprite)->(boolean);                     -- pauses the animation
    Stop:   (self:ImageSprite)->(boolean);                     -- pauses the animation and sets the current frame to 1
    SetFrame:(self:ImageSprite, frame:number)->();             -- manually sets the current frame
    Advance:(self:ImageSprite)->();             -- manually advances to the next frame, or 1 if last
};

-- Properties parsed to Sprite.new(props), most are optional (aka. can be nil)
export type ImageSpriteProps = {
    adornee:            ImageLabel|ImageButton?;
    spriteSheetId:      string?;
    currentFrame:       number?;
    spriteSize:         Vector2?;
    spriteOffset:       Vector2?;
    edgeOffset:         Vector2?;
    spriteCount:        number?;
    columnCount:        number?;
    frameRate:          number?;
    isLooped:           boolean?;
}

-- Don't touch anything below unless you know what you're doing
local Scheduler = require(script.Parent.Scheduler);
local _export = {};

-- Internal type with hidden values
export type ImageSpriteInternal = {
    __raw:ImageSpriteInternal;
    __stopcon:RBXScriptConnection?;
    __playcon:RBXScriptConnection?;
} & ImageSprite;

local ImageSprite = {}; do
    ImageSprite.__tostring = function() return "ImageSprite"; end
    ImageSprite.__index = ImageSprite;
    function ImageSprite.Play(self:ImageSpriteInternal, playFrom:number?)
        local raw = self.__raw;
        if (raw.isPlaying) then return false; end
        if (playFrom) then self:SetFrame(playFrom); end
        raw.isPlaying = true;
        raw.__playcon = Scheduler:GetSignal(tostring(raw.frameRate)):Connect(function()
            self:Advance();
        end);
        return true;
    end
    function ImageSprite.Pause(self:ImageSpriteInternal)
        local raw = self.__raw;
        if (not raw.isPlaying) then return false; end
        raw.isPlaying = false;
        (raw.__playcon::RBXScriptConnection):Disconnect();
        raw.__playcon = nil;
        return true;
    end
    function ImageSprite.Stop(self:ImageSpriteInternal)
        self:SetFrame(1);
        return self:Pause();
    end
    function ImageSprite.Advance(self:ImageSpriteInternal)
        local raw = self.__raw;
        local nextframe = raw.currentFrame + 1;
        if (nextframe > raw.spriteCount) then
            if (raw.isPlaying and not raw.isLooped) then
                self:Pause();
                return;
            end
            nextframe = 1;
        end
        self:SetFrame(nextframe);
    end

    function ImageSprite.SetFrame(self:ImageSpriteInternal, newframe:number)
        local raw = self.__raw;
        if (newframe<1 or newframe>raw.spriteCount) then
            error("Invalid frame number "..newframe);
        end
        raw.currentFrame = newframe;
        local adornee = raw.adornee :: ImageLabel;
        if (not adornee) then return; end
        local col = raw.columnCount;
        local ix = (newframe-1) % col;
        local iy = math.floor((newframe-1) / col);
        local size = raw.spriteSize;
        local offedge = raw.edgeOffset;
        local offsprt = raw.spriteOffset;
        local posx = offedge.X + ix*(size.X + offsprt.X);
        local posy = offedge.Y + iy*(size.Y + offsprt.Y);
        adornee.ImageRectOffset = Vector2.new(posx, posy);
    end
end

local ProxyMetaNewIndex = function(self:ImageSpriteInternal, i:string, v1:any)
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
            if (raw.spriteSheetId~="") then
                adornee.Image = raw.spriteSheetId;
            end
            adornee.ImageRectSize = raw.spriteSize;
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="columnCount" or i=="spriteCount" or i=="edgeOffset" or i=="spriteOffset") then
        if (raw.adornee) then
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="spriteSheetId") then
        local adornee = raw.adornee;
        if (adornee) then
            adornee.Image = v1;
        end
    end
end

_export.new = function(props:ImageSpriteProps)
    local raw = {} :: ImageSpriteInternal;
    raw.adornee = props.adornee;
    raw.spriteSheetId = props.spriteSheetId or "";
    raw.currentFrame = props.currentFrame or 1;
    raw.spriteSize = props.spriteSize or Vector2.zero;
    raw.spriteOffset = props.spriteOffset or Vector2.zero;
    raw.edgeOffset = props.edgeOffset or Vector2.zero;
    raw.spriteCount = props.spriteCount or 0;
    raw.columnCount = props.columnCount or 0;
    raw.frameRate = props.frameRate or 30;
    raw.isLooped = if props.isLooped ~= nil then props.isLooped else true;
    raw.isPlaying = false;
    raw.__raw = raw;
    setmetatable(raw, ImageSprite);
    
    local proxy = newproxy(true);
    local meta = getmetatable(proxy);
    meta.__tostring = function() return "ImageSprite"; end
    meta.__index = raw;
    meta.__newindex = ProxyMetaNewIndex;

    if (raw.adornee and raw.spriteSheetId~="") then
        raw.adornee.Image = raw.spriteSheetId;
        raw.adornee.ImageRectSize = raw.spriteSize;
        proxy:SetFrame(raw.currentFrame);
    end
    return proxy::ImageSprite;
end

return _export;