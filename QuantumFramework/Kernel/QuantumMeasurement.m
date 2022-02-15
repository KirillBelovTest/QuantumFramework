Package["Wolfram`QuantumFramework`"]

PackageExport["QuantumMeasurement"]

PackageScope["QuantumMeasurementQ"]


QuantumMeasurementQ[QuantumMeasurement[qmo_ ? QuantumMeasurementOperatorQ]] := qmo["OutputQudits"] <= qmo["InputQudits"]

QuantumMeasurementQ[___] := False


qm_QuantumMeasurement["ValidQ"] := QuantumMeasurementQ[qm]


(* constructors *)

QuantumMeasurement[qs_ ? QuantumStateQ, target_ ? orderQ] := QuantumMeasurement[QuantumMeasurementOperator[qs["Operator"], target]]

QuantumMeasurement[qo_ ? QuantumFrameworkOperatorQ, target_ ? orderQ] := QuantumMeasurement[QuantumMeasurementOperator[qo, target]]

QuantumMeasurement[proba_Association, states : {_ ? QuantumStateQ..}] /;
    Length[proba] == Length[states] && Equal @@ Map[#["Dimensions"] &, states] :=
QuantumMeasurement[
    QuantumState[
        QuantumState[
            ArrayReshape[
                Transpose[
                    TensorProduct[
                        Sqrt @ Values[proba],
                        MapThread[Times, {Sqrt @ Values[proba], #["Computational"]["Normalized"]["DensityTensor"] & /@ states}]
                    ],
                    Cycles[{RotateRight @ Reverse @ Range[Length[states] + 1]}]
                ],
                Table[Length[states] First[states]["Dimension"], 2]
            ],
            QuantumTensorProduct[
                QuantumBasis[Keys[proba]],
                QuantumBasis[First[states]["Dimensions"]]
            ]
        ],
        QuantumTensorProduct[
            QuantumBasis[Keys[proba]],
            First[states]["Basis"]
        ][{"Split", 1}]
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
    "PostMeasurementState"
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


QuantumMeasurementProp[qm_, "Properties"] := DeleteDuplicates @ Join[$QuantumMeasurementProperties, qm["QuantumOperator"]["Properties"]]

QuantumMeasurementProp[QuantumMeasurement[qmo_], "QuantumOperator" | "Operator"] := qmo

QuantumMeasurementProp[qm_, "TargetBasis"] := qm["Input"][{"Extract", qm["TargetIndex"]}]["Dual"]

QuantumMeasurementProp[qm_, "CanonicalBasis"] := QuantumBasis[qm["TargetBasis"], qm["Input"]["Dual"]]

QuantumMeasurementProp[qm_, "Canonical"] := QuantumMeasurement @
    QuantumMeasurementOperator[qm["QuantumOperator"]["Operator"], qm["CanonicalBasis"], qm["Target"]]


QuantumMeasurementProp[qm_, "Computational"] := QuantumMeasurement[
    qm["Operator"]["Computational"],
    qm["Target"]
]

QuantumMeasurementProp[qm_, "Arity" | "Targets"] := Length @ qm["Target"]

QuantumMeasurementProp[qm_, "Eigenstate"] := QuantumPartialTrace[qm["State"][{"Split", qm["Qudits"]}], qm["OutputQudits"] + Range[qm["InputQudits"]]]

QuantumMeasurementProp[qm_, "Eigenqudits"] := qm["OutputQudits"]

QuantumMeasurementProp[qm_, "PostMeasurementState"] := QuantumPartialTrace[
    qm["State"][{"Split", qm["Qudits"]}],
    Join[Range[qm["OutputQudits"]], qm["OutputQudits"] + Complement[Range[qm["InputQudits"]], qm["Target"]]]
]

QuantumMeasurementProp[qm_, "MixedStates"] := With[{rep = If[qm["PureStateQ"], 1, 2]},
    Which[
        MatchQ[qm["Label"], "Eigen" | "Eigen"[__]],
        QuantumState[ArrayReshape[#, Table[qm["InputDimension"], rep]], qm["Input"]["Dual"]] & /@ qm["StateMatrix"],
        MatchQ[qm["Label"], "Computational" | "Computational"[__]],
        QuantumState[QuantumState[ArrayReshape[#, Table[qm["InputDimension"], rep]], QuantumBasis[qm["InputDimensions"]]], QuantumBasis[qm["Input"]["Dual"]]] & /@
            qm["Computational"]["StateMatrix"],
        True,
        QuantumState[ArrayReshape[#, Table[qm["InputDimension"], rep]], QuantumBasis[qm["Input"]["Dual"]]] & /@
            qm["Canonical"]["StateMatrix"]
    ]
]

QuantumMeasurementProp[qm_, "States"] := If[qm["PureStateQ"], qm["MixedStates"], Plus @@@ Partition[qm["MixedStates"], qm["OutputDimension"]]]

QuantumMeasurementProp[qm_, "ProbabilitiesList"] :=
    If[MatchQ[qm["Label"], "Computational"[_]], qm["Eigenstate"]["Computational"], qm["Eigenstate"]]["Probabilities"]

QuantumMeasurementProp[qm_, "Eigenvalues"] := qm["Eigenstate"]["Names"]

QuantumMeasurementProp[qm_, "Outcomes"] := Which[
    MatchQ[qm["Label"], "Eigen" | "Eigen"[__]],
    qm["Eigenvalues"],
    MatchQ[qm["Label"], "Computational" | "Computational"[__]],
    QuditBasis[qm["InputDimensions"][[ qm["TargetIndex"] ]]]["Names"],
    True,
    qm["Canonical"]["Output"]["Names"]
]

QuantumMeasurementProp[qm_, "MixedOutcomes"] := If[
    qm["PureStateQ"],
    qm["Outcomes"],
    QuantumTensorProduct @@@ Tuples[{qm["Outcomes"], #["Dual"] & /@ qm["Outcomes"]}]
]

QuantumMeasurementProp[qm_, "Distribution"] := CategoricalDistribution[
    qm["Outcomes"],
    Normal @ Chop @ N @ qm["ProbabilitiesList"]
]

QuantumMeasurementProp[qm_, "DistributionInformation", args___] := Information[qm["Distribution"], args]

QuantumMeasurementProp[qm_, args :
    "Categories" | "Probabilities" | "ProbabilityTable" | "ProbabilityArray" |
    "ProbabilityPlot" |
    "TopProbabilities" | ("TopProbabilities" -> _Integer)] := qm["DistributionInformation", args]


QuantumMeasurementProp[qm_, "Entropy"] := Quantity[qm["DistributionInformation", "Entropy"] / Log[2], "Bits"]

QuantumMeasurementProp[qm_, "SimulatedMeasurement"] := RandomVariate[qm["Distribution"]]

QuantumMeasurementProp[qm_, {"SimulatedMeasurement", n_Integer}] := RandomVariate[qm["Distribution"], n]

QuantumMeasurementProp[qm_, "Mean"] := qm["Eigenvalues"] . qm["ProbabilitiesList"]

QuantumMeasurementProp[qm_, "StateAssociation" | "StatesAssociation"] := KeySort @ AssociationThread[qm["Outcomes"], qm["States"]]

QuantumMeasurementProp[qm_, "StateAmplitudes"] := Map[Simplify, #["Amplitudes"]] & /@ qm["StateAssociation"]

QuantumMeasurementProp[qm_, "StateProbabilities"] := Merge[Thread[qm["States"] -> qm["ProbabilityArray"]], Total]

QuantumMeasurementProp[qm_, "StateProbabilityTable"] := Dataset[qm["StateProbabilities"]]

QuantumMeasurementProp[qm_, "TopStateProbabilities"] := KeyMap[qm["StateAssociation"], Association @ qm["TopProbabilities"]]

QuantumMeasurementProp[qm_, "TopStateProbabilities" -> n_Integer] := KeyMap[qm["StateAssociation"], Association @ qm["TopProbabilities" -> n]]

QuantumMeasurementProp[qm_, "SimulatedStateMeasurement"] := qm["StateAssociation"][qm["SimulatedMeasurement"]]

QuantumMeasurementProp[qm_, {"SimulatedStateMeasurement", n_}] := Part[qm["StateAssociation"], Key /@ qm[{"SimulatedMeasurement", n}]]

QuantumMeasurementProp[qm_, "MeanState"] := qm["Mean"] /. qm["StateAssociation"]


(* qmo properties *)

QuantumMeasurementProp[qm_, prop_ ? propQ, args___] /;
    MatchQ[prop, Alternatives @@ Intersection[qm["QuantumOperator"]["Properties"], qm["Properties"]]] := qm["QuantumOperator"][prop, args]


(* equality *)

QuantumMeasurement /: (qm1_QuantumMeasurement ? QuantumMeasurementQ) == (qm2_QuantumMeasurement ? QuantumMeasurementQ) :=
    qm1["State"] == qm2["State"]


(* formatting *)

QuantumMeasurement /: MakeBoxes[qm_QuantumMeasurement ? QuantumMeasurementQ, format_] := Module[{icon},
    icon = If[
        AllTrue[qm["Probabilities"], NumericQ],
        Show[
            BarChart[qm["Probabilities"], Frame -> {{True, False}, {True, False}}, FrameTicks -> None],
            ImageSize -> Dynamic @ {Automatic, 3.5 CurrentValue["FontCapHeight"] / AbsoluteCurrentValue[Magnification]}
        ],
        Graphics[{
            {GrayLevel[0.55], Rectangle[{0., 0.}, {0.87, 1.}]},
            {GrayLevel[0.8], Rectangle[{1.,0.}, {1.88, 2.}]},
            {GrayLevel[0.65], Rectangle[{2., 0.}, {2.88, 3.}]}},
            Background -> GrayLevel[1], ImageSize -> {Automatic, 29.029}, AspectRatio -> 1]
    ];
    BoxForm`ArrangeSummaryBox["QuantumMeasurement", qm,
        icon,
        {
            {
                BoxForm`SummaryItem[{"Target: ", qm["Target"]}]
            },
            {
                BoxForm`SummaryItem[{"Measurement Outcomes: ", Length[qm["Probabilities"]]}]
            }
        },
        {
            {
                BoxForm`SummaryItem[{"Entropy: ", Enclose[N @ ConfirmQuiet[qm["Entropy"]], $Failed &]}]
            }
        },
        format,
        "Interpretable" -> Automatic
    ]
]

