# Logo
[Logo]: #logo

The Logo module facilitates the display of production logos when a
client joins. The user can create a driver that configures the timing and
allowed capabilities of logos, such as 2D, 3D, lighting, and sound.

Logos themselves are files in a specific format. See
[logo.rbxm](logo.rbxm.md) for a specification of this format.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Logo][Logo]
	1. [Logo.new][Logo.new]
2. [Device][Device]
3. [Driver][Driver]
4. [DriverConfig][DriverConfig]
5. [FrameCallback][FrameCallback]
6. [Monitor][Monitor]
	1. [Monitor.Cancel][Monitor.Cancel]
	2. [Monitor.ContentQueue][Monitor.ContentQueue]
	3. [Monitor.Finish][Monitor.Finish]
	4. [Monitor.Wait][Monitor.Wait]
7. [Options][Options]
8. [Root][Root]
9. [Section][Section]
10. [Sequence][Sequence]
	1. [Sequence.Options][Sequence.Options]
	2. [Sequence.Run][Sequence.Run]
11. [State][State]
12. [Timing][Timing]

</td></tr></tbody>
</table>

## Logo.new
[Logo.new]: #logonew
```
function Logo.new(...: Root): Sequence
```

The **new** constructor returns a [Sequence][Sequence] from a list of
logo [Roots][Root].

# Device
[Device]: #device
```
type Device = (driver: Driver) -> ()
```

A Device receives a [Driver][Driver] to alter the content of a logo. It
is expected to be returned by the main module of a logo.

The device is called concurrently with the presentation of the logo, and may
yield.

A device must not have persisting side-effects. A device may only modify
instances that are provided by *driver*, and must not spawn threads that live
beyond the presentation of the logo.

# Driver
[Driver]: #driver
```
type Driver = {
	-- Lists the capabilities provided by the driver.
	Capabilities: Options,

	-- The color of the blanker.
	BlankColor: Color3,

	-- The root of the 2D environment. Contains the 2D objects defined in
	-- the logo. Will be nil if TwoD is not enabled.
	Env2D: GuiObject?,

	-- The root of the 3D environment. Contains the 3D objects defined in
	-- the logo. Will be nil if ThreeD is not enabled.
	Env3D: Model?,

	-- A camera usable for the 3D environment. Will be nil if ThreeD is not
	-- enabled.
	Camera: Camera?,

	-- The Lighting service for the 3D environment. Will be nil if ThreeD
	-- or Lighting is not enabled.
	Lighting: Lighting?,

	-- The Terrain service for the 3D environment. Will be nil if ThreeD or
	-- Terrain is not enabled.
	Terrain: Terrain?,

	-- The SoundService service for sound. Will be nil if Sound is not
	-- enabled.
	SoundService: SoundService?,

	-- Describes the time lengths of each presentation section.
	Timing: Timing,

	-- Sets a callback to be called on every render frame of the logo.
	-- Setting *callback* to nil unsets the callback.
	OnStepped: (self: Driver, callback: FrameCallback?) -> (),
}
```

Driver contains the state of a presented logo.

# DriverConfig
[DriverConfig]: #driverconfig
```
type DriverConfig = {
	-- Sets the capabilities of the driver.
	Capabilities: Options?,

	-- Specifies the allowed range for each logo's PrefadeTime.
	PrefadeTimeRange: NumberRange?,

	-- Specifies the allowed range for each logo's FadeInTime.
	FadeInTimeRange: NumberRange?,

	-- Specifies the allowed range for each logo's UnskippableTime.
	UnskippableTimeRange: number?,

	-- Specifies the allowed range for each logo's SkippableTime.
	SkippableTimeRange: number?,

	-- Specifies the allowed range for each logo's FadeOutTime.
	FadeOutTimeRange: NumberRange?,

	-- Specifies the allowed range for each logo's PostfadeTime.
	PostfadeTimeRange: NumberRange?,

	-- Allow logo to override configured timings.
	OverrideTimes: boolean?,

	-- Default time for prefade section.
	PrefadeTime: number?,

	-- Default time for fade-in section.
	FadeInTime: number?,

	-- Default time for unskippable display section.
	UnskippableTime: number?,

	-- Default time for skippable display section.
	SkippableTime: number?,

	-- Default time for fade-out section.
	FadeOutTime: number?,

	-- Default time for postfade section.
	PostfadeTime: number?,

	-- Queue used to preload content.
	ContentQueue: ContentQueue.Queue?,

	-- Whether logos can be skipped by the player. If false, then
	-- SkippableTime is merged into UnskippableTime.
	EnableSkipping: boolean?,

	-- The color of the blanker.
	BlankColor: Color3?,

	-- The origin of the 3D environment.
	OriginCFrame: CFrame?,

	-- Container for 2D rendering. Defaults to local PlayerGui.
	TwoDRenderer: Instance?,

	-- Container for 3D rendering. Defaults to Workspace.
	ThreeDRenderer: Instance?,

	-- Container for sound rendering. Defaults to SoundService.
	SoundRenderer: Instance?,
}
```

