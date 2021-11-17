Package["Wolfram`QuantumFramework`"]

PackageScope["$QuantumOperatorNames"]
PackageScope["pauliZGate"]
PackageScope["controlledZGate"]



$QuantumOperatorNames = {
    "Identity", "Permutation", "Curry", "Uncurry",
    "Fourier", "InverseFourier",
    "XRotation", "YRotation", "ZRotation", "Phase", "P",
    "SUM", "RootNot",
    "X", "Y", "Z", "PauliX", "PauliY", "PauliZ", "H", "Hadamard",
    "SWAP", "RootSWAP", "CSWAP", "Fredkin",
    "Controlled", "Controlled0", "CX", "CY", "CZ", "CH", "CT", "CS", "CPHASE", "CNOT",
    "XX", "YY", "ZZ",
    "Toffoli", "Deutsch", "RandomUnitary",
    "Spider", "Deutsch"
}


pauliZGate = SparseArray[{j_, j_} :> Exp[(2 Pi I j / 2) + I Pi], {2, 2}];

controlledZGate = ReplacePart[
    IdentityMatrix[4],
    Thread[
        Flatten[Table[{i, j}, {i, 4 - Length[pauliZGate] + 1, 4}, {j, 4 - Length[pauliZGate] + 1, 4}], {2, 1}] ->
        Flatten[pauliZGate]
    ]
];


QuantumOperator[name_ ? nameQ, basisName : Except[Alternatives @@ $QuantumBasisPictures, _ ? nameQ]] :=
    QuantumOperator[QuantumOperator[name], QuantumBasis[basisName]]


QuantumOperator["Identity", args___] := QuantumOperator[{"Identity", 2}, args]

QuantumOperator[{"Identity", dimension_Integer}, args___] := QuantumOperator[IdentityMatrix[dimension], dimension, args]

QuantumOperator[{"Identity", dims_List}, args___] := QuantumOperator[{"Permutation", dims, Cycles[{{}}]}, args]

QuantumOperator[{"Identity", qb_ ? QuditBasisQ}, args___] := QuantumOperator[IdentityMatrix[qb["Dimension"]], qb, args]


QuantumOperator[name : "XRotation" | "YRotation" | "ZRotation", args___] :=  QuantumOperator[{name, Pi / 2}, args]

QuantumOperator[{"XRotation", angle_, dimension_Integer : 2}, args___] := QuantumOperator[
    Exp[- I angle / 2 QuantumOperator[{"PauliX", dimension}, args]],
    "Label" -> Subscript["R", "X"][angle]
]

QuantumOperator[{"YRotation", angle_, dimension_Integer : 2}, args___] := QuantumOperator[
    Exp[- I angle / 2 QuantumOperator[{"PauliY", dimension}, args]],
    "Label" -> Subscript["R", "Y"][angle],
    args
]

QuantumOperator[{"ZRotation", angle_, dimension_Integer : 2}, args___] := QuantumOperator[
    Exp[- I angle / 2 QuantumOperator[{"PauliZ", dimension}, args]],
    "Label" -> Subscript["R", "Z"][angle],
    args
]

QuantumOperator["Phase" | "P", args___] := QuantumOperator[{"Phase", Pi}, args]

QuantumOperator[{"Phase" | "P", angle_, dimension_Integer : 2}, args___] := QuantumOperator[
    SparseArray[{{1, 1} -> 1, {dimension, dimension} -> Exp[I angle]}],
    "Label" -> "P"[angle],
    args
]


QuantumOperator["S", args___] := QuantumOperator[{"Phase", Pi / 2}, "Label" -> "S", args]

QuantumOperator["T", args___] := QuantumOperator[{"Phase", Pi / 4}, "Label" -> "T", args]


QuantumOperator["CNOT", args___] := QuantumOperator[{"CNOT", 2}, args]

QuantumOperator[{"CNOT", dimension_Integer}, args___] := QuantumOperator[{"ControlledU", {"NOT", dimension}}, args]


QuantumOperator["CPHASE", args___] := QuantumOperator[{"CPHASE", Pi}, args]

