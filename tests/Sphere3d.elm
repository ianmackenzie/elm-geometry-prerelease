module Sphere3d exposing (..)

import Expect exposing (FloatingPointTolerance(Absolute, AbsoluteOrRelative))
import Fuzz
import Generic
import OpenSolid.Arc3d as Arc3d
import OpenSolid.Axis3d as Axis3d
import OpenSolid.BoundingBox3d as BoundingBox3d
import OpenSolid.Direction3d as Direction3d
import OpenSolid.Geometry.Decode as Decode
import OpenSolid.Geometry.Encode as Encode
import OpenSolid.Geometry.Expect as Expect
import OpenSolid.Geometry.Fuzz exposing (arc3d, axis3d, plane3d, point3d, scalar, sphere3d, vector3d)
import OpenSolid.Plane3d as Plane3d
import OpenSolid.Point3d as Point3d
import OpenSolid.Sphere3d as Sphere3d exposing (Sphere3d)
import OpenSolid.Triangle3d as Triangle3d
import OpenSolid.Vector3d as Vector3d
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, fuzz4, test)


{-
   Helper methods
-}


sphereFromTuple : ( ( Float, Float, Float ), Float ) -> Sphere3d
sphereFromTuple ( centerPoint, radius ) =
    Sphere3d.with { centerPoint = Point3d.fromCoordinates centerPoint, radius = radius }



{-
   Tests
-}


jsonRoundTrips : Test
jsonRoundTrips =
    Generic.jsonRoundTrips sphere3d
        Encode.sphere3d
        Decode.sphere3d


unit : Test
unit =
    describe "unit"
        [ test "The sphere returned by unit has radius 1" <|
            \_ ->
                Sphere3d.unit
                    |> Sphere3d.radius
                    |> Expect.equal 1
        , test "The sphere returned by unit is centered on the origin" <|
            \_ ->
                Sphere3d.unit
                    |> Sphere3d.centerPoint
                    |> Expect.equal Point3d.origin
        ]


with : Test
with =
    describe "with"
        [ fuzz2 point3d
            scalar
            "A sphere's radius gets set correctly"
            (\centerPoint radius ->
                let
                    sphere =
                        Sphere3d.with { centerPoint = centerPoint, radius = radius }
                in
                Sphere3d.radius sphere
                    |> Expect.equal (abs radius)
            )
        , fuzz2 point3d
            scalar
            "A sphere's center points gets set correctly"
            (\centerPoint radius ->
                let
                    sphere =
                        Sphere3d.with { centerPoint = centerPoint, radius = radius }
                in
                Sphere3d.centerPoint sphere
                    |> Expect.equal centerPoint
            )
        ]


throughPointsManual : Test
throughPointsManual =
    let
        testCases =
            [ ( ( ( 1, 0, 0 ), ( 0, 1, 0 ), ( -1, 0, 0 ), ( 0, 0, 1 ) )
              , ( ( 0, 0, 0 ), 1 )
              )
            , ( ( ( 1, 0, 0 ), ( 0, 1, 0 ), ( -1, 0, 0 ), ( 0, 0, -1 ) )
              , ( ( 0, 0, 0 ), 1 )
              )
            , ( ( ( 1, 0, 0 ), ( 0, 1, 0 ), ( -1, 0, 0 ), ( 0, 0, 0.5 ) )
              , ( ( 0, 0, -0.75 ), 1.25 )
              )
            , ( ( ( 1, 0, 0 ), ( 0, 1, 0 ), ( -1, 0, 0 ), ( 0, 0, -0.5 ) )
              , ( ( 0, 0, 0.75 ), 1.25 )
              )
            ]

        input ( p1, p2, p3, p4 ) =
            ( Point3d.fromCoordinates p1
            , Point3d.fromCoordinates p2
            , Point3d.fromCoordinates p3
            , Point3d.fromCoordinates p4
            )

        testTitle inputPoints expectedSphere =
            "Given " ++ toString (input inputPoints) ++ " throughPoints returns " ++ toString (sphereFromTuple expectedSphere)
    in
    describe "throughPoints" <|
        List.map
            (\( inputPoints, expectedSphere ) ->
                test
                    (testTitle inputPoints expectedSphere)
                    (\_ ->
                        Sphere3d.throughPoints (input inputPoints)
                            |> Maybe.map (Expect.equal (sphereFromTuple expectedSphere))
                            |> Maybe.withDefault (Expect.fail "throughPoints returned Nothing on valid input")
                    )
            )
            testCases


