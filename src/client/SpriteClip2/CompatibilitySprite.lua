--@native

-- The main sprite type
export type CompatibilitySprite = {
        -- properties
        Adornee				:Instance?;
        SpriteSheet			:string?;
        InheritSpriteSheet	:true;
        CurrentFrame		:number;
        SpriteSizePixel		:Vector2;
        SpriteOffsetPixel	:Vector2;
        EdgeOffsetPixel 	:Vector2;
        SpriteCount  		:number;
        SpriteCountX  		:number;
        FrameRate  			:number;
        FrameTime           :number;
        Looped  			:boolean;
        State				:boolean;
        -- methods
		Play:(self:CompatibilitySprite)->(boolean);
		Pause:(self:CompatibilitySprite)->(boolean);
		Stop:(self:CompatibilitySprite)->(boolean);
		Advance:(self:CompatibilitySprite, advanceby:number)->();
		Destroy:(self:CompatibilitySprite)->();
        Clone:(self:CompatibilitySprite)->(CompatibilitySprite);
}

-- Don't touch anything below unless you know what you're doing
local _export = {} :: {new:()->(CompatibilitySprite)};

-- Internal type with hidden values
local ImageSprite = require(script.Parent.ImageSprite);
export type CompatibilitySpriteInternal = {
    __raw:CompatibilitySpriteInternal;
    __real:ImageSprite.ImageSpriteInternal;
} & CompatibilitySprite;

local CompatibilitySprite = {}; do
    CompatibilitySprite.__tostring = function() return "CompatibilitySprite"; end
    CompatibilitySprite.__index = CompatibilitySprite;
    function CompatibilitySprite.Play(self:CompatibilitySpriteInternal)
        local real = self.__real;
        return real:Play();
    end
    function CompatibilitySprite.Pause(self:CompatibilitySpriteInternal)
        local real = self.__real;
        return real:Pause();
    end
    function CompatibilitySprite.Stop(self:CompatibilitySpriteInternal)
        local real = self.__real;
        return real:Stop();
    end
    function CompatibilitySprite.Advance(self:CompatibilitySpriteInternal, advanceby:number?)
        local real = self.__real;
        for _=1,advanceby or 1 do
            real:Advance();
        end
    end
    function CompatibilitySprite.Destroy(self:CompatibilitySpriteInternal)
        local real = self.__real;
        if (real.isPlaying) then
            real:Pause();
        end
        real.adornee = nil;
    end
    function CompatibilitySprite.Clone(self:CompatibilitySpriteInternal)
        local sprite1 = _export.new();
        sprite1.SpriteSheet = self.SpriteSheet;
        sprite1.InheritSpriteSheet = self.InheritSpriteSheet;
        sprite1.CurrentFrame = self.CurrentFrame;
        sprite1.SpriteSizePixel = self.SpriteSizePixel;
        sprite1.EdgeOffsetPixel = self.EdgeOffsetPixel;
        sprite1.SpriteCount = self.SpriteCount;
        sprite1.SpriteCountX = self.SpriteCountX;
        sprite1.FrameRate = self.FrameRate;
        sprite1.Looped = self.Looped;
        return sprite1;
    end
end

local Remap = {
    Adornee				= "adornee";
    CurrentFrame		= "currentFrame";
    SpriteSizePixel		= "spriteSize";
    SpriteOffsetPixel	= "spriteOffset";
    EdgeOffsetPixel 	= "edgeOffset";
    SpriteCount  		= "spriteCount";
    SpriteCountX  		= "columnCount";
    FrameRate  			= "frameRate";
    Looped  			= "isLooped";
    State				= "isPlaying";
}

local ProxyMetaNewIndex = function(self:CompatibilitySpriteInternal, i0:string, v1:any)
    local i = Remap[i0];
    local real = self.__real;
    if (i) then
        if (i=="currentFrame") then
            real:SetFrame(v1);
        elseif (i=="adornee") then
            if (self.InheritSpriteSheet) then
                self.SpriteSheet = v1.Image;
            end
            real[i] = v1;
        else
            real[i] = v1;
        end
    else
        i = i0;
        if (i=="SpriteSheet") then
            real.spriteSheetId = v1 or "";
        elseif (i=="FrameTime") then
            real.frameRate = math.round(1/v1);
        else
            self.__raw[i] = v1;
        end
    end
end

_export.new = function()
    local realsprite = ImageSprite.new({
        adornee = nil;
        spriteSheetId = nil;
        currentFrame = 1;
        spriteSize = Vector2.new(100,100);
        spriteOffset = Vector2.zero;
        edgeOffset = Vector2.zero;
        spriteCount = 25;
        columnCount = 5;
        frameRate = 15;
        isLooped = true;
    });

    local raw = {} :: CompatibilitySpriteInternal;
    raw.InheritSpriteSheet = true;
    raw.__real = realsprite;
    raw.__raw = raw;
    setmetatable(raw, CompatibilitySprite);
    
    local proxy = newproxy(true);
    local meta = getmetatable(proxy);
    meta.__tostring = function() return "CompatibilitySprite"; end
    meta.__newindex = ProxyMetaNewIndex;
    meta.__index = function(self:CompatibilitySpriteInternal, i0:string)
        local real = raw.__real;
        local i = Remap[i0];
        if (i) then
            return real[i];
        else
            i = i0;
            if (i=="SpriteSheet") then
                local v = real.spriteSheetId;
                return if v=="" then nil else v;
            elseif (i=="FrameTime") then
                return 1 / real.frameRate;
            else
                return raw[i];
            end
        end
    end

    return proxy::CompatibilitySprite;
end

return _export;