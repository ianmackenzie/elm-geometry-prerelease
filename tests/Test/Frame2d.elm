{- This Source Code Form is subject to the terms of the Mozilla Public License,
   v. 2.0. If a copy of the MPL was not distributed with this file, you can
   obtain one at http://mozilla.org/MPL/2.0/.

   Copyright 2016 by Ian Mackenzie
   ian.e.mackenzie@gmail.com
-}


module Test.Frame2d exposing (suite)

import Json.Decode as Decode exposing (decodeValue)
import Json.Encode as Encode
import ElmTest exposing (Test)
import Check exposing (Claim, claim, true, that, is, for, quickCheck)
import Check.Test exposing (evidenceToTest)
import Check.Producer as Producer
import OpenSolid.Core.Types exposing (..)
import OpenSolid.Core.Decode as Decode
import OpenSolid.Core.Encode as Encode
import OpenSolid.Point2d as Point2d
import Test.Utils exposing (pointsAreEqual2d)
import Test.Producers exposing (frame2d, point2d)


jsonRoundTrips : Claim
jsonRoundTrips =
    claim "JSON conversion round-trips properly"
        `that` (Encode.frame2d >> decodeValue Decode.frame2d)
        `is` Ok
        `for` frame2d


coordinateTransformationRoundTrips : Claim
coordinateTransformationRoundTrips =
    let
        transformationRoundTrips ( frame, point ) =
            let
                roundTrip1 =
                    Point2d.toLocalIn frame >> Point2d.toGlobalFrom frame

                roundTrip2 =
                    Point2d.toGlobalFrom frame >> Point2d.toLocalIn frame
            in
                pointsAreEqual2d point (roundTrip1 point)
                    && pointsAreEqual2d point (roundTrip2 point)
    in
        claim "Local/global coordinate transformation round-trips properly"
            `true` transformationRoundTrips
            `for` Producer.tuple ( frame2d, point2d )


suite : Test
suite =
    ElmTest.suite "Frame2d tests"
        [ evidenceToTest (quickCheck jsonRoundTrips)
        ]