QuantumOperator[{"CPHASE", angle_, dimension_Integer : 2}, args___] := QuantumOperator[{"ControlledU", {"Phase", angle, dimension}}, args]


controlledMatrix[matrix_ ? MatrixQ, dimension_Integer] := ReplacePart[
    IdentityMatrix[dimension ^ 2],
    Thread[
        Flatten[
            Table[{i, j},
                {i, (dimension ^ 2) - Length[matrix] + 1, dimension ^ 2},
                {j, (dimension ^ 2) - Length[matrix] + 1, dimension ^ 2}
            ],
            {2, 1}
        ] -> Flatten[matrix]
    ]
]

QuantumOperator[name : "CX" | "CY" | "CZ", args___] := QuantumOperator[{name, 2}, args]

QuantumOperator[{"CX", dimension_Integer}, args___] :=
    QuantumOperator[{"ControlledU", {"PauliX", dimension}}, args]

QuantumOperator[{"CY", dimension_Integer}, args___] :=
    QuantumOperator[{"ControlledU", {"PauliY", dimension}}, args]

QuantumOperator[{"CZ", dimension_Integer}, args___] :=
    QuantumOperator[{"ControlledU", {"PauliZ", dimension}}, args]

QuantumOperator["CH", args___] := QuantumOperator[{"ControlledU", "Hadamard"}, args]

QuantumOperator["CT", args___] := QuantumOperator[{"ControlledU", "T"}, args]

QuantumOperator["CS", args___] := QuantumOperator[{"ControlledU", "S"}, args]


QuantumOperator[{"ControlledU" | "Controlled", params : PatternSequence[Except[_ ? QuantumOperatorQ], ___], control_ ? orderQ}, args___] :=
    With[{op = QuantumOperator[params]}, QuantumOperator[{"ControlledU", QuantumOperator[op, Max[control] + op["InputOrder"]], control}, args]]

QuantumOperator[{"ControlledU" | "Controlled", params : PatternSequence[Except[_ ? QuantumOperatorQ], ___], control_ ? orderQ}, args___, target_ ? orderQ] :=
    QuantumOperator[{"ControlledU", QuantumOperator[params, target], control}, args]

QuantumOperator[{"ControlledU" | "Controlled", params : PatternSequence[___, Except[_ ? orderQ]]}, args___, order_ ? orderQ] :=
    With[{op = QuantumOperator[params, Rest @ order /. {} -> {First @ order + 1}]},
        QuantumOperator[{"ControlledU", op, {First @ order}}, args]
    ]

QuantumOperator[{"ControlledU" | "Controlled", params : PatternSequence[Except[_ ? QuantumOperatorQ], ___]}, args___] := Enclose @
    With[{op = QuantumOperator[params]},
        QuantumOperator[{"ControlledU", ConfirmBy[QuantumOperator[op, op["InputOrder"] + 1], QuantumOperatorQ], {First @ op["InputOrder"]}}, args]
    ]

QuantumOperator[{"ControlledU" | "Controlled", qo_ ? QuantumOperatorQ}, args___] := QuantumOperator[{"ControlledU", qo, {qo["LastInputQudit"] + 1}}, args]

QuantumOperator[{"ControlledU" | "Controlled", qo_ ? QuantumOperatorQ, control_ ? orderQ}, args___] := Enclose @ With[{controls = Length[control]},
    (*ConfirmAssert[! IntersectingQ[qo["Order"], control], "Target and control qudits shouldn't intersect"];*)
    QuantumOperator[
        ResourceFunction["BlockDiagonalMatrix"][IdentityMatrix[(2 ^ controls - 1) qo["OutputDimension"]], qo["Matrix"]],
        QuantumTensorProduct[QuantumBasis[QuditBasis[2, controls], QuditBasis[2, controls]], qo["Basis"]],
        "Label" -> "Controlled"[qo["Label"], control],
        args,
        Join[control,
            If[ IntersectingQ[control, qo["FullInputOrder"]],
                With[{order = Complement[Range @@ MinMax[Join[control, qo["FullInputOrder"]]], control]},
                    Join[order, Max[qo["FullInputOrder"], control] + Range[qo["Arity"] - Length[order]]]
                ],
                qo["InputOrder"]
            ]
        ]
    ]
]


