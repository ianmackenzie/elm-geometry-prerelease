{- This Source Code Form is subject to the terms of the Mozilla Public License,
   v. 2.0. If a copy of the MPL was not distributed with this file, you can
   obtain one at http://mozilla.org/MPL/2.0/.

   Copyright 2016 by Ian Mackenzie
   ian.e.mackenzie@gmail.com
-}


module OpenSolid.Direction3d
    exposing
        ( x
        , y
        , z
        , perpendicularTo
        , components
        , xComponent
        , yComponent
        , zComponent
        , vector
        , negate
        , times
        , dotProduct
        , crossProduct
        , angleFrom
        , rotateAround
        , mirrorAcross
        , projectOnto
        , relativeTo
        , placeIn
        , projectInto
        , placeOnto
        , encode
        , decoder
        )

{-| Various functions for creating and working with `Direction3d` values. For
the examples below, assume that all OpenSolid core types have been imported
using

    import OpenSolid.Types exposing (..)

and all necessary modules have been imported using the following pattern:

    import OpenSolid.Direction3d as Direction3d

Examples use `==` to indicate that two expressions are equivalent, even if (due
to numerical roundoff) they might not be exactly equal.

# Constants

@docs x, y, z

# Constructors

The simplest way to construct a `Direction3d` value is by passing a tuple of X,
Y and Z components to the `Direction3d` constructor, for example
`Direction3d (1, 0, 0 )`. However, if you do this you must ensure that the sum
of the squares of the given components is exactly one:

    Direction3d ( 1, 0, 0 )
    Direction3d ( 0, -1, 0 )
    Direction3d ( 0.6, 0, 0.8 )

are all valid but

    Direction3d ( 2, 0, 0 )
    Direction3d ( 1, 1, 1 )

are not.

@docs perpendicularTo

# Components

@docs components, xComponent, yComponent, zComponent

# Vector conversion

@docs vector

# Arithmetic

@docs negate, times, dotProduct, crossProduct

# Angle measurement

@docs angleFrom

# Transformations

@docs rotateAround, mirrorAcross, projectOnto

# Coordinate frames

Functions for transforming directions between local and global coordinates in
different coordinate frames. Like other transformations, coordinate
transformations of directions depend only on the orientations of the relevant
frames, not their positions.

For the examples, assume the following definition of a local coordinate frame,
one that is rotated 30 degrees counterclockwise about the Z axis from the global
XYZ frame:

    rotatedFrame =
        Frame3d.rotateAround Axis3d.z (degrees 30) Frame3d.xyz

    Frame3d.xDirection rotatedFrame ==
        Direction3d ( 0.866, 0.5, 0 )

    Frame3d.yDirection rotatedFrame ==
        Direction3d ( -0.5, 0.866, 0 )

    Frame3d.zDirection rotatedFrame ==
        Direction3d ( 0, 0, 1 )

@docs relativeTo, placeIn

# Sketch planes

@docs projectInto, placeOnto

# JSON serialization

@docs encode, decoder
-}

import Json.Encode as Encode exposing (Value)
import Json.Decode as Decode exposing (Decoder, (:=))
import OpenSolid.Types exposing (..)
import OpenSolid.Vector2d as Vector2d
import OpenSolid.Vector3d as Vector3d
import OpenSolid.Direction2d as Direction2d


toDirection : Vector3d -> Direction3d
toDirection (Vector3d components) =
    Direction3d components


{-| The positive X direction.

    Direction3d.x == Direction3d ( 1, 0, 0 )
-}
x : Direction3d
x =
    Direction3d ( 1, 0, 0 )


{-| The positive Y direction.

    Direction3d.y == Direction3d ( 0, 1, 0 )
-}
y : Direction3d
y =
    Direction3d ( 0, 1, 0 )


{-| The positive Z direction.

    Direction3d.z == Direction3d ( 0, 0, 1 )
-}
z : Direction3d
z =
    Direction3d ( 0, 0, 1 )


{-| Construct an arbitrary direction perpendicular to the given direction. The
exact resulting direction is not specified, but it is guaranteed to be
perpendicular to the given direction.

    Direction3d.perpendicularTo Direction3d.x ==
        Direction3d ( 0, 0, -1 )

    Direction3d.perpendicularTo Diretion3d.y ==
        Direction3d ( 1, 0, 0 )

    direction =
        Direction3d ( 0.6, 0, 0.8 )

    Direction3d.perpendicularTo direction ==
        Direction3d ( 0.8, 0, -0.6 )

-}
perpendicularTo : Direction3d -> Direction3d
perpendicularTo direction =
    let
        perpendicularVector =
            Vector3d.perpendicularTo (vector direction)

        length =
            Vector3d.length perpendicularVector

        normalizedVector =
            Vector3d.times (1 / length) perpendicularVector
    in
        Direction3d (Vector3d.components normalizedVector)


