Package["Wolfram`QuantumFramework`"]

PackageExport["QuantumMeasurement"]

PackageScope["QuantumMeasurementQ"]


CategoricalDistribution



QuantumMeasurementQ[QuantumMeasurement[qmo_ ? QuantumMeasurementOperatorQ]] := True

QuantumMeasurementQ[___] := False


qm_QuantumMeasurement["ValidQ"] := QuantumMeasurementQ[qm]


(* constructors *)

QuantumMeasurement[qs_ ? QuantumStateQ, target_ ? targetQ] := QuantumMeasurement[QuantumMeasurementOperator[qs["Operator"], target]]

QuantumMeasurement[qo_ ? QuantumFrameworkOperatorQ, target_ ? targetQ] := QuantumMeasurement[QuantumMeasurementOperator[qo, target]]

QuantumMeasurement[proba_Association] := Enclose @ QuantumMeasurement[proba, QuantumBasis[2, ConfirmBy[Log2[Length[proba]], IntegerQ]]["PureStates"]]

QuantumMeasurement[proba_Association, states : {_ ? QuantumStateQ..}] /;
    Length[proba] == Length[states] && Equal @@ Map[#["Dimensions"] &, states] :=
QuantumMeasurement[
    QuantumOperator[
        QuantumState[
            QuantumState[
                ArrayReshape[
                    Transpose[
                        With[{probValues = Sqrt @ SparseArray @ Values[proba]},
                            SparseArray @ TensorProduct[
                                probValues,
                                MapThread[Times, {probValues, #["Computational"]["Normalized"]["DensityTensor"] & /@ states}]
                            ]
                        ],
                        Cycles[{RotateRight @ Reverse @ Range[First[states]["Qudits"] + 2]}]
                    ],
                    Table[Length[states] First[states]["Dimension"], 2]
                ],
                QuantumTensorProduct[
                    QuantumBasis[QuditName /@ Keys[proba]],
                    QuantumBasis[First[states]["OutputDimensions"], First[states]["InputDimensions"]]
                ]
            ],
            QuantumTensorProduct[
                QuantumBasis[QuditName /@ Keys[proba]],
                First[states]["Basis"]
            ]
        ],
        {Prepend[Range[First[states]["FullOutputQudits"]], 0], Range[First[states]["FullInputQudits"]]}
    ],
    Range[First[states]["Qudits"]]
]


(* properties *)

$QuantumMeasurementProperties = {
    "QuantumOperator",
    "Distribution",
    "Outcomes", "Probabilities",
    "Mean", "States", "StateAssociation",
    "Entropy",
    "PostMeasurementState",
    "Eigenvalues", "EigenvalueVectors",
    "Eigenvectors", "Projectors",
    "SimulatedMeasurement", "SimulatedCounts"
};


QuantumMeasurement["Properties"] := QuantumMeasurement["Properties"] =
    DeleteDuplicates @ Join[$QuantumMeasurementProperties, QuantumMeasurementOperator["Properties"]]


QuantumMeasurement::undefprop = "QuantumMeasurement property `` is undefined for this basis";

(qm_QuantumMeasurement[prop_ ? propQ, args___]) /; QuantumMeasurementQ[qm] := With[{
    result = QuantumMeasurementProp[qm, prop, args]
    },
    (* don't cache Simulated* results *)
    If[ ! TrueQ[$QuantumFrameworkPropCache] || MatchQ[prop, name_String | {name_String, ___} /; StringStartsQ[name, "Simulated"]],
        result,
        QuantumMeasurementProp[qm, prop, args] = result
    ] /; !MatchQ[result, _QuantumMeasurementProp] || Message[QuantumMeasurement::undefprop, prop]
]

QuantumMeasurement[qm_QuantumMeasurement, args___] := QuantumMeasurement[QuantumMeasurementOperator[qm["QuantumOperator"], args]]

QuantumMeasurement[qmo_QuantumMeasurementOperator, args__] := QuantumMeasurement[QuantumMeasurementOperator[qmo, args]]


QuantumMeasurementProp[qm_, "Properties"] := Union @ Join[$QuantumMeasurementProperties, qm["QuantumOperator"]["Properties"]]

QuantumMeasurementProp[QuantumMeasurement[qmo_], "QuantumOperator"] := qmo

QuantumMeasurementProp[qm_, "Operator"] := qm["QuantumOperator"]["Operator"]

QuantumMeasurementProp[qm_, "Canonical"] := QuantumMeasurement @ qm["QuantumOperator"]["Canonical"]

QuantumMeasurementProp[qm_, "Computational"] := QuantumMeasurement @ qm["QuantumOperator"]["Computational"]


QuantumMeasurementProp[qm_, "StateDual"] := qm["State"]["Split", qm["Qudits"]]["PermuteOutput",
    FindPermutation @ Catenate[{#1, #3, #2}] & @@
        TakeList[Range[qm["Qudits"]], {qm["Eigenqudits"], qm["StateQudits"], qm["InputQudits"]}]
]["Split", qm["Eigenqudits"] + qm["InputQudits"]]

QuantumMeasurementProp[qm_, "Eigenstate"] :=
    QuantumPartialTrace[qm["State"], qm["Eigenqudits"] + Range[qm["StateQudits"]]]


QuantumMeasurementProp[qm_, "PostMeasurementState"] := QuantumPartialTrace[
    qm["State"],
    Join[Range[qm["Eigenqudits"]], qm["Eigenqudits"] + Complement[Range[qm["StateQudits"]], qm["Target"]]]
]

QuantumMeasurementProp[qm_, "MixedStates"] := With[{rep = If[qm["PureStateQ"], 1, 2]},
    Which[
        MatchQ[qm["LabelHead"], "Computational" | Automatic],
        QuantumState[QuantumState[ArrayReshape[#, Table[qm["StateDimension"], rep]], QuantumBasis[qm["StateDimensions"]]], qm["StateBasis"]]["Computational"] & /@
            qm["StateDual"]["StateMatrix"],
        MatchQ[qm["LabelHead"], "Eigen"] || qm["Eigendimension"] != qm["TargetDimension"],
        QuantumState[ArrayReshape[#, Table[qm["StateDimension"], rep]], qm["StateBasis"]] & /@
            qm["StateDual"]["StateMatrix"],
        True,
        QuantumState[ArrayReshape[#, Table[qm["StateDimension"], rep]], qm["StateBasis"]] & /@
            qm["Canonical"]["StateDual"]["StateMatrix"]
    ]
]

QuantumMeasurementProp[qm_, "States"] := If[qm["PureStateQ"], qm["MixedStates"], Plus @@@ Partition[qm["MixedStates"], qm["Eigendimension"] qm["InputDimension"]]]

QuantumMeasurementProp[qm_, "ProbabilitiesList"] :=
    Which[
        MatchQ[qm["LabelHead"], "Computational" | Automatic],
        qm["Computational"]["Eigenstate"],
        MatchQ[qm["LabelHead"], "Eigen"] || qm["Eigendimension"] != qm["TargetDimension"],
        qm["Eigenstate"],
        True,
        qm["Canonical"]["Eigenstate"]
    ]["Probabilities"]

QuantumMeasurementProp[qm_, "Eigenvalues"] := qm["Eigenstate"]["Names"]

QuantumMeasurementProp[qm_, "EigenvalueVectors"] := Replace[Flatten[{#["Name"]}] & /@ qm["Eigenvalues"], {Interpretation[_, {v_, _}] :> v, v_ :> Ket[v]}, {2}]

QuantumMeasurementProp[qm_, "Eigenvectors"] := qm["Eigenstate"]["Eigenvectors"]

QuantumMeasurementProp[qm_, "Projectors"] := qm["Eigenstate"]["Projectors"]

QuantumMeasurementProp[qm_, "Outcomes"] := Which[
    MatchQ[qm["LabelHead"], "Computational" | Automatic],
    qm["Computational"],
    MatchQ[qm["LabelHead"], "Eigen"] || qm["Eigendimension"] != qm["TargetDimension"],
    qm,
    True,
    qm["Canonical"]
]["Eigenvalues"]

QuantumMeasurementProp[qm_, "MixedOutcomes"] := If[
    qm["PureStateQ"],
    qm["Outcomes"],
    QuantumTensorProduct @@@ Tuples[{qm["Outcomes"], #["Dual"] & /@ qm["Outcomes"]}]
]

QuantumMeasurementProp[qm_, "Distribution"] := CategoricalDistribution[
    qm["Outcomes"],
    Normal @ Chop @ N @ qm["ProbabilitiesList"]
]

QuantumMeasurementProp[qm_, "Probabilities"] := AssociationThread[
    qm["Outcomes"],
    Normal @ qm["ProbabilitiesList"]
]

QuantumMeasurementProp[qm_, "DistributionInformation", args___] := Information[qm["Distribution"], args]

QuantumMeasurementProp[qm_, args :
    "Categories" | "Probabilities" | "ProbabilityTable" | "ProbabilityArray" |
    "ProbabilityPlot" |
    "TopProbabilities" | ("TopProbabilities" -> _Integer)] := qm["DistributionInformation", args]


QuantumMeasurementProp[qm_, "Entropy"] := TimeConstrained[Quantity[qm["DistributionInformation", "Entropy"] / Log[2], "Bits"], 1]

QuantumMeasurementProp[qm_, "SimulatedMeasurement"] := RandomVariate[qm["Distribution"]]

QuantumMeasurementProp[qm_, "SimulatedMeasurement", n_Integer] := RandomVariate[qm["Distribution"], n]

QuantumMeasurementProp[qm_, "SimulatedCounts", n_Integer : 100] := RandomVariate[MultinomialDistribution[n, qm["ProbabilitiesList"]]]

QuantumMeasurementProp[qm_, "Mean"] := Replace[Total @ MapThread[Times, {qm["ProbabilitiesList"], qm["EigenvalueVectors"]}], {x_} :> x]

QuantumMeasurementProp[qm_, "StateAssociation" | "StatesAssociation"] := Part[
    KeySort @ AssociationThread[qm["Outcomes"], qm["States"]],
    Catenate @ SparseArray[qm["ProbabilitiesList"]]["ExplicitPositions"]
]

QuantumMeasurementProp[qm_, "StateAmplitudes"] := Map[Simplify, #["Amplitudes"]] & /@ qm["StateAssociation"]

QuantumMeasurementProp[qm_, "StateProbabilities"] := Select[Chop /@ Merge[Thread[qm["States"] -> qm["ProbabilitiesList"]], Total], # != 0 &]

QuantumMeasurementProp[qm_, "StateProbabilityTable"] := Dataset[qm["StateProbabilities"]]

QuantumMeasurementProp[qm_, "TopStateProbabilities"] := KeyMap[qm["StateAssociation"], Association @ qm["TopProbabilities"]]

QuantumMeasurementProp[qm_, "TopStateProbabilities" -> n_Integer] := KeyMap[qm["StateAssociation"], Association @ qm["TopProbabilities" -> n]]

QuantumMeasurementProp[qm_, "SimulatedStateMeasurement"] := qm["StateAssociation"][qm["SimulatedMeasurement"]]

QuantumMeasurementProp[qm_, "SimulatedStateMeasurement", n_] := Part[qm["StateAssociation"], Key /@ qm["SimulatedMeasurement", n]]

QuantumMeasurementProp[qm_, "MeanState"] := qm["Mean"] /. qm["StateAssociation"]

QuantumMeasurementProp[qm_, "Simplify"] := QuantumMeasurement[qm["QuantumOperator"]["Simplify"]]


(* qmo properties *)

QuantumMeasurementProp[qm_, prop_ ? propQ, args___] /;
    MatchQ[prop, Alternatives @@ Intersection[qm["QuantumOperator"]["Properties"], qm["Properties"]]] := qm["QuantumOperator"][prop, args]


(* equality *)

QuantumMeasurement /: Equal[qms : _QuantumMeasurement ...] :=
    Equal @@ (#["Canonical"]["State"] & /@ {qms})


(* formatting *)

QuantumMeasurement /: MakeBoxes[qm_QuantumMeasurement, TraditionalForm] /; QuantumMeasurementQ[Unevaluated[qm]] :=
    With[{proba = ToBoxes[qm["Probabilities"]]},
        InterpretationBox[proba, qm]
    ]

QuantumMeasurement /: MakeBoxes[qm_QuantumMeasurement ? QuantumMeasurementQ, format_] := Module[{icon},
    icon = With[{proba = TimeConstrained[qm["Probabilities"], 1]},
        If[
            ! FailureQ[proba] && AllTrue[proba, NumericQ],
            Show[
                BarChart[
                    Chop /@ N @ proba, Frame -> {{True, False}, {True, False}}, FrameTicks -> None,
                    ChartLabels -> Placed[KeyValueMap[Column[{##}] &, qm["Probabilities"]], Tooltip]
                ],
                ImageSize -> Dynamic @ {Automatic, 3.5 CurrentValue["FontCapHeight"] / AbsoluteCurrentValue[Magnification]}
            ],
            Graphics[{
                {GrayLevel[0.55], Rectangle[{0., 0.}, {0.87, 1.}]},
                {GrayLevel[0.8], Rectangle[{1.,0.}, {1.88, 2.}]},
                {GrayLevel[0.65], Rectangle[{2., 0.}, {2.88, 3.}]}},
                Background -> GrayLevel[1], ImageSize -> {Automatic, 29.029}, AspectRatio -> 1]
        ]
    ];
    BoxForm`ArrangeSummaryBox["QuantumMeasurement", qm,
        Tooltip[icon, qm["Label"]],
        {
            {
                BoxForm`SummaryItem[{"Target: ", qm["Target"]}]
            },
            {
                BoxForm`SummaryItem[{"Measurement Outcomes: ", Length[qm["Outcomes"]]}]
            }
        },
        {
            {
                BoxForm`SummaryItem[{"Entropy: ", TimeConstrained[Enclose[ConfirmQuiet[N @ qm["Entropy"]], Indeterminate &], 1]}]
            }
        },
        format,
        "Interpretable" -> Automatic
    ]
]

