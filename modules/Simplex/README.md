# Simplex
[Simplex]: #user-content-simplex

Simplex noise algorithm in Lua.

- [Original Java implementation by Stefan Gustavson][java]
- [Paper][paper]

[java]: https://weber.itn.liu.se/~stegu/simplexnoise/SimplexNoise.java
[paper]: https://staffwww.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Simplex][Simplex]
	1. [Simplex.new][Simplex.new]
2. [Generator][Generator]
	1. [Generator.Noise2D][Generator.Noise2D]
	2. [Generator.Noise3D][Generator.Noise3D]
	3. [Generator.Noise4D][Generator.Noise4D]

</td></tr></tbody>
</table>

## Simplex.new
[Simplex.new]: #user-content-simplexnew
```
Simplex.new(permutations: {[number]: number} | number | Random | (number)->(number)): Generator
```

Returns a generator initialized with a table of permutations.

*permutations* may be an array containing each integer between 0 and 255,
inclusive. The order of these integers can be arbitrary.

*permutations* may be a number, which is used as a random seed to shuffle a
generated table of permutations.

*permutations* may be a Random object, which will be used to shuffle a
generated table of permutations.

*permutations* may be a function that receives an integer, and returns an
integer between 1 and the given value, inclusive. In this case, a generated
table of permutations will be shuffled using this function. math.random is an
example of such a function.

Otherwise, a shuffled table of permutations is generated from a random
source.

# Generator
[Generator]: #user-content-generator
```
type Generator
```

Generator holds the state for generating simplex noise.

## Generator.Noise2D
[Generator.Noise2D]: #user-content-generatornoise2d
```
Generator:Noise2D(x: number, y: number): number
```

Returns a number in the interval [-1, 1] based on the given
two-dimensional coordinates and the generator's permutation state.

## Generator.Noise3D
[Generator.Noise3D]: #user-content-generatornoise3d
```
Generator:Noise3D(x: number, y: number, z: number): number
```

Returns a number in the interval [-1, 1] based on the given
three-dimensional coordinates and the generator's permutation state.

## Generator.Noise4D
[Generator.Noise4D]: #user-content-generatornoise4d
```
Generator:Noise4D(x: number, y: number, z: number, w: number): number
```

Returns a number in the interval [-1, 1] based on the given
four-dimensional coordinates and the generator's permutation state.

