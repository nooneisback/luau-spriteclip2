
local _export = {};
local AssetService = game:GetService("AssetService");

--[[
    Allows creation of sprite sheets bigger than 1024x1024 by
    stitching them together into an editable image
    Places them on top of each other and doesn't check their sizes
]]
function _export.CreateCompoundSpriteSheet(...:string|EditableImage)
    local outputImage = Instance.new("EditableImage");
    for _, inputImage in ipairs({...}) do
        local editImage:EditableImage = if type(inputImage)=="string" then AssetService:CreateEditableImageAsync(inputImage) else inputImage;
        local posy = outputImage.Size.Y;
        outputImage.Size = Vector2.new(
            math.max(editImage.Size.X, outputImage.Size.X),
            outputImage.Size.Y + editImage.Size.Y
        );
        outputImage:WritePixels(
            Vector2.new(0,posy), editImage.Size, editImage:ReadPixels(Vector2.zero, editImage.Size));
    end
    return outputImage;
end

return _export;