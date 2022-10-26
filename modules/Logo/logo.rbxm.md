# logo.rbxm format
This document describes the format of production logo files, as interpreted by
the Logo module. By convention, such files have the `.logo.rbxm` extension.

The base format is RBXM, which encodes a model as a tree of instances. This
document describes the structure of the instances contained within the model.

# Capabilities
A logo driver is configured with a set of "capabilities", which determine what
facilities are provided in order to render a logo. The driver will render logos
within the constraints of these capabilities. A well-designed logo is able to
render for every combination of capability.

The following capabilities are specified:

Capability | Implies | Description
-----------|---------|------------
TwoD       |         | Use of 2D environment is allowed.
ThreeD     |         | Use of 3D environment is allowed.
Lighting   | ThreeD  | Use of Lighting is allowed.
Terrain    | ThreeD  | Use of Terrain is allowed.
Sound      |         | Use of sounds is allowed.
Scripting  |         | Use of scripts is allowed.

# Model
Each instance in the root of the model indicates the [root][root] of a logo.
That is, a single model file may contain more than one logo.

## Root
[root]: #root

The root of a logo must be a Configuration instance. The following members are
significant:

Member         | Kind      | Type      | Description
---------------|-----------|-----------|------------
Name           | Property  | `string`  | Identifies the logo.
PrefadeTime    | Attribute | `number?` | Preferred margin of time before the fade-in section.
FadeInTime     | Attribute | `number?` | Preferred time of the fade-in section.
DisplayTime    | Attribute | `number?` | Preferred display time of the logo.
FadeOutTime    | Attribute | `number?` | Preferred time of fade-out section.
PostfadeTime   | Attribute | `number?` | Preferred margin of time after fade-out section.
MinDisplayTime | Attribute | `number?` | Preferred minimum time the logo is displayed before skipping is allowed.

If a timing attribute is unspecified, then the driver's configured timing is
used instead.

The children of the root form the content of the logo. An instance is
interpreted depending on its name and class. This interpretation includes how
the children of the instance are traversed.

An instance tree may be "sanitized" to remove instances that would be unsafe for
the working copy of the logo. When sanitizing, the following alterations are
made:

- BaseScript instances are excluded.

Any descendant Sound instance within the root causes the **Sound** capability to
be requested.

### Folders
Folder instances are traversed recursively, such that their children are
considered in the same way as the root.

### Configurations
Certain instances of the Configuration class are significant, depending on their
name. The attributes of such instances are used to configure the properties of a
corresponding instance. There are several rules for configuring:

- An enum property is represented by a string attribute, where the string is the
  name of the enum item.
- A CFrame property is represented by two Vector3 attributes. For example,
  property `PROP` is represented by the following attributes:
	- `PROP_Position`: The position component of the CFrame.
	- `PROP_Orientation`: The orientation component of the CFrame.

#### Camera

- **Requests the ThreeD capability.**

The first Configuration instance named "Camera" configures the 3D camera.
Sanitized descendants are added to the camera.

*A Configuration must be used instead of a Camera instance, because Camera
instances do not replicate to clients.*

#### Lighting

- **Requests the Lighting capability.**

The first Configuration instance named "Lighting" configures the Lighting
service. Sanitized descendants are added to the Lighting.

#### Terrain

- **Requests the Terrain capability.**

The first Configuration instance named "Terrain" configures the Terrain
service. Sanitized descendants are added to the Terrain.

The instance may contain descendant TerrainRegion instances. For each
TerrainRegion, the following members are significant:

Member          | Kind      | Type      | Description
----------------|-----------|-----------|------------
Name            | Property  | `string`  | Identifies the logo.
Corner          | Attribute | `Vector3` | The location of the lower corner of the terrain region.
PasteEmptyCells | Attribute | `boolean` | Whether empty cells should be included.

When the logo is loaded, each of these regions are pasted to the Terrain as
configured.

#### SoundService

- **Requests the Sound capability.**

The first Configuration instance named "SoundService" configures the SoundService
service. Sanitized descendants are added to the SoundService.

### PVInstances

- **Requests the ThreeD capability.**

Instances inheriting the PVInstance class represent 3D objects that are added to
the 3D environment. Descendants are sanitized.

### GuiObjects

