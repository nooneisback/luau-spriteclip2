local _export = {};

-- remove this to shut up the warning
warn("EditableImage API (EditableSprite and ScriptedEditableSprite) is currently only available in studio");

local Scheduler = require(script.Scheduler);
_export.Scheduler = Scheduler;

local SimpleSprite = require(script.SimpleSprite);
_export.SimpleSprite = SimpleSprite;
export type SimpleSprite = SimpleSprite.SimpleSprite;
export type SimpleSpriteProps = SimpleSprite.SimpleSpriteProps;

local EditableSprite = require(script.EditableSprite);
_export.EditableSprite = EditableSprite;
export type EditableSprite = EditableSprite.EditableSprite;
export type EditableSpriteProps = EditableSprite.EditableSpriteProps;

local ScriptedSimpleSprite = require(script.ScriptedSimpleSprite);
_export.ScriptedSimpleSprite = ScriptedSimpleSprite;
export type ScriptedSimpleSprite = ScriptedSimpleSprite.ScriptedSimpleSprite;
export type ScriptedSimpleSpriteProps = ScriptedSimpleSprite.ScriptedSimpleSpriteProps;

local ScriptedEditableSprite = require(script.ScriptedEditableSprite);
_export.ScriptedEditableSprite = ScriptedEditableSprite;
export type ScriptedEditableSprite = ScriptedEditableSprite.ScriptedEditableSprite;
export type ScriptedEditableSpriteProps = ScriptedEditableSprite.ScriptedEditableSpriteProps;

return _export;