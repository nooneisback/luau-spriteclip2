--@native

--[[
    A more advanced version of ScriptedEditableSprite that doesn't apply currentFrame automatically,
    instead it allows you to manually select the sprite's position on each render tick.
    To do so, give it an onRenderCallback function through props or directly, which can call SetFrame
    on each render tick.

    Check type definitions below for detailed explanation
        format: [default] description
]]

-- The main sprite type
export type ScriptedEditableSprite = {
    -- properties -- removed: spriteCount, columnCount
    inputImage:         EditableImage?; -- READONLY [nil] editable image to read the pixel data from, change using LoadInputImage
    outputImage:        EditableImage;  -- [nil] editable image to write the pixel data to, can be replaced with a different editable image
    outputPosition:     Vector2;        -- [0,0] where to render on the output image, useful for storing multiple sprites as an atlas
    currentFrame:       Vector2;   --MODIFIED       -- READONLY [1,1] position of the frame that is currently visible (starts from 1,1)
    spriteSize:         Vector2;                    -- [0,0] the size of the individual sprites represented by the sprite sheet in pixels
    spriteOffset:       Vector2;                    -- [0,0] offset between individual sprites in pixels
    edgeOffset:         Vector2;                    -- [0,0] offset from the image's top-left edge in pixels
    frameRate:          number;                     -- [30] max frame rate the sprite can achieve when playing (can be any number, but will be clamped by RenderStepped frame rate)
    isPlaying:          boolean;                    -- READONLY [false] whether the sprite is playing or not
    -- methods -- removed: Stop, 
    Play:   (self:ScriptedEditableSprite)->(boolean); --MODIFIED          -- plays the animation
    Pause:  (self:ScriptedEditableSprite)->(boolean);                     -- pauses the animation
    SetFrame:(self:ScriptedEditableSprite, frame:Vector2)->(); --MODIFIED -- manually sets the current frame
    Advance:(self:ScriptedEditableSprite)->();   --MODIFIED               -- manually advances to the next frame, or 1 if last
    -- callbacks
    onRenderCallback: (self:ScriptedEditableSprite)->()?;   --ADDED       
};

-- Properties parsed to Sprite.new(props), most are optional (aka. can be nil)
export type ScriptedEditableSpriteProps = {
    inputImage:         EditableImage|string?;
    outputImage:        EditableImage?;
    outputPosition:     Vector2?;
    currentFrame:       number?;
    spriteSize:         Vector2;       -- REQUIRED
    spriteOffset:       Vector2?;
    edgeOffset:         Vector2?;
    frameRate:          number?;
    isLooped:           boolean?;
    onRenderCallback:   (self:ScriptedEditableSprite)->()?;
}

-- Don't touch anything below unless you know what you're doing
local Scheduler = require(script.Parent.Scheduler);
local _export = {};
local AssetService = game:GetService("AssetService");

-- Internal type with hidden values
export type ScriptedEditableSpriteInternal = {
    __raw:ScriptedEditableSprite;
    __stopcon:RBXScriptConnection?;
    __playcon:RBXScriptConnection?;
} & ScriptedEditableSprite;

local ScriptedEditableSprite = {}; do
    ScriptedEditableSprite.__index = ScriptedEditableSprite;
    ScriptedEditableSprite.__tostring = function() return "ScriptedEditableSprite"; end
    function ScriptedEditableSprite.Play(self:ScriptedEditableSpriteInternal)
        local raw = self.__raw;
        if (raw.isPlaying) then return false; end
        raw.isPlaying = true;
        raw.__playcon = Scheduler:GetSignal(tostring(raw.frameRate)):Connect(function()
            self:Advance();
        end);
        return true;
    end
    function ScriptedEditableSprite.Pause(self:ScriptedEditableSpriteInternal)
        local raw = self.__raw;
        if (not raw.isPlaying) then return false; end
        raw.isPlaying = false;
        (raw.__playcon::RBXScriptConnection):Disconnect();
        return true;
    end
    function ScriptedEditableSprite.Advance(self:ScriptedEditableSpriteInternal)
        local call = self.onRenderCallback;
        if (call) then call(self); end
    end

    function ScriptedEditableSprite.SetFrame(self:ScriptedEditableSpriteInternal, newframe:Vector2)
        local raw = self.__raw;
        raw.currentFrame = newframe;
        local input = self.inputImage :: EditableImage;
        if (not input) then return; end
        local edgeoff = raw.edgeOffset;
        local sprtoff = raw.spriteOffset;
        local size = raw.spriteSize;
        local posx = edgeoff.X + (newframe.X-1)*(size.X + sprtoff.X);
        local posy = edgeoff.Y + (newframe.Y-1)*(size.Y + sprtoff.Y);
        self.outputImage:WritePixels(raw.outputPosition, size, input:ReadPixels(Vector2.new(posx,posy), size));
    end

    function ScriptedEditableSprite.LoadInputImage(self:ScriptedEditableSpriteInternal, newinput:EditableImage|string)
        local raw = self.__raw;
        raw.inputImage = if type(newinput)~="string" then newinput::EditableImage else AssetService:CreateEditableImageAsync(newinput::string);
        self:SetFrame(raw.currentFrame);
    end
end

local ProxyMetaNewIndex = function(self:ScriptedEditableSpriteInternal, i:string, v1:any)
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
    elseif (i=="outputImage" or i=="outputPosition") then
        self:SetFrame(raw.currentFrame);
    elseif (i=="spriteSize") then
        raw.outputImage.Size = v1;
        if (raw.inputImage) then
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="edgeOffset" or i=="spriteOffset") then
        if (raw.inputImage) then
            self:SetFrame(raw.currentFrame);
        end
    end
end

local config = require(script.Parent.config);
_export.new = function(props:ScriptedEditableSpriteProps)
    if (config.WarnEditableImageAPI) then
        warn("Sprites relying on the EditableImageAPI (EditableSprite and ScriptedEditableSprite) are currently only available in studio");
    end

    local raw = {} :: ScriptedEditableSpriteInternal;
    raw.inputImage = nil;
    raw.outputImage = props.outputImage;
    raw.outputPosition = props.outputPosition or Vector2.zero;
    raw.currentFrame = props.currentFrame or Vector2.one;
    raw.spriteSize = props.spriteSize or Vector2.zero;
    raw.spriteOffset = props.spriteOffset or Vector2.zero;
    raw.edgeOffset = props.edgeOffset or Vector2.zero;
    raw.frameRate = props.frameRate or 30;
    raw.isLooped = if props.isLooped ~= nil then props.isLooped else true;
    raw.isPlaying = false;
    raw.onRenderCallback = props.onRenderCallback;
    raw.__raw = raw;
    setmetatable(raw, ScriptedEditableSprite);
    
    if (not raw.outputImage) then
        raw.outputImage = Instance.new("EditableImage");
        raw.outputImage.Size = raw.spriteSize;
    end

    local proxy = newproxy(true);
    local meta = getmetatable(proxy);
    meta.__tostring = function() return "ScriptedEditableSprite"; end
    meta.__index = raw;
    meta.__newindex = ProxyMetaNewIndex;

    if (props.inputImage) then
        proxy:LoadInputImage(props.inputImage);
    end
    return proxy::ScriptedEditableSprite;
end

return _export;