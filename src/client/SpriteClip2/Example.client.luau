-- Example script for SpriteClip2

if (not require(script.Parent.config).IsDemoMode) then return end

local SpriteClip = require(script.Parent);
local scrgui = Instance.new("ScreenGui");
scrgui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui");

task.wait(2);

-- sync all sprite.new() functions to call Play at the same time
local numsync = 0;
local syncfunc;
do
    local bindsync = Instance.new("BindableEvent");
    function syncfunc()
        numsync-=1;
        bindsync:Fire();
        while (numsync~=0) do
            bindsync.Event:Wait();
        end
    end
end

-- ImageSprite example
task.spawn(function()
    numsync+=1;

    local label = Instance.new("ImageLabel");
    label.Size = UDim2.fromOffset(200, 200);
    label.Position = UDim2.fromOffset(0, 0);
    label.BackgroundTransparency = 1;
    label.Parent = scrgui;

    local sprite = SpriteClip.ImageSprite.new({
        adornee = label;
        spriteSheetId = "rbxassetid://104239803996382";
        spriteSize = Vector2.new(150,150);
        spriteCount = 12;
        columnCount = 6;
        frameRate = 3;
        isLooped = true;
    });

    syncfunc();
    sprite:Play();
end);

-- EditableSprite example
task.spawn(function()
    numsync+=1;

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
    
    syncfunc();
    sprite:Play();
end);

-- ScriptedImageSprite example
task.spawn(function()
    numsync+=1;

    local label = Instance.new("ImageLabel");
    label.Size = UDim2.fromOffset(200, 200);
    label.Position = UDim2.fromOffset(400, 0);
    label.BackgroundTransparency = 1;
    label.Parent = scrgui;

    local currentFrame = 1;
    local spriteCount = 12;
    local columnCount = 6;
    local sprite = SpriteClip.ScriptedImageSprite.new({
        adornee = label;
        spriteSheetId = "rbxassetid://104239803996382";
        spriteSize = Vector2.new(150,150);
        frameRate = 3;
    });
    sprite.onRenderCallback = function(self)
        currentFrame += 1;
        if (currentFrame > spriteCount) then
            currentFrame = 1;
        end
        local ix = (currentFrame-1) % columnCount + 1;
        local iy = math.floor((currentFrame-1) / columnCount) + 1;
        self:SetFrame(Vector2.new(ix, iy));
    end
    
    syncfunc();
    sprite:Play();
end);

-- ScriptedEditableSprite example
task.spawn(function()
    numsync+=1;

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
        currentFrame += 1;
        if (currentFrame > spriteCount) then
            currentFrame = 1;
        end
        local ix = (currentFrame-1) % columnCount + 1;
        local iy = math.floor((currentFrame-1) / columnCount) + 1;
        self:SetFrame(Vector2.new(ix, iy));
        
    end
    sprite.outputImage.Parent = label;

    syncfunc();
    sprite:Play();
end);

-- CompatibilitySprite example
task.spawn(function()
    numsync+=1;

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

    syncfunc();
    sprite:Play();
end);

local preRenderSignal = SpriteClip.Scheduler:GetPreRenderSignal(3);
local onRenderSignal = SpriteClip.Scheduler:GetOnRenderSignal(3);
local postRenderSignal = SpriteClip.Scheduler:GetPostRenderSignal(3);
preRenderSignal:Connect(function()
    print("pre");
end);
onRenderSignal:Connect(function()
    print("on");
end);
postRenderSignal:Connect(function()
    print("post");
end);