throughPointsFuzz : Test
throughPointsFuzz =
    fuzz4 point3d
        point3d
        point3d
        point3d
        "All given points lie on the sphere constructed using `throughPoints`"
        (\p1 p2 p3 p4 ->
            let
                {- If the first three of the four points are collinear no circle
                       (and by extension no sphere) can be constructed going through them.
                   If the fourth point is in the same plane as the three other points it is also
                       not possible to construct a sphere going through them (it would need to have a height of zero).
                   ==> volume of the tetrahedron formed by the four points needs to be greater than zero
                -}
                isValidInput =
                    let
                        v2 =
                            Vector3d.from p1 p2

                        v3 =
                            Vector3d.from p1 p3

                        v4 =
                            Vector3d.from p1 p4

                        volume =
                            abs (Vector3d.dotProduct v4 (Vector3d.crossProduct v2 v3))
                    in
                    volume > 1.0e-6

                sphere =
                    Sphere3d.throughPoints ( p1, p2, p3, p4 )

                hasPointOnSurface point sphere =
                    Point3d.distanceFrom point (Sphere3d.centerPoint sphere)
                        |> Expect.approximately (Sphere3d.radius sphere)
            in
            case sphere of
                Just sphere ->
                    sphere
                        |> Expect.all
                            [ hasPointOnSurface p1
                            , hasPointOnSurface p2
                            , hasPointOnSurface p3
                            , hasPointOnSurface p4
                            ]

                Nothing ->
                    if isValidInput then
                        Expect.fail "throughPoints returned Nothing on valid input"
                    else
                        Expect.pass
        )


properties : Test
properties =
    fuzz sphere3d
        "A sphere has the correct properties (diameter, circumference, surfaceArea, volume)"
        (\sphere ->
            let
                r =
                    Sphere3d.radius sphere
            in
            sphere
                |> Expect.all
                    [ Sphere3d.diameter >> Expect.equal (2 * r)
                    , Sphere3d.circumference >> Expect.equal (2 * pi * r)
                    , Sphere3d.surfaceArea >> Expect.equal (4 * pi * r * r)
                    , Sphere3d.volume >> Expect.equal (4 / 3 * pi * r * r * r)
                    ]
        )


scaleAbout : Test
scaleAbout =
    describe "scaleAbout"
        [ test
            "scaleAbout correctly scales a specific sphere"
            (\_ ->
                let
                    scale =
                        0.5

                    aboutPoint =
                        Point3d.fromCoordinates ( 1, 0, 0 )

                    originalCenter =
                        Point3d.fromCoordinates ( 1, 2, 0 )

                    scaledCenter =
                        Point3d.fromCoordinates ( 1, 1, 0 )

                    originalRadius =
                        2

                    scaledRadius =
                        1
                in
                Sphere3d.with { centerPoint = originalCenter, radius = originalRadius }
                    |> Sphere3d.scaleAbout aboutPoint scale
                    |> Expect.sphere3d
                        (Sphere3d.with { centerPoint = scaledCenter, radius = scaledRadius })
            )
        , fuzz2 point3d
            sphere3d
            "scaling by 1 has no effect on the sphere"
            (\point sphere ->
                sphere
                    |> Sphere3d.scaleAbout point 1
                    |> Expect.sphere3d sphere
            )
        , fuzz3 point3d
            (Fuzz.intRange 2 10)
            sphere3d
            "scaling and unscaling has no effect on the sphere"
            (\point scale sphere ->
                sphere
                    |> Sphere3d.scaleAbout point (toFloat scale)
                    |> Sphere3d.scaleAbout point (1 / toFloat scale)
                    |> Expect.sphere3d sphere
            )
        , fuzz3 point3d
            scalar
            sphere3d
            "scaling changes the radius and distance to the scaling point"
            (\point scale sphere ->
                let
                    originalRadius =
                        Sphere3d.radius sphere

                    originalDistance =
                        Sphere3d.centerPoint sphere
                            |> Point3d.distanceFrom point
                in
                sphere
                    |> Sphere3d.scaleAbout point scale
                    |> Expect.all
                        [ Sphere3d.radius
                            >> Expect.approximately (originalRadius * abs scale)
                        , Sphere3d.centerPoint
                            >> Point3d.distanceFrom point
                            >> Expect.approximately (originalDistance * abs scale)
                        ]
            )
        ]


