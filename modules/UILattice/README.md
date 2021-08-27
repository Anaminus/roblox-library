# UILattice
[UILattice]: #user-content-uilattice

The UILattice module provides an implementation of the **Lattice
algorithm**. The Lattice algorithm converts a [flexbox][flexbox]-like grid
structure to a static set of UDim2 positions and sizes.

A grid is defined as a list of **spans** for each axis. A span is a numeric
value with either a constant or fractional unit:

- `px`: A constant size in UDim.Offset units (pixels). For example, `4px`
  indicates 4 pixels.
- `fr`: A fraction of the remaining non-constant span of the axis. The
  calculated fraction is the value divided by the sum of all fr units on the
  axis. So, if an axis contained `1fr`, `2fr`, `3fr`, and `1fr`, the total
  space would be 7 fractional units, and the `2fr` would take up 2/7 of the
  available fractional space.

The position and size of an object within the grid is defined in terms of its
**bounds**, or a rectangle of cells on the grid. For example, on a 3x3 grid,
the middle cell would have a bounds of ((1, 1), (2, 2)). If the bounds lies
partially outside the boundary of the grid, then the components are
constrained. If the bounds lies completely outside the grid, then the object
is not rendered (Visible is set to false).

The calculated positions and sizes of objects are static; the given bounds of
an object is reduced to a Position and Size UDim2, which makes resizing
inexpensive.

[flexbox]: https://en.wikipedia.org/wiki/Flexbox

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [UILattice][UILattice]
	1. [UILattice.update][UILattice.update]
	2. [UILattice.new][UILattice.new]
	3. [UILattice.bind][UILattice.bind]

</td></tr></tbody>
</table>

## UILattice.update
[UILattice.update]: #user-content-uilatticeupdate
```
function UILattice.update(parent: Instance): Instance
```

The update function uses the Lattice algorithm to update the child
GuiObjects of *parent*, using configured attributes.

On the parent, the following attributes are recognized:
- `UILatticeColumns: string`: A whitespace-separated list of spans that
  determines the span of each column. For example, `4px 1fr 4px`. If a
  non-string, defaults to "1fr".
- `UILatticeRows: string`: A whitespace-separated list of spans that
  determines the span of each row. For example, `4px 1fr 4px`. If a
  non-string, defaults to "1fr".
- `UILatticeConstraints: Rect`: If a Rect, specifies the minimum and maximum
  constraints of the *fractional space* for each axis. This is applied by
  configuring the first child of *parent* that is a UISizeConstraint, which
  will be created if not found.

On child GuiObjects, the following attributes are recognized:
- `UILatticeBounds: Rect | Vector2`: Sets the position and size of the child,
  in cell coordinates. If a Rect, specifies the lower and upper bounds. If a
  Vector2, specifies the position, while the size is set to 1 on both axes.
  Any other type causes Visible to be set to false.

## UILattice.new
[UILattice.new]: #user-content-uilatticenew
```
function UILattice.new(parent: Instance?): (parent: Instance, disconnect: () -> ())
```

The new constructor begins monitoring *parent* for changes, then
automatically updates according to [UILattice.update][UILattice.update]. If
*parent* is unspecified, then a Frame instance is created with reasonable
defaults.

*disconnect*, when called, causes monitoring to stop, and used resources to
be released.

## UILattice.bind
[UILattice.bind]: #user-content-uilatticebind
```
function UILattice.bind(tag: string?): () -> ()
```

The bind function begins monitoring the *tag* instance tag. While an
instance is tagged with *tag*, it behaves as though it were passed to
[UILattice.new][UILattice.new]. If unspecified, *tag* defaults to
"UILattice".

The returned function, when called, causes monitoring to stop, and unbinds
any bound instances.

