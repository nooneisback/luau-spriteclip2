--@native

--[[
    A Sprite that takes input and gives output as an EditableImage
    Check type definitions below for detailed explanation
        format: [default] description
]]


-- The main sprite type
export type EditableSprite = {
    -- properties
    inputImage:         EditableImage?; -- READONLY [nil] editable image to read the pixel data from, change using LoadInputImage
    outputImage:        EditableImage;  -- [nil] editable image to write the pixel data to, can be replaced with a different editable image
    currentFrame:       number;         -- READONLY [1] index of the frame that is currently visible (starts from 1)
    spriteSize:         Vector2;        -- [0,0] the size of the individual sprites represented by the sprite sheet in pixels
    spriteOffset:       Vector2;        -- [0,0] offset between individual sprites in pixels
    edgeOffset:         Vector2;        -- [0,0] offset from the image's top-left edge in pixels
    spriteCount:        number;         -- [0] total number of sprites
    columnCount:        number;         -- [0] total number of sprite columns (left-to-right sprite count)
    frameRate:          number;         -- [30] max frame rate the sprite can achieve when playing (can be any number, but will be clamped by RenderStepped frame rate)
    isLooped:           boolean;        -- [true] if the sprite loops while playing (stops at last frame otherwise)
    isPlaying:          boolean;        -- READONLY [false] whether the sprite is playing or not
    -- methods
    Play:   (self:EditableSprite, playFrom:number?)->(boolean);                 -- plays the animation
    Pause:  (self:EditableSprite)->(boolean);                                   -- pauses the animation
    Stop:   (self:EditableSprite)->(boolean);                                   -- pauses the animation and sets the current frame to 1
    SetFrame:(self:EditableSprite, frame:number)->();                           -- manually sets the current frame
    Advance:(self:EditableSprite, count:number?)->();                           -- manually advances to the next frame, or 1 if last
    LoadInputImage: (self:EditableSprite, newinput:EditableImage|string)->();   -- ASYNC if given a string, replaces the input image with a new one
};

-- Properties parsed to Sprite.new(props), most are optional (aka. can be nil)
export type EditableSpriteProps = {
    inputImage:         EditableImage|string?;
    currentFrame:       number?;
    spriteSize:         Vector2;       -- REQUIRED
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
local AssetService = game:GetService("AssetService");

export type EditableSpriteInternal = {
    __raw:EditableSprite;
    __playcon:RBXScriptConnection?;
} & EditableSprite;

local EditableSprite = {}; do
    EditableSprite.__index = EditableSprite;
    function EditableSprite.Play(self:EditableSpriteInternal, playFrom:number?)
        if (self.isPlaying) then return false; end
        if (playFrom) then self:SetFrame(playFrom); end
        local raw = self.__raw;
        raw.isPlaying = true;
        raw.__playcon = Scheduler:GetSignal(tostring(self.frameRate)):Connect(function()
            self:Advance(1);
        end);
        return true;
    end
    function EditableSprite.Pause(self:EditableSpriteInternal)
        if (not self.isPlaying) then return false; end
        local raw = self.__raw;
        raw.isPlaying = false;
        (raw.__playcon::RBXScriptConnection):Disconnect();
        return true;
    end
    function EditableSprite.Stop(self:EditableSpriteInternal)
        self:SetFrame(1);
        return self:Pause();
    end
    function EditableSprite.Advance(self:EditableSpriteInternal)
        local nextframe = self.currentFrame + 1;
        if (nextframe > self.spriteCount) then
            if (self.isPlaying and not self.isLooped) then
                self:Pause();
                return;
            end
            nextframe = 1;
        end
        self:SetFrame(nextframe);
    end

    function EditableSprite.SetFrame(self:EditableSpriteInternal, newframe:number)
        if (newframe<1 or newframe>self.spriteCount) then
            error("Invalid frame number "..newframe);
        end
        self.__raw.currentFrame = newframe;
        local input = self.inputImage :: EditableImage;
        if (not input) then return; end
        local ix = (newframe-1) % self.columnCount;
        local iy = math.floor((newframe-1) / self.columnCount);
        local off = self.spriteOffset;
        local size = self.spriteSize;
        local pos = self.edgeOffset + Vector2.new(ix,iy) * (size+off);
        self.outputImage:WritePixels(Vector2.zero, size, input:ReadPixels(pos, size));
    end

    function EditableSprite.LoadInputImage(self:EditableSpriteInternal, newinput:EditableImage|string)
        local raw = self.__raw;
        raw.inputImage = if type(newinput)~="string" then newinput::EditableImage else AssetService:CreateEditableImageAsync(newinput::string);
        self:SetFrame(raw.currentFrame);
    end
end

local ProxyMetaNewIndex = function(self:EditableSpriteInternal, i:string, v1:any)
    local raw = self.__raw;
    local v0 = raw[i];
    if (v0==v1) then return; end
    if (i=="isLooped" or i=="currentFrame" or i=="inputImage") then
        error(`Property {i} is read-only`);
    end
    raw[i] = v1;
    -- behavior
    if (i=="frameRate") then
        if (raw.isPlaying) then
            self:Pause(); self:Play();
        end
    elseif (i=="outputImage") then
        self:SetFrame(raw.currentFrame);
    elseif (i=="spriteSize") then
        raw.outputImage.Size = v1;
        if (raw.inputImage) then
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="columnCount" or i=="spriteCount" or i=="edgeOffset" or i=="spriteOffset") then
        if (self.inputImage) then
            self:SetFrame(self.currentFrame);
        end
    end
end

_export.new = function(props:EditableSpriteProps)
    local raw = {} :: EditableSpriteInternal;
    raw.inputImage = nil;
    raw.currentFrame = props.currentFrame or 1;
    raw.spriteSize = props.spriteSize or error("Sprite size must be provided");
    raw.spriteOffset = props.spriteOffset or Vector2.zero;
    raw.edgeOffset = props.edgeOffset or Vector2.zero;
    raw.spriteCount = props.spriteCount or 0;
    raw.columnCount = props.columnCount or 0;
    raw.frameRate = props.frameRate or 30;
    raw.isLooped = if props.isLooped ~= nil then props.isLooped else true;
    raw.isPlaying = false;
    raw.__raw = raw;
    setmetatable(raw, EditableSprite);

    raw.outputImage = Instance.new("EditableImage");
    raw.outputImage.Size = raw.spriteSize;
    
    local proxy = newproxy(true) :: EditableSprite;
    local meta = getmetatable(proxy);
    meta.__index = raw;
    meta.__newindex = ProxyMetaNewIndex;

    if (props.inputImage) then
        proxy:LoadInputImage(props.inputImage);
    end
    return proxy::EditableSprite;
end

return _export;