{-| Get the components of a direction as a tuple (the components it would have
as a unit vector, also know as its direction cosines).

    ( x, y, z ) =
        Direction3d.components direction
-}
components : Direction3d -> ( Float, Float, Float )
components (Direction3d components') =
    components'


{-| Get the X component of a direction.

    Direction3d.xComponent Direction3d.x == 1
    Direction3d.xComponent Direction3d.y == 0
-}
xComponent : Direction3d -> Float
xComponent (Direction3d ( x, _, _ )) =
    x


{-| Get the Y component of a direction.

    Direction3d.yComponent Direction3d.y == 1
    Direction3d.yComponent Direction3d.z == 0
-}
yComponent : Direction3d -> Float
yComponent (Direction3d ( _, y, _ )) =
    y


{-| Get the Z component of a direction.

    Direction3d.zComponent Direction3d.z == 1
    Direction3d.zComponent Direction3d.x == 0
-}
zComponent : Direction3d -> Float
zComponent (Direction3d ( _, _, z )) =
    z


{-| Convert a direction to a unit vector.

    Direction3d.vector Direction3d.y ==
        Vector3d ( 0, 1, 0 )
-}
vector : Direction3d -> Vector3d
vector (Direction3d components) =
    Vector3d components


{-| Reverse a direction.

    Direction3d.negate Direction3d.y ==
        Direction3d ( 0, -1, 0 )
-}
negate : Direction3d -> Direction3d
negate =
    vector >> Vector3d.negate >> toDirection


{-| Construct a vector from a magnitude and a direction. If the magnitude is
negative the resulting vector will be in the opposite of the given direction.

    Direction3d.times 3 Direction3d.z ==
        Vector3d ( 0, 0, 3 )

-}
times : Float -> Direction3d -> Vector3d
times scale =
    vector >> Vector3d.times scale


{-| Find the dot product of two directions. This is equal to the cosine of the
angle between them.

    direction =
        Direction3d ( 0.6, 0.8, 0 )

    Direction3d.dotProduct Direction2d.x direction == 0.6
    Direction3d.dotProduct Direction2d.z direction == 0
    Direction3d.dotProduct direction direction == 1

-}
dotProduct : Direction3d -> Direction3d -> Float
dotProduct firstDirection secondDirection =
    Vector3d.dotProduct (vector firstDirection) (vector secondDirection)


{-| Find the cross product of two directions. This is equal to the cross product
of the two directions converted to unit vectors.

    Direction3d.crossProduct Direction3d.x Direction3d.z ==
        Vector3d ( 0, -1, 0 )

    direction =
        Direction3d ( 0.6, 0.8, 0 )

    Direction3d.crossProduct Direction3d.x direction ==
        Vector3d ( 0, 0, 0.8 )

    Direction3d.crossProduct direction direction ==
        Vector3d.zero
-}
crossProduct : Direction3d -> Direction3d -> Vector3d
crossProduct firstDirection secondDirection =
    Vector3d.crossProduct (vector firstDirection) (vector secondDirection)


{-| Find the angle from one direction to another. The result will be in the
range 0 to π.

    Direction3d.angleFrom Direction3d.x Direction3d.x ==
        degrees 0 -- 0

    Direction3d.angleFrom Direction3d.x Direction3d.z ==
        degrees 90 -- pi / 2

    Direction3d.angleFrom Direction3d.y (Direction3d ( 0, -1, 0 )) ==
        degrees 180 -- pi
-}
angleFrom : Direction3d -> Direction3d -> Float
angleFrom other direction =
    acos (dotProduct direction other)


{-| Rotate a direction around an axis by a given angle.

    Direction3d.rotateAround Axis3d.x (degrees 90) Direction3d.y ==
        Direction3d.z

Note that only the direction of the axis affects the result, not the position of
its origin point, since directions are position-independent:

    offsetAxis =
        Axis3d
            { originPoint = Point3d ( 100, 200, 300 )
            , direction = Direction3d.z
            }

    Direction3d.rotateAround offsetAxis (degrees 90) Direction3d.x ==
        Direction3d.y

-}
rotateAround : Axis3d -> Float -> Direction3d -> Direction3d
rotateAround axis angle =
    vector >> Vector3d.rotateAround axis angle >> toDirection


{-| Mirror a direction across a plane.

    direction =
        Direction3d ( 0.6, 0, 0.8 )

    Direction3d.mirrorAcross Plane3d.xy direction ==
        Direction3d ( 0.6, 0, -0.8 )

Note that only the normal direction of the plane affects the result, not the
position of its origin point, since directions are position-independent:

    offsetPlane =
        Plane3d.offsetBy 10 Plane3d.yz

    Direction3d.mirrorAcross offsetPlane direction ==
        Direction3d ( -0.6, 0, 0.8 )
-}
mirrorAcross : Plane3d -> Direction3d -> Direction3d
mirrorAcross plane =
    vector >> Vector3d.mirrorAcross plane >> toDirection


{-| Project a direction onto a plane. This is effectively the direction of the
given direction's 'shadow' on the given plane. If the given direction is
exactly perpendicular to the given plane, then `Nothing` is returned.

    direction =
        Direction3d ( 0.6, -0.8, 0 )

    Direction3d.projectOnto Plane3d.xy direction ==
        Just (Direction3d ( 0.6, -0.8, 0 ))

    Direction3d.projectOnto Plane3d.xz direction ==
        Just (Direction3d ( 1, 0, 0 ))

    Direction3d.projectOnto Plane3d.yz direction ==
        Just (Direction3d ( 0, -1, 0 ))

    Direction3d.projectOnto Plane3d.xy Direction3d.z ==
        Nothing
-}
projectOnto : Plane3d -> Direction3d -> Maybe Direction3d
projectOnto plane =
    vector >> Vector3d.projectOnto plane >> Vector3d.direction


{-| Take a direction currently expressed in global coordinates and express it
relative to a given frame.

    Direction3d.relativeTo rotatedFrame Direction3d.x ==
        Direction3d ( 0.866, -0.5, 0 )

    Direction3d.relativeTo rotatedFrame Direction3d.y ==
        Direction3d ( 0.5, 0.866, 0 )

    Direction3d.relativeTo rotatedFrame Direction3d.z ==
        Direction3d ( 0, 0, 1 )
-}
relativeTo : Frame3d -> Direction3d -> Direction3d
relativeTo frame =
    vector >> Vector3d.relativeTo frame >> toDirection


{-| Place a direction in a given frame, considering it as being expressed
relative to that frame and returning the corresponding direction in global
coordinates. Inverse of `relativeTo`.

    Direction3d.placeIn rotatedFrame Direction3d.x ==
        Direction3d ( 0.866, 0.5, 0 )

    Direction3d.placeIn rotatedFrame Direction3d.y ==
        Direction2d ( -0.5, 0.866, 0 )

    Direction3d.placeIn rotatedFrame Direction3d.z ==
        Direction3d ( 0, 0, 1 )
-}
placeIn : Frame3d -> Direction3d -> Direction3d
placeIn frame =
    vector >> Vector3d.placeIn frame >> toDirection


{-| Project a direction into a given sketch plane. Conceptually, this projects
the direction onto the plane and then expresses the projected direction in 2D
sketch coordinates.

This is only possible if the direction is not perpendicular to the sketch
plane; if it is perpendicular, `Nothing` is returned.

    direction =
        Direction3d ( 0.6, -0.8, 0 )

    Direction3d.projectInto SketchPlane3d.xy direction ==
        Just (Direction2d ( 0.6, -0.8 ))

    Direction3d.projectInto SketchPlane3d.xz direction ==
        Just (Direction2d ( 1, 0 ))

    Direction3d.projectInto SketchPlane3d.yz direction ==
        Just (Direction2d ( -1, 0 ))

    Direction3d.projectInto SketchPlane3d.xy Direction3d.z ==
        Nothing
-}
projectInto : SketchPlane3d -> Direction3d -> Maybe Direction2d
projectInto sketchPlane =
    vector >> Vector3d.projectInto sketchPlane >> Vector2d.direction


{-| Take a direction defined in 2D coordinates within a particular sketch plane
and return the corresponding direction in 3D.

    direction =
        Direction2d ( 0.6, 0.8 )

    Direction2d.placeOnto SketchPlane3d.xy direction ==
        Direction3d ( 0.6, 0.8, 0 )

    Direction2d.placeOnto SketchPlane3d.yz direction ==
        Direction3d ( 0, 0.6, 0.8 )

    Direction2d.placeOnto SketchPlane3d.zx direction ==
        Direction3d ( 0.8, 0, 0.6 )
-}
placeOnto : SketchPlane3d -> Direction2d -> Direction3d
placeOnto sketchPlane =
    Direction2d.vector >> Vector3d.placeOnto sketchPlane >> toDirection


{-| Encode a Direction3d as a JSON object with 'x', 'y' and 'z' fields.
-}
encode : Direction3d -> Value
encode direction =
    Encode.object
        [ ( "x", Encode.float (xComponent direction) )
        , ( "y", Encode.float (yComponent direction) )
        , ( "z", Encode.float (zComponent direction) )
        ]


{-| Decoder for Direction3d values from JSON objects with 'x', 'y' and 'z'
fields.
-}
decoder : Decoder Direction3d
decoder =
    Decode.object3 (\x y z -> Direction3d ( x, y, z ))
        ("x" := Decode.float)
        ("y" := Decode.float)
        ("z" := Decode.float)