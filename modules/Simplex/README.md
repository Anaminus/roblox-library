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
	1. [Simplex.fromArray][Simplex.fromArray]
	2. [Simplex.fromFunction][Simplex.fromFunction]
	3. [Simplex.fromRandom][Simplex.fromRandom]
	4. [Simplex.fromSeed][Simplex.fromSeed]
	5. [Simplex.isGenerator][Simplex.isGenerator]
	6. [Simplex.new][Simplex.new]
2. [Generator][Generator]
	1. [Generator.Noise2D][Generator.Noise2D]
	2. [Generator.Noise3D][Generator.Noise3D]
	3. [Generator.Noise4D][Generator.Noise4D]

</td></tr></tbody>
</table>

## Simplex.fromArray
[Simplex.fromArray]: #user-content-simplexfromarray
```
Simplex.new(permutations: {number}): Generator
```

Returns a generator with a state initialized by a table of permutations.

*permutations* is an array containing some permutation of each integer
between 0 and 255, inclusive.

## Simplex.fromFunction
[Simplex.fromFunction]: #user-content-simplexfromfunction
```
Simplex.new(func: (number)->(number)): Generator
```

Returns a generator with a state initialized by a random function.

*func* is a function that receives an integer, and returns an integer between
1 and the given value, inclusive. A generated array of permutations will be
shuffled using this function. `math.random` is an example of such a function.

## Simplex.fromRandom
[Simplex.fromRandom]: #user-content-simplexfromrandom
```
Simplex.new(source: Random): Generator
```

Returns a generator with a state initialized by a Random source.

*source* is a Random value, which is used to shuffle a generated array of
permutations.

## Simplex.fromSeed
[Simplex.fromSeed]: #user-content-simplexfromseed
```
Simplex.new(seed: number): Generator
```

Returns a generator with a state initialized by a seed for a random
number generator.

*seed* is a number, which is used as a random seed to shuffle a generated
array of permutations.

## Simplex.isGenerator
[Simplex.isGenerator]: #user-content-simplexisgenerator
```
Simplex.isGenerator(v: any): boolean
```

isGenerator returns whether *v* is an instance of
[Generator][Generator].

## Simplex.new
[Simplex.new]: #user-content-simplexnew
```
Simplex.new(): Generator
```

Returns a generator with a state initialized by a random shuffle.

# Generator
[Generator]: #user-content-generator
```
type Generator
```

Generator holds the state for generating simplex noise. The state is
based off of an array containing a permutation of integers.

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