QuantumOperator["Controlled0" | {"Controlled0", params___}, args___] := With[{
    op = QuantumOperator[{"Controlled", params}, args]
},
    QuantumOperator[
        QuantumOperator["NOT", op["ControlOrder"]] @ op @ QuantumOperator["NOT", op["ControlOrder"]],
        "Label" -> Insert[op["Label"], "Zero", 3]
    ]
]


QuantumOperator["Fourier", args___] := QuantumOperator[{"Fourier", 2}, args]

QuantumOperator[{"Fourier", dimension_Integer}, args___, order : (_ ? orderQ) : {1}] := QuantumOperator[QuantumOperator[
        SparseArray[
            ({i_, j_} :>  Exp[2 Pi I (i - 1) (j - 1) / (dimension ^ Length[order])] / Sqrt[dimension ^ Length[order]]),
            {dimension ^ Length[order], dimension ^ Length[order]}
        ],
        dimension,
        Length[order]
    ],
    "Label" -> "QFT",
    args,
    order
]

QuantumOperator["InverseFourier", args___] := QuantumOperator[{"InverseFourier", 2}, args]

QuantumOperator[{"InverseFourier", dimension_Integer}, args___, order : (_ ? orderQ) : {1}] := QuantumOperator[QuantumOperator[
        SparseArray[
            ({i_, j_} :> Exp[-2 Pi I (i - 1) (j - 1) / (dimension ^ Length[order])] / Sqrt[dimension ^ Length[order]]),
            {dimension ^ Length[order], dimension ^ Length[order]}
        ],
        dimension,
        Length[order]
    ],
    "Label" -> Superscript["QFT", "\[Dagger]"],
    args,
    order
]


swapMatrix[dimension_] := SparseArray[# -> 1 & /@
    Thread[{
        Range[dimension ^ 2],
        Flatten @ Table[j + i - 1, {i, dimension}, {j, 1, dimension ^ 2, dimension}]
    }]
]

QuantumOperator["SWAP", args___] := QuantumOperator[{"SWAP", 2}, args]

QuantumOperator[{"SWAP", dimension_Integer}, args___] :=
    QuantumOperator[QuantumOperator[swapMatrix[dimension], dimension, 2], "Label" -> "SWAP", args]

QuantumOperator["RootSWAP", args___] := QuantumOperator[{"RootSWAP", 2}, args]

QuantumOperator[{"RootSWAP", dimension_Integer}, args___] :=
    QuantumOperator[QuantumOperator[MatrixPower[swapMatrix[dimension], 1 / 2], dimension, 2], "Label" -> "RootSWAP", args]


QuantumOperator["SUM", args___] := QuantumOperator[{"SUM", 2}, args]

QuantumOperator[{"SUM", dimension_Integer}, args___] := QuantumOperator[QuantumOperator[
        SparseArray[{input_, output_} :>
            With[{
                i1 = First[IntegerDigits[input - 1, dimension, 2]],
                j1 = IntegerDigits[input - 1, dimension, 2][[2]],
                i2 = First[IntegerDigits[output - 1, dimension, 2]],
                j2 = IntegerDigits[output - 1, dimension, 2][[2]]
            },
            If[i1 == i2 && j2 == Mod[i1 + j1, dimension], 1, 0]
            ],
            {dimension ^ 2, dimension ^ 2}
        ],
        dimension,
        2
    ],
    "Label" -> "SUM",
    args
]


pauliMatrix[1, dimension_] := With[{
    s = (dimension - 1) / 2
},
    SparseArray[
        {a_, b_} :> (KroneckerDelta[a, b + 1] + KroneckerDelta[a + 1, b]) Sqrt[(s + 1) (a + b - 1) - a b],
        {dimension, dimension}
    ]
]

QuantumOperator[name : "X" | "Y" | "Z" | "PauliX" | "PauliY" | "PauliZ" | "NOT", args___] := QuantumOperator[{name, 2}, args]

