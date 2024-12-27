--@native

--[[
    A sprite class that combines multiple input editable images into one sprite for high resolution animations.
    Untested and not fully documented. Use at your own risk.
    Main difference: Instead of Vector2 for currentFrame, Vector3 is used where Z represents an index in inputImages
]]

local assetService = game:GetService("AssetService")

-- The main sprite type
export type CompositeSprite = {
    -- properties -- removed: spriteCount, columnCount
    inputImages:        {EditableImage};            --  a list of editable images to read the data from
    outputImage:        EditableImage;              -- [nil] editable image to write the pixel data to, can be replaced with a different editable image
    outputPosition:     Vector2;                    -- [0,0] where to render on the output image, useful for storing multiple sprites as an atlas
    currentFrame:       Vector3;                    -- READONLY [1,1,1] position of the frame that is currently visible (starts from 1,1), Z represents the index of the input image
    spriteSize:         Vector2;                    -- [0,0] the size of the individual sprites represented by the sprite sheet in pixels
    spriteOffset:       Vector2;                    -- [0,0] offset between individual sprites in pixels
    edgeOffset:         Vector2;                    -- [0,0] offset from the image's top-left edge in pixels
    frameRate:          number;                     -- [30] max frame rate the sprite can achieve when playing (can be any number, but will be clamped by RenderStepped frame rate)
    isPlaying:          boolean;                    -- READONLY [false] whether the sprite is playing or not
    -- methods -- removed: Stop, 
    Play:   (self:CompositeSprite)->(boolean); --MODIFIED          -- plays the animation
    Pause:  (self:CompositeSprite)->(boolean);                     -- pauses the animation
    SetFrame:(self:CompositeSprite, frame:Vector2)->(); --MODIFIED -- manually sets the current frame
    Advance:(self:CompositeSprite)->();   --MODIFIED               -- manually advances to the next frame, or 1 if last
    LoadInputImage: (self:CompositeSprite, newInput:EditableImage|string, index:number?)->();   -- async if given a string, replaces the input image at the given index, or appends to list if nil
    GetSignal:(self:CompositeSprite, signalType:SignalType)->(RBXScriptSignal);
    -- callbacks
    onRenderCallback: (self:CompositeSprite)->()?;   --ADDED       
};

-- format: "signalName" | -- (callback arguments) - description
type SignalType =
    "FrameChanged" |-- () - fires on frame change
    "PlayCalled" |  -- () - fires when :Play() is called if the sprite isn't playing
    "PauseCalled" | -- () - fires when :Pause() is called if the sprite is playing
    "StaticChanged" -- (propName:string) - fires when a static property has changed, such as: such as: inputImage, outputImage, outputPosition, spriteSize, spriteOffset, edgeOffset, frameRate

-- Properties parsed to Sprite.new(props), most are optional (aka. can be nil)
export type CompositeProps = {
    inputImages:        {EditableImage|string}?;
    outputImage:        EditableImage?;
    outputPosition:     Vector2?;
    currentFrame:       number?;
    spriteSize:         Vector2?;
    spriteOffset:       Vector2?;
    edgeOffset:         Vector2?;
    frameRate:          number?;
    onRenderCallback:   (self:CompositeSprite)->()?;
}

-- Don't touch anything below unless you know what you're doing
local Scheduler = require(script.Parent.Scheduler);
local _export = {};
local AssetService = game:GetService("AssetService");

-- Internal type with hidden values
export type CompositeSpriteInternal = {
    __raw:CompositeSpriteInternal;
    __stopcon:RBXScriptConnection?;
    __playcon:RBXScriptConnection?;
    __signalcache:{[string]:BindableEvent};
} & CompositeSprite;

