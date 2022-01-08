# Tag
[Tag]: #user-content-tag

The Tag module enables the creation of instanceable symbol-like values.

There are 3 types of tags: [static][StaticTag], [class][ClassTag] and
[instance][InstanceTag].

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Tag][Tag]
	1. [Tag.class][Tag.class]
	2. [Tag.static][Tag.static]
	3. [Tag.typeof][Tag.typeof]
2. [ClassTag][ClassTag]
	1. [ClassTag.Has][ClassTag.Has]
	2. [ClassTag.Kind][ClassTag.Kind]
	3. [ClassTag.__call][ClassTag.__call]
3. [InstanceTag][InstanceTag]
	1. [InstanceTag.IsA][InstanceTag.IsA]
	2. [InstanceTag.Key][InstanceTag.Key]
	3. [InstanceTag.Kind][InstanceTag.Kind]
4. [StaticTag][StaticTag]
	1. [StaticTag.Kind][StaticTag.Kind]

</td></tr></tbody>
</table>

## Tag.class
[Tag.class]: #user-content-tagclass
```
Tag.class(kind: string): ClassTag
```

The **class** constructor returns a [class tag][ClassTag] with *kind* as
the kind. *kind* must not contain null characters.

## Tag.static
[Tag.static]: #user-content-tagstatic
```
Tag.static(kind: string): StaticTag
```

The **static** constructor returns a [static tag][StaticTag] with *kind*
as the kind. *kind* must not contain null characters.

## Tag.typeof
[Tag.typeof]: #user-content-tagtypeof
```
Tag.typeof(value: any): string?
```

The **typeof** function returns the type of the value as a string, or
nil if the value is not known by the module. Known types are
[StaticTag][StaticTag], [ClassTag][ClassTag], and [InstanceTag][InstanceTag].

# ClassTag
[ClassTag]: #user-content-classtag

The **ClassTag** type is a tag of which
[instances][InstanceTag] can be [created][ClassTag.__call].

## ClassTag.Has
[ClassTag.Has]: #user-content-classtaghas
```
ClassTag:Has(): string
```

The **Has** method returns whether *tag* is an instance of the tag.

## ClassTag.Kind
[ClassTag.Kind]: #user-content-classtagkind
```
ClassTag:Kind(): string
```

The **Kind** method returns the kind of the tag.

## ClassTag.__call
[ClassTag.__call]: #user-content-classtag__call
```
ClassTag(key: string): InstanceTag
```

Calling a ClassTag returns an [instance][InstanceTag] of the tag with
*key* as the key.

# InstanceTag
[InstanceTag]: #user-content-instancetag

The **InstanceTag** type is a tag that is the instance of a [class
tag][ClassTag].

## InstanceTag.IsA
[InstanceTag.IsA]: #user-content-instancetagisa
```
InstanceTag:IsA(): string
```

The **IsA** method returns whether the tag is an instance of *tag*.

## InstanceTag.Key
[InstanceTag.Key]: #user-content-instancetagkey
```
InstanceTag:Key(): string
```

The **Key** method returns the key of the instance.

## InstanceTag.Kind
[InstanceTag.Kind]: #user-content-instancetagkind
```
InstanceTag:Kind(): string
```

The **Kind** method returns the kind of the tag.

# StaticTag
[StaticTag]: #user-content-statictag

The **StaticTag** type is a tag with only a kind.

## StaticTag.Kind
[StaticTag.Kind]: #user-content-statictagkind
```
StaticTag:Kind(): string
```

The **Kind** method returns the kind of the tag.

