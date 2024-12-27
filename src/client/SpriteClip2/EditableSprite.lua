--@native

local assetService = game:GetService("AssetService")

-- The main sprite type
export type EditableSprite = {
    -- properties
    inputImage:         EditableImage?; -- READONLY [nil] editable image to read the pixel data from, change using LoadInputImage
    outputImage:        EditableImage;  -- [nil] editable image to write the pixel data to, can be replaced with a different editable image
    outputPosition:     Vector2;        -- [0,0] where to render on the output image, useful for storing multiple sprites as an atlas
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
    Advance:(self:EditableSprite)->();                                          -- manually advances to the next frame, or 1 if last
    LoadInputImage: (self:EditableSprite, newInput:EditableImage|string)->();   -- ASYNC if given a string, replaces the input image with a new one
    GetSignal:(self:EditableSprite, signalType:SignalType)->(RBXScriptSignal);
};

-- format: "signalName" | -- (callback arguments) - description
type SignalType =
    "FrameLast" |   -- () - fires when the sprite hits its last frame
    "Looped" |      -- () - fires when a looped sprite goes from its last to first frame
    "FrameChanged" |-- () - fires on frame change
    "PlayCalled" |  -- () - fires when :Play() is called if the sprite isn't playing
    "PauseCalled" | -- () - fires when :Pause() is called if the sprite is playing
    "StopCalled" |  -- () - fires when :Stop() is called if the sprite is playing
    "StaticChanged" -- (propName:string) - fires when a static property has changed, such as: such as: inputImage, outputImage, outputPosition, spriteSize, spriteOffset, edgeOffset, spriteCount, columnCount, frameRate, isLooped

-- Properties parsed to Sprite.new(props), most are optional (aka. can be nil)
export type EditableSpriteProps = {
    inputImage:         EditableImage|string?;
    outputImage:        EditableImage?;
    outputPosition:     Vector2?;
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
    __signalcache:{[string]:BindableEvent};
} & EditableSprite;

local EditableSprite = {}; do
    EditableSprite.__index = EditableSprite;
    EditableSprite.__tostring = function() return "EditableSprite"; end
    function EditableSprite.Play(self:EditableSpriteInternal, playFrom:number?)
        local raw = self.__raw;
        if (raw.isPlaying) then return false; end
        if (playFrom) then self:SetFrame(playFrom); end
        raw.isPlaying = true;
        raw.__playcon = Scheduler:GetOnRenderSignal(raw.frameRate):Connect(function()
            self:Advance();
        end);
        local _ev = self.__signalcache["PlayCalled"]; _ = _ev and _ev:Fire();
        return true;
    end
    function EditableSprite.Pause(self:EditableSpriteInternal, stopcall:boolean?)
        local raw = self.__raw;
        if (not raw.isPlaying) then return false; end
        raw.isPlaying = false;
        (raw.__playcon::RBXScriptConnection):Disconnect();
        local _ev = not stopcall and self.__signalcache["PauseCalled"]; _ = _ev and _ev:Fire();
        return true;
    end
    function EditableSprite.Stop(self:EditableSpriteInternal)
        self:SetFrame(1);
        local didPause = (self::any).Pause(self, true); -- don't question it, I just don't want to deal with typechecking
        local _ev = didPause and self.__signalcache["StopCalled"]; _ = _ev and _ev:Fire();
        return didPause;
    end
    function EditableSprite.Advance(self:EditableSpriteInternal)
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
        local _ev = nextframe==1 and raw.__signalcache["Looped"]; _ = _ev and _ev:Fire();
    end

    function EditableSprite.SetFrame(self:EditableSpriteInternal, newframe:number)
        local raw = self.__raw;
        if (newframe<1 or newframe>raw.spriteCount) then
            error("Invalid frame number "..newframe);
        end
        local oldFrame = raw.currentFrame;
        raw.currentFrame = newframe;
        local input = raw.inputImage :: EditableImage;
        if (not input) then return; end
        local col = raw.columnCount;
        local ix = (newframe-1) % col;
        local iy = math.floor((newframe-1) / col);
        local size = raw.spriteSize;
        local offedge = raw.edgeOffset;
        local offsprt = raw.spriteOffset;
        local posx = offedge.X + ix*(size.X + offsprt.X);
        local posy = offedge.Y + iy*(size.Y + offsprt.Y);
        self.outputImage:WritePixelsBuffer(raw.outputPosition, size, input:ReadPixelsBuffer(Vector2.new(posx,posy), size));
        local _ev;
        _ev = oldFrame ~= newframe and raw.__signalcache["FrameChanged"]; _ = _ev and _ev:Fire();
        _ev = newframe == raw.spriteCount and raw.__signalcache["FrameLast"]; _ = _ev and _ev:Fire();
    end

    function EditableSprite.LoadInputImage(self:EditableSpriteInternal, newinput:EditableImage|string)
        local raw = self.__raw;
        raw.inputImage = if type(newinput)~="string" then newinput::EditableImage else AssetService:CreateEditableImageAsync(newinput::string);
        self:SetFrame(raw.currentFrame);
    end

    -- create a signalType:bool hash to quickly check if the requested signalType is valid
    local validSignalTypes = {"FrameLast","Looped","FrameChanged","PlayCalled","PauseCalled","StopCalled","StaticChanged"};
    for _,i in pairs(validSignalTypes) do
        validSignalTypes[i]=true;
    end

    function EditableSprite.GetSignal(self, signalType)
        local evcache = (self::EditableSpriteInternal).__signalcache;
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
    elseif (i=="outputImage" or i=="outputPosition") then
        self:SetFrame(raw.currentFrame);
    elseif (i=="spriteSize") then
        raw.outputImage.Size = v1;
        if (raw.inputImage) then
            self:SetFrame(raw.currentFrame);
        end
    elseif (i=="columnCount" or i=="spriteCount" or i=="edgeOffset" or i=="spriteOffset") then
        if (raw.inputImage) then
            self:SetFrame(raw.currentFrame);
        end
    end
    local _ev = raw.__signalcache["StaticChanged"]; _ = _ev and _ev:Fire(i);
end

--local config = require(script.Parent.config);
_export.new = function(props:EditableSpriteProps)

    local raw = {} :: EditableSpriteInternal;
    raw.inputImage = nil;
    raw.outputImage = props.outputImage;
    raw.outputPosition = props.outputPosition or Vector2.zero;
    raw.currentFrame = props.currentFrame or 1;
    raw.spriteSize = props.spriteSize or error("Sprite size must be provided");
    raw.spriteOffset = props.spriteOffset or Vector2.zero;
    raw.edgeOffset = props.edgeOffset or Vector2.zero;
    raw.spriteCount = props.spriteCount or 0;
    raw.columnCount = props.columnCount or 0;
    raw.frameRate = props.frameRate or 30;
    raw.isLooped = if props.isLooped ~= nil then props.isLooped else true;
    raw.isPlaying = false;
    raw.__signalcache = {};
    raw.__raw = raw;
    setmetatable(raw, EditableSprite);

    if (not raw.outputImage) then
        raw.outputImage = assetService:CreateEditableImage({
            Size = raw.spriteSize
        })
    end
    
    local proxy = newproxy(true) :: EditableSprite;
    local meta = getmetatable(proxy);
    meta.__tostring = function() return "EditableSprite"; end
    meta.__index = raw;
    meta.__newindex = ProxyMetaNewIndex;

    if (props.inputImage) then
        proxy:LoadInputImage(props.inputImage);
    end
    return proxy::EditableSprite;
end

return _export;