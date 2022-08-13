module Elm.Let exposing
    ( letIn
    , value, tuple, record
    , fn, fn2, fn3
    , toExpression
    )

{-|

@docs letIn

@docs value, tuple, record

@docs fn, fn2, fn3

@docs toExpression

-}

import Dict
import Elm exposing (Expression)
import Elm.Annotation
import Elm.Syntax.Expression as Exp
import Elm.Syntax.Node as Node
import Elm.Syntax.Pattern as Pattern
import Elm.Syntax.TypeAnnotation as Annotation
import Internal.Compiler as Compiler


{-| -}
type Let a
    = Let
        (Compiler.Index
         ->
            { letDecls : List (Node.Node Exp.LetDeclaration)
            , index : Compiler.Index
            , return : a
            }
        )


{-|

    Elm.Let.letIn
        (\one two ->
            Elm.Op.append one two
        )
        |> Elm.Let.value "one" (Elm.string "Hello")
        |> Elm.Let.value "two" (Elm.string "World!")
        |> Elm.Let.toExpression

Will translate into

    let
        one =
            "Hello!"

        two =
            "World"
    in
    one ++ two

-}
letIn : a -> Let a
letIn return =
    Let
        (\index ->
            { letDecls = []
            , index = index
            , return = return
            }
        )


with : Let a -> Let (a -> b) -> Let b
with (Let toScopeA) (Let toScopeAB) =
    Let
        (\index ->
            let
                resultA =
                    toScopeA index

                resultB =
                    toScopeAB resultA.index
            in
            { letDecls = resultA.letDecls ++ resultB.letDecls
            , index = resultB.index
            , return = resultB.return resultA.return
            }
        )


{-| -}
value : String -> Expression -> Let (Expression -> a) -> Let a
value desiredName valueExpr sourceLet =
    with
        (Let
            (\index ->
                let
                    ( name, secondIndex ) =
                        Compiler.getName desiredName index

                    ( finalIndex, details ) =
                        Compiler.toExpressionDetails secondIndex valueExpr
                in
                { letDecls =
                    [ case details.expression of
                        Exp.LambdaExpression lamb ->
                            Compiler.nodify <|
                                Exp.LetFunction
                                    { documentation = Nothing
                                    , signature = Nothing
                                    , declaration =
                                        Compiler.nodify
                                            { name = Compiler.nodify name
                                            , arguments =
                                                lamb.args
                                            , expression =
                                                lamb.expression
                                            }
                                    }

                        _ ->
                            Compiler.nodify <|
                                Exp.LetDestructuring
                                    (Compiler.nodify
                                        (Pattern.VarPattern name)
                                    )
                                    (Compiler.nodify details.expression)
                    ]
                , index = finalIndex
                , return =
                    Compiler.Expression
                        (\i ->
                            { details
                                | expression =
                                    Exp.FunctionOrValue []
                                        name
                            }
                        )
                }
            )
        )
        sourceLet


{-| -}
fn :
    String
    -> ( String, Maybe Elm.Annotation.Annotation )
    -> (Expression -> Expression)
    -> Let ((Expression -> Expression) -> a)
    -> Let a
fn desiredName ( desiredArg, argAnnotation ) toInnerFn sourceLet =
    with
        (Let
            (\index ->
                let
                    ( name, secondIndex ) =
                        Compiler.getName desiredName index

                    ( argName, thirdIndex ) =
                        Compiler.getName desiredArg secondIndex

                    arg =
                        Elm.value
                            { importFrom = []
                            , annotation = argAnnotation
                            , name = argName
                            }

                    ( finalIndex, innerFnDetails ) =
                        Compiler.toExpressionDetails thirdIndex
                            (toInnerFn arg)
                in
                { letDecls =
                    [ Compiler.nodify <|
                        Exp.LetFunction
                            { documentation = Nothing
                            , signature = Nothing
                            , declaration =
                                Compiler.nodify
                                    { name = Compiler.nodify name
                                    , arguments =
                                        [ Compiler.nodify
                                            (Pattern.VarPattern argName)
                                        ]
                                    , expression =
                                        Compiler.nodify innerFnDetails.expression
                                    }
                            }
                    ]
                , index = finalIndex
                , return =
                    \callerArg ->
                        Elm.apply
                            (Compiler.Expression
                                (\i ->
                                    { innerFnDetails
                                        | expression =
                                            Exp.FunctionOrValue []
                                                name
                                    }
                                )
                            )
                            [ callerArg
                            ]
                }
            )
        )
        sourceLet