QuantumOperator[{"PauliX" | "X", dimension_Integer}, args___] := QuantumOperator[
    pauliMatrix[1, dimension],
    dimension,
    "Label" -> "X",
    args
]

QuantumOperator[{"PauliY" | "Y", dimension_Integer}, args___] := QuantumOperator[
    pauliMatrix[2, dimension],
    dimension,
    "Label" -> "Y",
    args
]

QuantumOperator[{"PauliZ" | "Z", dimension_Integer}, args___] := QuantumOperator[
    pauliMatrix[3, dimension],
    dimension,
    "Label" -> "Z",
    args
]

QuantumOperator[{"NOT", dimension_Integer}, args___] := QuantumOperator[{"X", dimension}, "Label" -> "NOT", args]


QuantumOperator["RootNOT", args___] := QuantumOperator[{"RootNOT", 2}, args]

QuantumOperator[{"RootNOT", dimension_Integer}, args___] := QuantumOperator[
    MatrixPower[
        SparseArray[({i_, j_} /; Mod[i - 1, dimension, 1] == j) -> 1, {dimension, dimension}],
        1 / 2
    ],
    dimension,
    "Label" -> "RootNOT",
    args
]


QuantumOperator["Hadamard" | "H", args___] := QuantumOperator[HadamardMatrix[2], "Label" -> "H", args]

QuantumOperator[{"Hadamard" | "H", qudits_Integer ? Positive}, args : PatternSequence[] | PatternSequence[___, Except[_ ? orderQ]]] :=
    QuantumOperator[{"H", qudits}, args, Range[qudits]]

QuantumOperator[{"Hadamard" | "H", qudits_Integer ? Positive}, args___, order_ ? orderQ] :=
    QuantumOperator[
        QuantumTensorProduct[Table[QuantumOperator["Hadamard", args], qudits]],
        "Label" -> If[qudits > 1, Superscript["H", CircleTimes[qudits]], "H"],
        order
    ]


QuantumOperator["Toffoli", order : (_ ? orderQ) : {1, 2, 3}] :=
    QuantumOperator[{"ControlledU", "NOT", Most[order]}, {Last[order]}]


QuantumOperator["CSWAP" | "Fredkin", args___] := QuantumOperator[{"ControlledU", "SWAP"}, args]


QuantumOperator[name : "XX" | "YY" | "ZZ", args___] := QuantumOperator[{name, 0}, args]

QuantumOperator[{"XX", angle_}, args___] := QuantumOperator[
    SparseArray[{
        {1, 1} -> Cos[angle / 2], {2, 2} -> Cos[angle / 2], {3, 3} -> Cos[angle / 2], {4, 4} -> Cos[angle / 2],
        {4, 1} -> -I Sin[angle / 2], {3, 2} -> -I Sin[angle / 2], {2, 3} -> -I Sin[angle / 2], {1, 4} -> -I Sin[angle / 2]
    },
        {4, 4}
    ],
    "Label" -> "XX",
    args
]

QuantumOperator[{"YY", angle_}, args___] := QuantumOperator[
    SparseArray[{
        {1, 1} -> Cos[angle / 2], {2, 2} -> Cos[angle / 2], {3, 3} -> Cos[angle / 2], {4, 4} -> Cos[angle / 2],
        {4, 1} -> I Sin[angle / 2], {3, 2} -> -I Sin[angle / 2], {2, 3} -> -I Sin[angle / 2], {1, 4} -> I Sin[angle / 2]
    },
        {4, 4}
    ],
    "Label" -> "YY",
    args
]

QuantumOperator[{"ZZ", angle_}, args___] := QuantumOperator[
    SparseArray[{
        {1, 1} -> Exp[- I angle / 2], {2, 2} -> Exp[I angle / 2],
        {3, 3} -> Exp[I angle / 2], {4, 4} ->  Exp[- I angle / 2]
    },
        {4, 4}
    ],
    "Label" -> "ZZ",
    args
]


QuantumOperator["RandomUnitary", args___] := QuantumOperator[{"RandomUnitary", 2}, args]

QuantumOperator[{"RandomUnitary", dimension_Integer}, args___, order : (_ ? orderQ) : {1}] :=
    QuantumOperator[RandomVariate @ CircularUnitaryMatrixDistribution[dimension ^ Length[order]], dimension, Length[order], "Label" -> None, args, order]