Configures a [Driver][Driver].

# FrameCallback
[FrameCallback]: #framecallback
```
type FrameCallback = (driver: Driver, state: State) -> boolean?
```

FrameCallback is called during the presentation of a logo. *state*
indicates the current state of the presentation.

If false is returned, then the driver will cancel the presentation and move
immediately to the next logo (defaults to true).

# Monitor
[Monitor]: #monitor
```
type Monitor
```

Monitor manages the progress of a running [Sequence][Sequence].

## Monitor.Cancel
[Monitor.Cancel]: #monitorcancel
```
function Monitor:Cancel()
```

The **Cancel** method causes the sequence to stop immediately.
Returns immediately if the sequence is finished or cancelled.

## Monitor.ContentQueue
[Monitor.ContentQueue]: #monitorcontentqueue
```
function Monitor:ContentQueue(): ContentQueue.Queue
```

The **ContentQueue** method returns the queue used by the driver to
load assets. Content added to the queue will begin preloading after any
logo content. The monitor will wait until the queue is empty before
finishing.

## Monitor.Finish
[Monitor.Finish]: #monitorfinish
```
function Monitor:Finish(time: number?)
```

The **Finish** method finalizes the rendering of the Sequence by
fading the blanker out to reveal whatever is displayed behind it. *time*
is the duration of the fade-in effect, defaulting to the FadeInTime of
the driver configuration.

Finish will block before fading the blanker until the Sequence is
finished or cancelled.

## Monitor.Wait
[Monitor.Wait]: #monitorwait
```
function Monitor:Wait()
```

The **Wait** method blocks until the Sequence has finished
presenting each logo, and the underlying ContentQueue is empty. Returns
immediately if the sequence is finished or cancelled.

# Options
[Options]: #options
```
type Options = {
	-- True if driver has 2D environment, or if logo contains 2D objects.
	TwoD: boolean,

	-- True if driver has 3D environment, or if logo contains 3D objects.
	ThreeD: boolean,

	-- True if driver allows lighting config, or if logo contains lighting data.
	-- Implies ThreeD.
	Lighting: boolean,

	-- True if driver allows terrain config, or if logo contains terrain data.
	-- Implies ThreeD.
	Terrain: boolean,

	-- True if driver allows scripting, or if logo contains a Main module.
	Scripting: boolean,

	-- True if driver allows sounds, or if logo contains objects for sound.
	Sound: boolean,
}
```

Options describes the required capabilities of a driver, or available
capabilities of a logo.

# Root
[Root]: #root
```
type Root = Instance
```

**Root** is an instance that contains objects comprising a logo. A
[logo.rbxm](logo.rbxm.md) file may contain one or more Roots.

# Section
[Section]: #section
```
type Section = string
```

Section indicates a particular duration of time during the presentation
of a logo.

- `FadeIn`: When the blanker is transitioning to the logo.
- `Unskippable`: The unskippable portion of the logo display.
- `Skippable`: The skippable portion of the logo display. The logo can only
  be skipped after this section has been entered. If the logo is skipped,
  then the presentation will switch immediately to the FadeOut section.
- `FadeOut`: When the logo is transitioning to the blanker.
- `Postfade`:mitted only once, to signal the end of the presentation.

# Sequence
[Sequence]: #sequence
```
type Sequence
```

**Sequence** is an ordered sequence of logos constructed from one or more
[Roots][Root].

## Sequence.Options
[Sequence.Options]: #sequenceoptions
```
function Sequence:Options(id: string?): Options?
```

The **Options** method lists capabilities requested by logo *id*. If
*id* is nil, then returns the logical disjunction of each capability for
all logos. Returns nil if *id* is not a valid logo.

## Sequence.Run
[Sequence.Run]: #sequencerun
```
function Sequence:Run(config: DriverConfig): Monitor
```

The **Run** method begins the logo sequence by preloading content
and presenting each logo according to the given configuration.

# State
[State]: #state
```
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
```

State provides information about a frame of a presentation.

# Timing
[Timing]: #timing
```
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
```

Timing describes timing lengths of each presentation section.

