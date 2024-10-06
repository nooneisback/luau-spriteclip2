-- Example script for SpriteClip2

if (not require(script.Parent.config).IsDemoMode) then return end

local SpriteClip = require(script.Parent);
local scrgui = Instance.new("ScreenGui");
scrgui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui");

task.wait(2);

-- SimpleSprite example
task.spawn(function()
    local label = Instance.new("ImageLabel");
    label.Size = UDim2.fromOffset(200, 200);
    label.Position = UDim2.fromOffset(0, 0);
    label.BackgroundTransparency = 1;
    label.Parent = scrgui;

    local sprite = SpriteClip.SimpleSprite.new({
        adornee = label;
        spriteSheetId = "rbxassetid://104239803996382";
        spriteSize = Vector2.new(150,150);
        spriteCount = 12;
        columnCount = 6;
        frameRate = 3;
        isLooped = true;
    });
    sprite:Play();
end);

-- EditableSprite example
task.spawn(function()
    local label = Instance.new("ImageLabel");
    label.Size = UDim2.fromOffset(200, 200);
    label.Position = UDim2.fromOffset(200, 0);
    label.BackgroundTransparency = 1;
    label.Parent = scrgui;

    local sprite = SpriteClip.EditableSprite.new({
        inputImage = "rbxassetid://104239803996382";
        spriteSize = Vector2.new(150,150);
        spriteCount = 12;
        columnCount = 6;
        frameRate = 3;
        isLooped = true;
    });
    sprite.outputImage.Parent = label;
    sprite:Play();
end);

-- ScriptedSimpleSprite example
task.spawn(function()
    local label = Instance.new("ImageLabel");
    label.Size = UDim2.fromOffset(200, 200);
    label.Position = UDim2.fromOffset(400, 0);
    label.BackgroundTransparency = 1;
    label.Parent = scrgui;

    local currentFrame = 1;
    local spriteCount = 12;
    local columnCount = 6;
    local sprite = SpriteClip.ScriptedSimpleSprite.new({
        adornee = label;
        spriteSheetId = "rbxassetid://104239803996382";
        spriteSize = Vector2.new(150,150);
        frameRate = 3;
    });
    sprite.onRenderCallback = function(self)
        local ix = (currentFrame-1) % columnCount + 1;
        local iy = math.floor((currentFrame-1) / columnCount) + 1;
        self:SetFrame(Vector2.new(ix, iy));
        currentFrame += 1;
        if (currentFrame > spriteCount) then
            currentFrame = 1;
        end
    end
    sprite:Play();
end);

-- ScriptedEditableSprite example
task.spawn(function()
    local label = Instance.new("ImageLabel");
    label.Size = UDim2.fromOffset(200, 200);
    label.Position = UDim2.fromOffset(600, 0);
    label.BackgroundTransparency = 1;
    label.Parent = scrgui;

    local currentFrame = 1;
    local spriteCount = 12;
    local columnCount = 6;
    local sprite = SpriteClip.ScriptedEditableSprite.new({
        inputImage = "rbxassetid://104239803996382";
        spriteSize = Vector2.new(150,150);
        frameRate = 3;
    });
    sprite.onRenderCallback = function(self)
        local ix = (currentFrame-1) % columnCount + 1;
        local iy = math.floor((currentFrame-1) / columnCount) + 1;
        self:SetFrame(Vector2.new(ix, iy));
        currentFrame += 1;
        if (currentFrame > spriteCount) then
            currentFrame = 1;
        end
    end
    sprite.outputImage.Parent = label;
    sprite:Play();
end);

-- CompatibilitySprite example
task.spawn(function()
    local label = Instance.new("ImageLabel");
    label.Size = UDim2.fromOffset(200, 200);
    label.Position = UDim2.fromOffset(800, 0);
    label.BackgroundTransparency = 1;
    label.Parent = scrgui;

    local sprite = SpriteClip.CompatibilitySprite.new();
    label.Image = "rbxassetid://104239803996382";
    sprite.InheritSpriteSheet = true;
    sprite.SpriteSizePixel = Vector2.new(150,150);
    sprite.SpriteCount = 12;
    sprite.SpriteCountX = 6;
    sprite.FrameRate = 3;
    sprite.Looped = true;
    sprite.Adornee = label;

    sprite:Play();
end);