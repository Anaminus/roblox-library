# Tag
[Tag]: #user-content-tag

The Tag module enables the creation of instanceable symbol-like values.

There are 4 types of tags: [empty][EmptyTag], [static][StaticTag],
[class][ClassTag], and [instance][InstanceTag].

A tag can have multiple kinds. These kinds can be composed by adding or
subtracting tags from each other. There are several rules based on the types
of the operands:
- Adding EmptyTag with another tag returns the other tag.
    - `Tag + Empty == Tag`
    - `Empty + Tag == Tag`
- Adding StaticTags, ClassTags, and InstanceTags produces the union of the
  kinds of the tags. The type of the result will be the operand type with the
  highest priority (from highest to lowest): InstanceTag (also inherits the
  key), ClassTag, StaticTag.
- Adding two InstanceTags throws an error.
- Subtracting EmptyTag from a tag returns that tag.
    - `Tag - Empty == Tag`
- Subtracting a tag from EmptyTag returns EmptyTag.
    - `Empty - Tag == Empty`
- Subtracting StaticTags, ClassTags, and InstanceTags produces the complement
  of the kinds of the tags. The type of the result will the type of the left
  operand (the key is inherited for InstanceTags).
- If the complement of the two operands is the empty set, then EmptyTag is
  returned.
- Subtracting two InstanceTags throws an error.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Tag][Tag]
	1. [Tag.class][Tag.class]
	2. [Tag.empty][Tag.empty]
	3. [Tag.static][Tag.static]
	4. [Tag.typeof][Tag.typeof]
2. [ClassTag][ClassTag]
	1. [ClassTag.Has][ClassTag.Has]
	2. [ClassTag.Is][ClassTag.Is]
	3. [ClassTag.__call][ClassTag.__call]
3. [EmptyTag][EmptyTag]
	1. [EmptyTag.Has][EmptyTag.Has]
	2. [EmptyTag.Is][EmptyTag.Is]
4. [InstanceTag][InstanceTag]
	1. [InstanceTag.Has][InstanceTag.Has]
	2. [InstanceTag.Is][InstanceTag.Is]
	3. [InstanceTag.Key][InstanceTag.Key]
5. [StaticTag][StaticTag]
	1. [StaticTag.Has][StaticTag.Has]
	2. [StaticTag.Is][StaticTag.Is]

</td></tr></tbody>
</table>

## Tag.class
[Tag.class]: #user-content-tagclass
```
Tag.class(kind: string): ClassTag
```

The **class** constructor returns a [class tag][ClassTag] with *kind* as
the kind. *kind* must not contain null characters.

## Tag.empty
[Tag.empty]: #user-content-tagempty
```
Tag.empty: EmptyTag
```

The **empty** constant contains the [empty tag][EmptyTag].

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
[EmptyTag][EmptyTag], [StaticTag][StaticTag], [ClassTag][ClassTag], and
[InstanceTag][InstanceTag].

# ClassTag
[ClassTag]: #user-content-classtag

The **ClassTag** type is a tag of which
[instances][InstanceTag] can be [created][ClassTag.__call].

## ClassTag.Has
[ClassTag.Has]: #user-content-classtaghas
```
ClassTag:Has(tag: Tag): boolean
```

The **Has** method returns true if the tag has any kind from *tag*.

## ClassTag.Is
[ClassTag.Is]: #user-content-classtagis
```
ClassTag:Is(tag: Tag): boolean
```

The **Is** method returns true if the tag is all kinds from *tag*.

## ClassTag.__call
[ClassTag.__call]: #user-content-classtag__call
```
ClassTag(key: string): InstanceTag
```

Calling a ClassTag returns an [instance][InstanceTag] of the tag with
*key* as the key.

# EmptyTag
[EmptyTag]: #user-content-emptytag

The **EmptyTag** type is the tag with no kind. It is returned by
operations that produce the empty set of kinds.

## EmptyTag.Has
[EmptyTag.Has]: #user-content-emptytaghas
```
EmptyTag:Has(tag: Tag): boolean
```

The **Has** method returns true only if *tag* is EmptyTag.

## EmptyTag.Is
[EmptyTag.Is]: #user-content-emptytagis
```
EmptyTag:Is(tag: Tag): boolean
```

The **Is** method returns true only if *tag* is EmptyTag.

# InstanceTag
[InstanceTag]: #user-content-instancetag

The **InstanceTag** type is a tag that is the instance of a [class
tag][ClassTag]. Instances have a "key", which is an arbitrary string.

## InstanceTag.Has
[InstanceTag.Has]: #user-content-instancetaghas
```
InstanceTag:Has(tag: Tag): boolean
```

The **Has** method returns true if the tag has any kind from *tag*.

## InstanceTag.Is
[InstanceTag.Is]: #user-content-instancetagis
```
InstanceTag:Is(tag: Tag): boolean
```

The **Is** method returns true if the tag has all kinds from *tag*.

## InstanceTag.Key
[InstanceTag.Key]: #user-content-instancetagkey
```
InstanceTag:Key(): string
```

The **Key** method returns the key of the instance.

# StaticTag
[StaticTag]: #user-content-statictag

The **StaticTag** type is a tag that cannot be instanced.

## StaticTag.Has
[StaticTag.Has]: #user-content-statictaghas
```
StaticTag:Has(tag: Tag): boolean
```

The **Has** method returns true if the tag has any kind from *tag*.

## StaticTag.Is
[StaticTag.Is]: #user-content-statictagis
```
StaticTag:Is(tag: Tag): boolean
```

The **Is** method returns true if the tag has all kinds from *tag*.