{-| -}
fn2 :
    String
    -> ( String, Maybe Elm.Annotation.Annotation )
    -> ( String, Maybe Elm.Annotation.Annotation )
    -> (Expression -> Expression -> Expression)
    -> Let ((Expression -> Expression -> Expression) -> a)
    -> Let a
fn2 desiredName ( oneDesiredArg, oneType ) ( twoDesiredArg, twoType ) toInnerFn sourceLet =
    with
        (Let
            (\index ->
                let
                    ( name, secondIndex ) =
                        Compiler.getName desiredName index

                    ( oneName, thirdIndex ) =
                        Compiler.getName oneDesiredArg secondIndex

                    ( twoName, fourIndex ) =
                        Compiler.getName twoDesiredArg thirdIndex

                    one =
                        Elm.value
                            { importFrom = []
                            , annotation = oneType
                            , name = oneName
                            }

                    two =
                        Elm.value
                            { importFrom = []
                            , annotation = twoType
                            , name = twoName
                            }

                    ( finalIndex, innerFnDetails ) =
                        Compiler.toExpressionDetails fourIndex
                            (toInnerFn one two)
                in
                { letDecls =
                    [ Compiler.nodify <|
                        Exp.LetFunction
                            { documentation = Nothing
                            , signature = Nothing
                            , declaration =
                                Compiler.nodify
                                    { name = Compiler.nodify name
                                    , arguments =
                                        [ Compiler.nodify
                                            (Pattern.VarPattern oneName)
                                        , Compiler.nodify
                                            (Pattern.VarPattern twoName)
                                        ]
                                    , expression =
                                        Compiler.nodify innerFnDetails.expression
                                    }
                            }
                    ]
                , index = finalIndex
                , return =
                    \oneIncoming twoIncoming ->
                        Elm.apply
                            (Compiler.Expression
                                (\i ->
                                    { innerFnDetails
                                        | expression =
                                            Exp.FunctionOrValue []
                                                name
                                    }
                                )
                            )
                            [ oneIncoming
                            , twoIncoming
                            ]
                }
            )
        )
        sourceLet


{-| -}
fn3 :
    String
    -> ( String, Maybe Elm.Annotation.Annotation )
    -> ( String, Maybe Elm.Annotation.Annotation )
    -> ( String, Maybe Elm.Annotation.Annotation )
    -> (Expression -> Expression -> Expression -> Expression)
    -> Let ((Expression -> Expression -> Expression -> Expression) -> a)
    -> Let a
fn3 desiredName ( oneDesiredArg, oneType ) ( twoDesiredArg, twoType ) ( threeDesiredArg, threeType ) toInnerFn sourceLet =
    with
        (Let
            (\index ->
                let
                    ( name, secondIndex ) =
                        Compiler.getName desiredName index

                    ( oneName, thirdIndex ) =
                        Compiler.getName oneDesiredArg secondIndex

                    ( twoName, fourIndex ) =
                        Compiler.getName twoDesiredArg thirdIndex

                    ( threeName, fifthIndex ) =
                        Compiler.getName threeDesiredArg fourIndex

                    one =
                        Elm.value
                            { importFrom = []
                            , annotation = oneType
                            , name = oneName
                            }

                    two =
                        Elm.value
                            { importFrom = []
                            , annotation = twoType
                            , name = twoName
                            }

                    three =
                        Elm.value
                            { importFrom = []
                            , annotation = threeType
                            , name = threeName
                            }

                    ( finalIndex, innerFnDetails ) =
                        Compiler.toExpressionDetails fifthIndex
                            (toInnerFn one two three)
                in
                { letDecls =
                    [ Compiler.nodify <|
                        Exp.LetFunction
                            { documentation = Nothing
                            , signature = Nothing
                            , declaration =
                                Compiler.nodify
                                    { name = Compiler.nodify name
                                    , arguments =
                                        [ Compiler.nodify
                                            (Pattern.VarPattern oneName)
                                        , Compiler.nodify
                                            (Pattern.VarPattern twoName)
                                        , Compiler.nodify
                                            (Pattern.VarPattern threeName)
                                        ]
                                    , expression =
                                        Compiler.nodify innerFnDetails.expression
                                    }
                            }
                    ]
                , index = finalIndex
                , return =
                    \oneIncoming twoIncoming threeIncoming ->
                        Elm.apply
                            (Compiler.Expression
                                (\i ->
                                    { innerFnDetails
                                        | expression =
                                            Exp.FunctionOrValue []
                                                name
                                    }
                                )
                            )
                            [ oneIncoming
                            , twoIncoming
                            , threeIncoming
                            ]
                }
            )
        )
        sourceLet