QuantumOperator[{"Permutation", perm_Cycles}, args___] := QuantumOperator[{"Permutation", 2, perm}, args]

QuantumOperator[{"Permutation", dim_Integer, perm_Cycles}, args___] := QuantumOperator[{"Permutation", Table[dim, PermutationMax[perm]], perm}, args]

QuantumOperator[{"Permutation", dims_List, perm_Cycles}] := QuantumOperator[{"Permutation", dims, perm}, Range[Length[dims]]]

QuantumOperator[{"Permutation", dims_List, perm_Cycles}, order_ ? orderQ] := QuantumOperator[
    TensorTranspose[ArrayReshape[kroneckerProduct @@ IdentityMatrix /@ dims, Join[dims, dims]], perm],
    QuantumBasis[QuditBasis[Permute[dims, perm]], QuditBasis[dims], "Label" -> Superscript["\[Pi]", Row @ PermutationList[perm]]],
    order
]

QuantumOperator["Uncurry", args___] := QuantumOperator[{"Uncurry", {2, 2}}, args]

QuantumOperator[{"Uncurry", dims_List}] := QuantumOperator[{"Uncurry", dims}, {1}, Range[Length[dims]]]

QuantumOperator[{"Uncurry", dims_List}, args___] :=
    QuantumOperator[
        QuantumOperator[IdentityMatrix[Times @@ dims], QuantumBasis[QuditBasis[Times @@ dims], QuditBasis[dims]["Dual"]]],
        args
    ]


QuantumOperator[name : "Curry" | {"Curry", ___}, args___] := QuantumOperator[name /. "Curry" -> "Uncurry", args]["ConjugateTranspose"]


QuantumOperator[name : "ZSpider" | "XSpider" | "Spider", args___] := QuantumOperator[{name}, args]

QuantumOperator[{"ZSpider", out_Integer : 1, in_Integer : 1, phase_ : 0}, args___] := Module[{
    phases = If[ListQ[phase], phase, {0, phase}],
    dim, basis
},
    dim = Length[phases];
    basis = QuantumBasis[QuditBasis[dim, out], QuditBasis[dim, in], "Label" -> "ZSpider"];
    QuantumOperator[
        QuantumState[Flatten @ SparseArray[Thread[Transpose[Table[Range[dim], basis["Qudits"]]] -> Exp[I phases]], basis["Dimensions"]], basis],
        args,
        Range[basis["OutputQudits"]], Range[basis["InputQudits"]]
    ]
]


QuantumOperator[{"XSpider", params___}, args___] := With[{
    zSpider = QuantumOperator[{"ZSpider", params}, args]
},
    QuantumOperator[
        QuantumOperator[zSpider, QuantumBasis[
            QuditBasis[{"PauliX", First @ zSpider["Dimensions"]}, zSpider["OutputQudits"]],
            QuditBasis[{"PauliX", First @ zSpider["Dimensions"]}, zSpider["InputQudits"]]]
        ]["Matrix"],
        zSpider["Basis"],
        "Label" -> "XSpider",
        zSpider["Order"]
    ]
]


QuantumOperator[{"Spider", basis_ ? QuantumBasis, phase_ : 0}, args___] := With[{
    zSpider = QuantumOperator[{"ZSpider", phase, basis["OutputQudits"], basis["InputQudits"]}, args]
},
    QuantumOperator[
        QuantumOperator[zSpider, basis]["Matrix"],
        zSpider["Basis"],
        "Label" -> basis["Label"],
        zSpider["Order"]
    ]
]


QuantumOperator[{"Deutsch", theta_}, order : _ ? orderQ : {1, 2, 3}] := With[{
    controlOrder = PadRight[Most[order], 2, Range[2] + Max[order]],
    targetOrder = {Last[order]}
},
    QuantumOperator[{
        "ControlledU",
        QuantumOperator[I QuantumOperator[{"XRotation", theta}, targetOrder], "Label" -> "D"[theta]],
        controlOrder
    }]
]