rotateAround : Test
rotateAround =
    describe "rotateAround"
        [ test
            "correctly rotates a specific sphere"
            (\_ ->
                let
                    axis =
                        Axis3d.z

                    -- 90 degrees
                    angle =
                        pi / 2

                    originalCenter =
                        Point3d.fromCoordinates ( 2, 0, 0 )

                    rotatedCenter =
                        Point3d.fromCoordinates ( 0, 2, 0 )

                    radius =
                        2
                in
                Sphere3d.with { centerPoint = originalCenter, radius = radius }
                    |> Sphere3d.rotateAround axis angle
                    |> Expect.sphere3d
                        (Sphere3d.with { centerPoint = rotatedCenter, radius = radius })
            )
        , fuzz3 axis3d
            scalar
            sphere3d
            "roating a sphere doesn't change its radius and its distance from the rotation axis"
            (\axis angle sphere ->
                let
                    originalDistance =
                        sphere
                            |> Sphere3d.centerPoint
                            |> Point3d.distanceFromAxis axis
                in
                sphere
                    |> Sphere3d.rotateAround axis angle
                    |> Expect.all
                        [ Sphere3d.radius
                            >> Expect.approximately (Sphere3d.radius sphere)
                        , Sphere3d.centerPoint
                            >> Point3d.distanceFromAxis axis
                            >> Expect.approximately originalDistance
                        ]
            )
        , fuzz3 axis3d
            (Fuzz.floatRange 0 pi)
            sphere3d
            "rotates by the correct angle"
            (\axis angle sphere ->
                let
                    {- find the direction of the vector connecting the axis with `point`
                       that is orthogonal to the axis.
                       can return `Nothing` if `point` is already on the `axis`
                       (could happen when the fuzzer accidentally creates them like that)
                    -}
                    orthogonalDirectionFromAxisTo point =
                        point
                            |> Point3d.projectOntoAxis axis
                            |> Direction3d.from point

                    originalDirection =
                        orthogonalDirectionFromAxisTo (Sphere3d.centerPoint sphere)

                    rotatedDirection =
                        sphere
                            |> Sphere3d.rotateAround axis angle
                            |> Sphere3d.centerPoint
                            |> orthogonalDirectionFromAxisTo
                in
                case ( originalDirection, rotatedDirection ) of
                    ( Just originalDirection, Just rotatedDirection ) ->
                        let
                            angleBetweenDirections =
                                Direction3d.angleFrom originalDirection rotatedDirection
                        in
                        angleBetweenDirections
                            |> Expect.approximately angle

                    _ ->
                        Expect.pass
            )
        , fuzz2 axis3d
            sphere3d
            "rotating by 2 pi doesn't change the sphere"
            (\axis sphere ->
                sphere
                    |> Sphere3d.rotateAround axis (2 * pi)
                    |> Expect.sphere3d sphere
            )
        , fuzz3 axis3d
            scalar
            sphere3d
            "rotating and unrotating doesn't change the sphere"
            (\axis angle sphere ->
                sphere
                    |> Sphere3d.rotateAround axis angle
                    |> Sphere3d.rotateAround axis -angle
                    |> Expect.sphere3d sphere
            )
        ]


translateBy : Test
translateBy =
    fuzz2 vector3d
        sphere3d
        "A sphere gets translated correctly"
        (\displacement sphere ->
            sphere
                |> Sphere3d.translateBy displacement
                |> Expect.all
                    [ Sphere3d.radius >> Expect.equal (Sphere3d.radius sphere)
                    , Sphere3d.centerPoint >> Expect.equal (Point3d.translateBy displacement (Sphere3d.centerPoint sphere))
                    ]
        )


mirrorAcross : Test
mirrorAcross =
    fuzz2 plane3d
        sphere3d
        "A sphere gets mirrored across a plane correctly"
        (\plane sphere ->
            sphere
                |> Sphere3d.mirrorAcross plane
                |> Expect.all
                    [ Sphere3d.radius >> Expect.equal (Sphere3d.radius sphere)
                    , Sphere3d.centerPoint >> Expect.equal (Point3d.mirrorAcross plane (Sphere3d.centerPoint sphere))
                    ]
        )


boundingBoxContainsCenter : Test
boundingBoxContainsCenter =
    fuzz sphere3d
        "A sphere's bounding box contains its center point"
        (\sphere ->
            let
                boundingBox =
                    Sphere3d.boundingBox sphere

                centerPoint =
                    Sphere3d.centerPoint sphere
            in
            Expect.true
                "Circle bounding box does not contain the center point"
                (BoundingBox3d.contains centerPoint boundingBox)
        )