- **Requests the TwoD capability.**

Instances inheriting the GuiObject class represent 2D objects that are added to
the 2D environment. Descendants are sanitized.

### Sounds

- **Requests the Sound capability.**

Orphan Sound instances (not included in a 2D or 3D object) are added to the
driver's configured sound renderer. Sounds with their Playing property set to
true will begin playing immediately when the logo is presented.

Such sounds must be unique by their Name property. That is, only the first sound
per Name is considered. This allows them to be identified more easily by
scripts.

### Main script

- **Requests the Scripting capability.**

The first ModuleScript instance named "Main" defines the entrypoint for
scripting the logo.

The main module may contain descendant ModuleScript instances that can be
required as normal. Note that only ModuleScripts are allowed. Non-ModuleScripts
are converted to Folders, and branches that do not contain ModuleScripts are
removed.

The following types are defined for use by scripts:

```
-- Device must be returned by the main module.
--
-- The device is called concurrently with the presentation of the logo, and may
-- yield.
--
-- A device must not have persisting side-effects. A device may only modify
-- instances that are provided by *driver*, and must not spawn threads that live
-- beyond the presentation of the logo.
type Device = (driver: Driver) -> ()

-- Driver contains the state of a presented logo.
type Driver = {
	-- Lists the capabilities provided by the driver.
	Capabilities: Options,

	-- The color of the blanker.
	BlankColor: Color3,

	-- The root of the 2D environment. Contains the 2D objects defined in the
	-- logo. Will be nil if TwoD is not enabled.
	Env2D: GuiObject?,

	-- The root of the 3D environment. Contains the 3D objects defined in the
	-- logo. Will be nil if ThreeD is not enabled.
	Env3D: Model?,

	-- A camera usable for the 3D environment. Will be nil if ThreeD is not
	-- enabled.
	Camera: Camera?,

	-- The Lighting service for the 3D environment. Will be nil if
	-- ThreeD or Lighting is not enabled.
	Lighting: Lighting?,

	-- The Terrain service for the 3D environment. Will be nil if ThreeD or
	-- Terrain is not enabled.
	Terrain: Terrain?,

	-- The SoundService service for sound. Will be nil if Sound is not enabled.
	SoundService: SoundService?,

	-- Describes the time lengths of each presentation section.
	Timing: Timing,

	-- Sets a callback to be called on every render frame of the logo. Setting
	-- *callback* to nil unsets the callback.
	OnStepped: (self: Driver, callback: FrameCallback?) -> (),
}

-- Timing describes timing lengths of each presentation section.
type Timing = {
	-- The amount of time of the fade-in section.
	FadeIn: number,

	-- The amount of time of the non-skippable portion of the display section.
	Nonskippable: number,

	-- The amount of time of the skippable portion of the display section.
	Skippable: number,

	-- The amount of time of the fade-out section.
	FadeOut: number,
}

-- FrameCallback is called during the presentation of a logo. *state* indicates
-- the current state of the presentation.
--
-- If false is returned, then the driver will cancel the presentation and move
-- immediately to the next logo (defaults to true).
type FrameCallback = (driver: Driver, state: State) -> (boolean?)

-- State provides information about a frame of a presentation.
type State = {
	-- The name of the current section.
	Section: Section,

	-- The amount of time elapsed since the start of the current section.
	SectionProgress: number,

	-- The amount of time elapsed since the start of the presentation.
	OverallProgress: number,

	-- The amount of time since the previous frame.
	DeltaTime: number,

	-- The time when the logo was skipped, since the start of the Skippable
	-- section. Will be nil during unskippable sections, if the logo has not
	-- been skipped, or if skipping is disabled.
	SkipTime: number?,
}

-- Section indicates a particular duration of time during the presentation of a
-- logo.
type Section =
	-- When the blanker is transitioning to the logo.
	"FadeIn" |

	-- The unskippable portion of the logo display.
	"Unskippable" |

	-- The skippable portion of the logo display. The logo can
	-- only be skipped after this section has been entered. If the logo is
	-- skipped, then the presentation will switch immediately to the FadeOut
	-- section.
	"Skippable" |

	-- When the logo is transitioning to the blanker.
	"FadeOut" |

	-- Emitted only once, to signal the end of the presentation.
	"Postfade"

```