local ScriptedEditableSprite = {}; do
    ScriptedEditableSprite.__index = ScriptedEditableSprite;
    ScriptedEditableSprite.__tostring = function() return "ScriptedEditableSprite"; end
    function ScriptedEditableSprite.Play(self:CompositeSpriteInternal)
        local raw = self.__raw;
        if (raw.isPlaying) then return false; end
        raw.isPlaying = true;
        raw.__playcon = Scheduler:GetOnRenderSignal(raw.frameRate):Connect(function()
            self:Advance();
        end);
        local _ev = self.__signalcache["PlayCalled"]; _ = _ev and _ev:Fire();
        return true;
    end
    function ScriptedEditableSprite.Pause(self:CompositeSpriteInternal)
        local raw = self.__raw;
        if (not raw.isPlaying) then return false; end
        raw.isPlaying = false;
        (raw.__playcon::RBXScriptConnection):Disconnect();
        local _ev = self.__signalcache["PauseCalled"]; _ = _ev and _ev:Fire();
        return true;
    end
    function ScriptedEditableSprite.Advance(self:CompositeSpriteInternal)
        local call = self.onRenderCallback;
        if (call) then call(self); end
    end

    function ScriptedEditableSprite.SetFrame(self:CompositeSpriteInternal, newframe:Vector3)
        local raw = self.__raw;
        local oldFrame = raw.currentFrame;
        raw.currentFrame = newframe;
        local input = self.inputImages[newframe.Z] or error("Index out of range") :: EditableImage;
        if (not input) then return; end
        local edgeoff = raw.edgeOffset;
        local sprtoff = raw.spriteOffset;
        local size = raw.spriteSize;
        local posx = edgeoff.X + (newframe.X-1)*(size.X + sprtoff.X);
        local posy = edgeoff.Y + (newframe.Y-1)*(size.Y + sprtoff.Y);
        self.outputImage:WritePixelsBuffer(raw.outputPosition, size, input:ReadPixelsBuffer(Vector2.new(posx,posy), size));
        local _ev = oldFrame ~= newframe and raw.__signalcache["FrameChanged"]; _ = _ev and _ev:Fire();
    end

    function ScriptedEditableSprite.LoadInputImage(self:CompositeSpriteInternal, newinput, index)
        local raw = self.__raw;
        index = index or #raw.inputImages+1;
        raw.inputImages[index] = if type(newinput)~="string" then newinput::EditableImage else AssetService:CreateEditableImageAsync(newinput::string);
        self:SetFrame(raw.currentFrame);
    end

    -- create a signalType:bool hash to quickly check if the requested signalType is valid
    local validSignalTypes = {"FrameChanged","PlayCalled","PauseCalled","StaticChanged"};
    for _,i in pairs(validSignalTypes) do
        validSignalTypes[i]=true;
    end

    function ScriptedEditableSprite.GetSignal(self:CompositeSpriteInternal, signalType)
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

local ProxyMetaNewIndex = function(self:CompositeSpriteInternal, i:string, v1:any)
    local raw = self.__raw;
    local v0 = raw[i];
    if (v0==v1) then return; end
    if (i=="isLooped" or i=="currentFrame" or i=="inputImages") then
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
    local _ev = raw.__signalcache["StaticChanged"]; _ = _ev and _ev:Fire(i);
end

--local config = require(script.Parent.config);
_export.new = function(props:CompositeProps)

    local raw = {} :: CompositeSpriteInternal;
    raw.inputImages = {};
    raw.outputImage = props.outputImage;
    raw.outputPosition = props.outputPosition or Vector2.zero;
    raw.currentFrame = props.currentFrame or Vector2.one;
    raw.spriteSize = props.spriteSize or error("Sprite size must be provided");
    raw.spriteOffset = props.spriteOffset or Vector2.zero;
    raw.edgeOffset = props.edgeOffset or Vector2.zero;
    raw.frameRate = props.frameRate or 30;
    raw.isPlaying = false;
    raw.onRenderCallback = props.onRenderCallback;
    raw.__signalcache = {};
    raw.__raw = raw;
    setmetatable(raw, ScriptedEditableSprite);
    
    if (not raw.outputImage) then
        raw.outputImage = assetService:CreateEditableImage({
            Size = raw.spriteSize
        })
    end

    local proxy = newproxy(true);
    local meta = getmetatable(proxy);
    meta.__tostring = function() return "CompositeSprite"; end
    meta.__index = raw;
    meta.__newindex = ProxyMetaNewIndex;

    for _,v in pairs(props.inputImages or {}) do
         proxy:LoadInputImage(v);
    end
    return proxy::CompositeSprite;
end

return _export;