{-| -}
tuple : String -> String -> Expression -> Let (( Expression, Expression ) -> a) -> Let a
tuple desiredNameOne desiredNameTwo valueExpr sourceLet =
    sourceLet
        |> with
            (Let
                (\index ->
                    let
                        ( oneName, oneIndex ) =
                            Compiler.getName desiredNameOne index

                        ( twoName, twoIndex ) =
                            Compiler.getName desiredNameTwo oneIndex

                        ( newIndex, sourceDetails ) =
                            Compiler.toExpressionDetails twoIndex valueExpr
                    in
                    { letDecls =
                        [ Compiler.nodify <|
                            Exp.LetDestructuring
                                (Compiler.nodify
                                    (Pattern.TuplePattern
                                        [ Compiler.nodify (Pattern.VarPattern oneName)
                                        , Compiler.nodify (Pattern.VarPattern twoName)
                                        ]
                                    )
                                )
                                (Compiler.nodify sourceDetails.expression)
                        ]
                    , index = newIndex
                    , return =
                        ( Compiler.Expression <|
                            \_ ->
                                { expression =
                                    Exp.FunctionOrValue []
                                        oneName
                                , annotation =
                                    case sourceDetails.annotation of
                                        Err e ->
                                            Err e

                                        Ok inference ->
                                            case inference.type_ of
                                                Annotation.Tupled [ Node.Node _ oneType, Node.Node _ twoType ] ->
                                                    Ok
                                                        { type_ = oneType
                                                        , inferences = Dict.empty
                                                        , aliases = inference.aliases
                                                        }

                                                _ ->
                                                    Err []
                                , imports =
                                    sourceDetails.imports
                                }
                        , Compiler.Expression <|
                            \_ ->
                                { expression =
                                    Exp.FunctionOrValue []
                                        (Compiler.sanitize twoName)
                                , annotation =
                                    case sourceDetails.annotation of
                                        Err e ->
                                            Err e

                                        Ok inference ->
                                            case inference.type_ of
                                                Annotation.Tupled [ Node.Node _ oneType, Node.Node _ twoType ] ->
                                                    Ok
                                                        { type_ = twoType
                                                        , inferences = Dict.empty
                                                        , aliases = inference.aliases
                                                        }

                                                _ ->
                                                    Err []
                                , imports =
                                    []
                                }
                        )
                    }
                )
            )


{-| -}
record :
    List String
    -> Expression
    -> Let (List Expression -> a)
    -> Let a --Let (List Expression)
record fields recordExp sourceLet =
    -- Note, we can't actually guard the field names against collision here
    -- They have to be the actual field names in the record, duh.
    sourceLet
        |> with
            (Let
                (\index ->
                    let
                        ( recordIndex, recordDetails ) =
                            Compiler.toExpressionDetails index recordExp

                        ( finalIndex, unpackedfields ) =
                            List.foldl
                                (\fieldName ( i, gathered ) ->
                                    let
                                        ( gotIndex, got ) =
                                            Elm.get fieldName recordExp
                                                |> Compiler.toExpressionDetails index
                                    in
                                    ( gotIndex
                                    , Compiler.Expression
                                        (\_ ->
                                            { got
                                                | expression =
                                                    Exp.FunctionOrValue []
                                                        fieldName
                                            }
                                        )
                                        :: gathered
                                    )
                                )
                                ( recordIndex, [] )
                                fields
                    in
                    { letDecls =
                        [ Compiler.nodify
                            (Exp.LetDestructuring
                                (Compiler.nodify
                                    (Pattern.RecordPattern
                                        (List.map Compiler.nodify
                                            fields
                                        )
                                    )
                                )
                                (Compiler.nodify recordDetails.expression)
                            )
                        ]
                    , index = finalIndex
                    , return =
                        List.reverse unpackedfields
                    }
                )
            )


{-| -}
toExpression : Let Expression -> Expression
toExpression (Let toScope) =
    Compiler.Expression <|
        \index ->
            let
                scope =
                    toScope index

                ( returnIndex, return ) =
                    Compiler.toExpressionDetails scope.index scope.return
            in
            { expression =
                -- if we're leading into another let expression, just merge with it.
                case return.expression of
                    Exp.LetExpression innerReturn ->
                        Exp.LetExpression
                            { declarations =
                                List.reverse scope.letDecls
                                    ++ innerReturn.declarations
                            , expression = innerReturn.expression
                            }

                    _ ->
                        Exp.LetExpression
                            { declarations = List.reverse scope.letDecls
                            , expression = Compiler.nodify return.expression
                            }
            , imports = return.imports
            , annotation =
                return.annotation
            }
