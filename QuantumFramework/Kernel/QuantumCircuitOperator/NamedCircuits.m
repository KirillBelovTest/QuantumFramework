Package["Wolfram`QuantumFramework`"]

PackageScope["$QuantumCircuitOperatorNames"]



$QuantumCircuitOperatorNames = {
    "Graph",
    "GroverDiffusion", "GroverDiffusion0",
    "GroverPhaseDiffusion", "GroverPhaseDiffusion0",
    "BooleanOracle", "PhaseOracle",
    "BooleanOracleR",
    "Grover", "GroverPhase",
    "Grover0", "GroverPhase0",
    "Bell", "Toffoli",
    "BernsteinVaziraniOracle", "BernsteinVazirani",
    "Fourier", "InverseFourier",
    "PhaseEstimation",
    "Controlled",
    "Trotterization",
    "Magic",
    "Multiplexer",
    "QuantumState"
}


QuantumCircuitOperator[{"Graph", g_Graph, m : _Integer ? NonNegative : 0, gate_ : "CZ"}, opts___] := With[{
    ig = If[AllTrue[VertexList[g], Internal`PositiveIntegerQ], g, IndexGraph @ g]
},
    QuantumCircuitOperator[
        Join["H" -> # & /@ Range[Max[VertexList[ig]]], QuantumOperator[gate, {#1, #2} + m] & @@@
            EdgeList[ig]], "\[ScriptCapitalG]", opts
    ]
]


QuantumCircuitOperator[{"GroverAmplification" | "GroverDiffusion",
    xs : {_Integer ? Positive..},
    gate : _ ? QuantumOperatorQ | Automatic : Automatic
}, opts___] := Module[{
    op = If[gate === Automatic, QuantumOperator["NOT", {Max[xs]}], QuantumOperator[gate]], ys
},
    ys = DeleteCases[xs, Alternatives @@ op["OutputOrder"]];
    QuantumCircuitOperator[{
        Splice[Table[QuantumOperator["H", {q}], {q, ys}]],
        Splice[Table[QuantumOperator["X", {q}], {q, ys}]],
        QuantumOperator[{"Controlled", op, ys}],
        Splice[Table[QuantumOperator["X", {q}], {q, ys}]],
        Splice[Table[QuantumOperator["H", {q}], {q, ys}]]
    },
        opts
    ]
]

QuantumCircuitOperator[{"GroverPhaseAmplification" | "GroverPhaseDiffusion",
    xs : {_Integer ? Positive..},
    gate : _ ? QuantumOperatorQ | Automatic : Automatic
}, opts___] := With[{
    op = If[gate === Automatic, QuantumOperator["Z", {Max[xs]}], QuantumOperator[gate]]
},
    QuantumCircuitOperator[{
        Splice[Table[QuantumOperator["H", {q}], {q, xs}]],
        Splice[Table[QuantumOperator["X", {q}], {q, xs}]],
        QuantumOperator[{"Controlled", op, DeleteCases[xs, Alternatives @@ op["OutputOrder"]]}],
        Splice[Table[QuantumOperator["X", {q}], {q, xs}]],
        Splice[Table[QuantumOperator["H", {q}], {q, xs}]]
    },
        opts
    ]
]

QuantumCircuitOperator[{"GroverAmplification0" | "GroverDiffusion0",
    xs : {_Integer ? Positive..},
    gate : _ ? QuantumOperatorQ | Automatic : Automatic
}, opts___] := Module[{
    op = If[gate === Automatic, QuantumOperator["NOT", {Max[xs]}], QuantumOperator[gate]], ys
},
    ys = DeleteCases[xs, Alternatives @@ op["OutputOrder"]];
    QuantumCircuitOperator[
        {
            Splice[Table[QuantumOperator["H", {q}], {q, ys}]],
            QuantumOperator[{"Controlled0", op, ys}],
            Splice[Table[QuantumOperator["H", {q}], {q, ys}]]
        },
        opts,
        "GroverDiffusion"
    ]
]

QuantumCircuitOperator[{"GroverPhaseAmplification0" | "GroverPhaseDiffusion0",
    xs : {_Integer ? Positive..},
    gate : _ ? QuantumOperatorQ | Automatic : Automatic
}, opts___] := Module[{
    op = If[gate === Automatic, QuantumOperator["Z", {Max[xs]}], QuantumOperator[gate]]
},
    QuantumCircuitOperator[
        {
            Splice[Table[QuantumOperator["H", {q}], {q, xs}]],
            QuantumOperator[{"Controlled0", - op, DeleteCases[xs, Alternatives @@ op["OutputOrder"]]}],
            Splice[Table[QuantumOperator["H", {q}], {q, xs}]]
        },
        opts,
        "GroverDiffusion"
    ]
]

QuantumCircuitOperator[{
    name : "GroverAmplification" | "GroverAmplification0" | "GroverDiffusion" | "GroverDiffusion0" |
    "GroverPhaseAmplification" | "GroverPhaseDiffusion" | "GroverPhaseAmplification0" | "GroverPhaseDiffusion0",
    n_Integer ? Positive, gate_ : Automatic}, opts___] :=
    QuantumCircuitOperator[{name, Range[n], gate}, opts]


QuantumCircuitOperator[{
        name : "GroverOperator" | "Grover" | "GroverOperator0" | "Grover0" |
        "GroverPhaseOperator" | "GroverPhase" | "GroverPhaseOperator0" | "GroverPhase0",
        op_ ? QuantumFrameworkOperatorQ,
        gate_ : Automatic
    },
    opts___
] := QuantumCircuitOperator[
    QuantumCircuitOperator[{
        "Grover" <> If[StringContainsQ[name, "Phase"], "Phase", ""] <> "Diffusion" <> If[StringEndsQ[name, "0"], "0", ""],
        op["OutputOrder"],
        gate
    }
    ] @ op,
    opts
]


QuantumCircuitOperator[{
        name : "GroverOperator" | "Grover" | "GroverOperator0" | "Grover0" |
        "GroverPhaseOperator" | "GroverPhase" | "GroverPhaseOperator0" | "GroverPhase0",
        formula_,
        m : _Integer ? Positive | Automatic | None : Automatic,
        gate_ : Automatic
    },
    opts___
] := Enclose @ Module[{
    oracle = Confirm @ QuantumCircuitOperator[{If[StringContainsQ[name, "Phase"], "PhaseOracle", "BooleanOracle"], formula, m}], n
},
    n = Replace[m, Automatic -> Last @ oracle["OutputOrder"]];
    QuantumCircuitOperator[{
        name,
        oracle,
        QuantumOperator[Replace[gate, Automatic -> QuantumOperator[If[StringContainsQ[name, "Phase"], "Z", "NOT"], {n}]], {n}]
    }, opts]
]

indicesPattern = {KeyValuePattern[0 | 1 -> {_Integer ? Positive...}]..}

BooleanIndices[formula_, vars : _List] := Enclose @ Module[{
    esop = Confirm[BooleanConvert[formula, "ESOP"]] /. And -> List,
    indices
},
    If[ MatchQ[esop, _Function],
        esop = esop @@ vars
    ];
    esop = Replace[esop, clause : Except[_Xor] :> {clause}]  /. Xor -> List;
    esop = Replace[esop, clause : Except[_List] :> {clause}, {1}];
	indices = <|0 -> {}, 1 -> {}, KeySelect[Not @* MissingQ] @ PositionIndex @ Lookup[#, vars]|> & /@ Map[If[MatchQ[#, _Not], #[[1]] -> 0, # -> 1] &, esop, {2}];
	indices = SortBy[indices, Values /* Catenate /* Length];
    indices
]


QuantumCircuitOperator[{"BooleanOracle",
    formula_,
    varSpec : _List | _Association | Automatic : Automatic,
    n : _Integer ? NonNegative | Automatic : Automatic,
    m : _Integer ? NonNegative : 0,
    gate_ : "NOT"
}, opts___] := Enclose @ Module[{
    vars, order, indices, negIndices, isNegative = False, targetQubits
},
    vars = Replace[varSpec, {
        Automatic | {__Integer} -> Replace[BooleanVariables[formula], k_Integer :> Array[\[FormalX], k]],
        rules : KeyValuePattern[{_ -> _Integer ? Positive}] :> Keys[rules]
    }];
    order = Replace[varSpec, {rules : KeyValuePattern[{_ -> _Integer ? Positive}] :> Values[rules], Except[{__Integer}] :> Range[Length[vars]]}];
    ConfirmAssert[orderQ[order]];
    indices = ConfirmMatch[BooleanIndices[formula, vars], indicesPattern];
    negIndices = ConfirmMatch[BooleanIndices[Not[Replace[formula, bf_BooleanFunction :> bf @@ vars]], vars], indicesPattern];
    If[ Length[negIndices] < Length[indices],
        indices = negIndices;
        isNegative = True;
    ];
    indices = With[{repl = Thread[Range[Length[order]] -> order]}, Replace[indices, repl, {3}]];
    targetQubits = {If[MemberQ[order, n], First[DeleteCases[Range @@ ({0, 1} + MinMax[order]), n]], Replace[n, Automatic -> Max[order] + 1]]};

    QuantumCircuitOperator[
        Prepend[
            QuantumOperator[{"Controlled", gate, #[1] + m, #[0] + m}, targetQubits + m] & /@ indices,
            If[isNegative, QuantumOperator[gate, targetQubits + m]["Dagger"], Nothing]
        ],
        opts,
        formula
    ]
]

QuantumCircuitOperator[{"BooleanOracleR",
    formula_,
    varSpec : _List | _Association | Automatic : Automatic,
    n : _Integer ? NonNegative | Automatic : Automatic,
    m : _Integer ? NonNegative : 0,
    rotationGate : {"YRotation" | "ZRotation", _ ? NumericQ} : {"ZRotation", Pi}
}, opts___] := Enclose @ Module[{
    vars, order, indices, negIndices, isNegative = False, l, angles, targetQubit
},
    vars = Replace[varSpec, {
        Automatic | {__Integer} -> Replace[BooleanVariables[formula], k_Integer :> Array[\[FormalX], k]],
        rules : KeyValuePattern[_ -> _Integer ? Positive] :> Keys[rules]
    }];
    order = Replace[varSpec, {rules : KeyValuePattern[{_ -> _Integer ? Positive}] :> Values[rules], Except[{__Integer}] :> Range[Length[vars]]}];
    ConfirmAssert[orderQ[order]];
    indices = ConfirmMatch[BooleanIndices[formula, vars], indicesPattern];
    negIndices = ConfirmMatch[BooleanIndices[Not[Replace[formula, bf_BooleanFunction :> bf @@ vars]], vars], indicesPattern];
    If[ Length[negIndices] < Length[indices],
        indices = negIndices;
        isNegative = True;
    ];
    l = Length[order];
    angles = ConfirmMatch[BooleanGrayAngles[indices, rotationGate[[2]]], {{Repeated[{_, _Integer}, 2 ^ l]}..}];
    indices = With[{repl = Thread[Range[Length[order]] -> order]}, Replace[indices, repl, {3}]];
    targetQubit = If[MemberQ[order, n], First[DeleteCases[Range @@ ({0, 1} + MinMax[order]), n]], Replace[n, Automatic -> Max[order] + 1]];
	QuantumCircuitOperator[
        Prepend[
            Flatten @ Map[{If[#[[1]] == 0, Nothing, QuantumOperator[{rotationGate[[1]], #[[1]]}, {targetQubit + m}]], QuantumOperator["CNOT", {#[[2]], targetQubit} + m]} &, angles, {2}],
            If[isNegative, QuantumOperator[MapAt[Minus, rotationGate, {2}], {targetQubit + m}], Nothing]
        ],
        opts
    ]
]

GrayMatrix[n_] := With[{range = Range[0, 2 ^ n - 1]}, Outer[(-1)^Dot[##] &, IntegerDigits[range, 2, n], PadLeft[#, n] & /@ ResourceFunction["GrayCode"][range], 1]]

GrayOrders[n_] := ResourceFunction["SymmetricDifference"] @@@ Partition[Append[ResourceFunction["GrayCodeSubsets"][Range[n]], {}], 2, 1]

BooleanGrayAngles[indices : indicesPattern, angle_ : Pi] := KeyValueMap[
	With[{n = Length[#1], order = #1},
		Thread[{
            1 / 2 ^ n Transpose[GrayMatrix[n]] . ReplacePart[
                ConstantArray[0, 2 ^ n],
                Thread[Fold[BitSet, 0, n - Lookup[PositionIndex[order], #[1]]] + 1 & /@ #2 -> angle]
            ],
            Extract[order, GrayOrders[n]]
        }]
	] &,
    GroupBy[indices, Apply[Union]]
]

QuantumCircuitOperator[{"PhaseOracle",
    formula_,
    defaultVars : _List | Automatic : Automatic,
    n : _Integer ? NonNegative | Automatic : Automatic,
    m : _Integer ? NonNegative : 0
}, opts___] := Enclose @ Module[{
    esop = Confirm[BooleanConvert[formula, "ESOP"]] /. And -> List,
    vars = Replace[defaultVars, Automatic -> Replace[BooleanVariables[formula], k_Integer :> Array[\[FormalX], k]]],
    indices,
    k
},
    k = Replace[n, Automatic -> Length[vars]];
    If[ MatchQ[esop, _Function],
        esop = esop @@ vars
    ];
    esop = Replace[esop, clause : Except[_Xor] :> {clause}]  /. Xor -> List;
    esop = Replace[esop, clause : Except[_List] :> {clause}, {1}];
	indices = <|0 -> {}, 1 -> {}, PositionIndex @ Lookup[#, vars]|> & /@ Map[If[MatchQ[#, _Not], #[[1]] -> 0, # -> 1] &, esop, {2}];
    QuantumCircuitOperator[
        If[ #[1] === {},
            If[ #[0] === {},
                QuantumOperator[{"Identity", 2, Max[Length[vars], 1] + m}],
                QuantumOperator[{"Controlled0", - QuantumOperator["Z"], DeleteCases[k] @ #[0] + m}, {k + m}]
            ],
            If[ !MemberQ[#[0], k],
                QuantumOperator[{"Controlled", "Z", DeleteCases[k] @ #[1] + m, #[0] + m}, {k + m}],
                QuantumOperator[{"Controlled", - QuantumOperator["Z"], #[1], m + DeleteCases[k] @ #[0]}, {k + m}]
            ]
        ] & /@ indices,
        formula,
        opts
    ]
]

QuantumCircuitOperator[{"PhaseOracle", formula_, vars : KeyValuePattern[_ -> _Integer ? Positive], n : _Integer ? NonNegative : Automatic}, opts___] :=
    QuantumCircuitOperator[{"PhaseOracle", formula, Lookup[Reverse /@ Normal @ vars, Range[Max[vars]]], n}, opts]



QuantumCircuitOperator["Bell", opts___]  :=
    QuantumCircuitOperator[{QuantumOperator["H"], QuantumOperator["CNOT"]}, opts, "Bell"]


QuantumCircuitOperator["Toffoli", opts___] := QuantumCircuitOperator[{"Toffoli"}, opts]

QuantumCircuitOperator[{"Toffoli", n : _Integer ? NonNegative : 0}, opts___] := QuantumCircuitOperator[
    {
        QuantumOperator["H", {n + 3}],
        QuantumOperator["CNOT", {n + 2, n + 3}],
        QuantumOperator["T", {n + 3}]["Dagger"],
        QuantumOperator["CNOT", {n + 1, n + 3}],
        QuantumOperator["T", {n + 3}],
        QuantumOperator["CNOT", {n + 2, n + 3}],
        QuantumOperator["T", {n + 3}]["Dagger"],
        QuantumOperator["CNOT", {n + 1, n + 3}],
        QuantumOperator["T", {n + 2}]["Dagger"],
        QuantumOperator["T", {n + 3}],
        QuantumOperator["H", {n + 3}],
        QuantumOperator["CNOT", {n + 1, n + 2}],
        QuantumOperator["T", {n + 2}]["Dagger"],
        QuantumOperator["CNOT", {n + 1, n + 2}],
        QuantumOperator["T", {n + 1}],
        QuantumOperator["S", {n + 2}]
    },
    opts,
    "Toffoli"
]

QuantumCircuitOperator[{"BernsteinVaziraniOracle", secret : {(0 | 1) ...}, m : _Integer ? NonNegative : 0}, opts___] := With[{n = Length[secret]},
    QuantumCircuitOperator[
        If[MatchQ[secret, {0 ...}], Append[QuantumOperator["I", {n + 1 + m}]], Identity] @
            MapIndexed[If[#1 === 1, QuantumOperator["CNOT", {First[#2], n + 1} + m], QuantumOperator["I", #2 + m]] & , secret],
        opts,
        "BV Oracle"
    ]
]

QuantumCircuitOperator[{"BernsteinVaziraniOracle", secret_String /; StringMatchQ[secret, ("0" | "1") ...], m : _Integer ? NonNegative : 0}, opts___] :=
    QuantumCircuitOperator[{"BernsteinVaziraniOracle", Characters[secret] /. {"0" -> 0, "1" -> 1}, m}, opts]

QuantumCircuitOperator[{"BernsteinVazirani", (secret : {(0 | 1) ...}) | (secret_String /; StringMatchQ[secret, ("0" | "1") ...]), m : _Integer ? NonNegative : 0}, opts___] := With[{
    n = If[ListQ[secret], Length[secret], StringLength[secret]]
},
    QuantumCircuitOperator[{
        Splice @ Table[QuantumOperator["H", {i + m}], {i, n + 1}],
        QuantumOperator["Z", {n + 1 + m}],
        QuantumCircuitOperator[{"BernsteinVaziraniOracle", secret, m}, opts],
        Splice @ Table[QuantumOperator["H", {i + m}], {i, n}],
        Splice @ Table[QuantumMeasurementOperator[{i + m}], {i, n}]
    }]
]

QuantumCircuitOperator[{"Adder", n_Integer ? Positive, m : _Integer ? NonNegative : 0}, opts___] := QuantumCircuitOperator[
    Table[
        Splice[QuantumOperator[{"Controlled", {"PhaseShift", #}, {# + i - 1 + m}}, {n + i + m}] & /@ Range[n - i + 1]],
        {i, n}
    ],
    opts,
	"ADD"
]

QuantumCircuitOperator[name : "Fourier" | "InverseFourier", opts___] := QuantumCircuitOperator[{name, 2}, opts]

QuantumCircuitOperator[{"Fourier", n_Integer ? Positive, m : _Integer ? NonNegative : 0}, opts___] := QuantumCircuitOperator[Join[
		Catenate @ Table[{
			QuantumOperator["H", {i + m}],
			Splice[QuantumOperator[{"Controlled", {"PhaseShift", # + 1}, {# + i + m}}, {i + m}] & /@ Range[n - i]]
		},
		{i, n}],
		QuantumOperator["SWAP", {# + m, n - # + 1 + m}] & /@ Range[Floor[n / 2]]
	],
    opts,
	"QFT"
]

QuantumCircuitOperator[{"InverseFourier", n_Integer ? Positive, m : _Integer ? NonNegative : 0}] := QuantumCircuitOperator[{"Fourier", n, m}]["Dagger"]


QuantumCircuitOperator[{
    "PhaseEstimation",
    op_ ? QuantumOperatorQ /; op["InputDimensions"] === op["OutputDimensions"] && MatchQ[op["OutputDimensions"], {2 ..}] ,
    n : _Integer ? Positive : 4,
    m : _Integer ? NonNegative : 0,
    params : OptionsPattern[{"PowerExpand" -> False}]
}, opts___] :=
QuantumCircuitOperator[{
    Splice @ Table[QuantumOperator["X", {n + i + m}], {i, op["InputQudits"]}],
    Splice @ Table[QuantumOperator["H", {i + m}], {i, n}],
    With[{qo = QuantumOperator[op, op["QuditOrder"] + n + m]},
        If[ TrueQ[Lookup[{params}, "PowerExpand"]],
            Splice @ Catenate @ Table[Table[QuantumOperator[{"Controlled", qo, {i + m}}], 2 ^ (n - i)], {i, n}],
            Splice @ Table[QuantumOperator[{"Controlled", qo ^ 2 ^ (n - i), {i + m}}], {i, n}]
        ]
    ],
    QuantumCircuitOperator[{"InverseFourier", n}],
    Splice @ Table[QuantumMeasurementOperator[{i + m}], {i, n}]
},
    opts
]

QuantumCircuitOperator[{
    "PhaseEstimation",
    op_ ? QuantumCircuitOperatorQ /; op["InputDimensions"] === op["OutputDimensions"] && MatchQ[op["OutputDimensions"], {2 ..}],
    n : _Integer ? Positive : 4,
    m : _Integer ? NonNegative : 0
}, opts___] :=
QuantumCircuitOperator[{
    Splice @ Table[QuantumOperator["X", {n + i + m}], {i, op["InputQudits"]}],
    Splice @ Table[QuantumOperator["H", {i + m}], {i, n}],
    With[{qo = op["Shift", m]},
        Splice @ Catenate @ Table[Table[QuantumCircuitOperator[{"Controlled", qo, {i + m}}], 2 ^ (n - i)], {i, n}]
    ],
    QuantumCircuitOperator[{"InverseFourier", n}],
    Splice @ Table[QuantumMeasurementOperator[{i + m}], {i, n}]
},
    opts
]

QuantumCircuitOperator[{"C" | "Controlled", qc_ ? QuantumCircuitOperatorQ, control1 : _ ? orderQ | Automatic : Automatic, control0 : _ ? orderQ : {}}, opts___] :=
    QuantumCircuitOperator[If[QuantumOperatorQ[#], QuantumOperator[{"Controlled", #, control1, control0}], #] & /@ qc["Elements"], Subscript["C", qc["Label"]][control1, control0]]

QuantumCircuitOperator[{"C" | "Controlled", qc_, control1 : _ ? orderQ | Automatic : Automatic, control0 : _ ? orderQ : {}}] :=
    QuantumCircuitOperator[{"C", QuantumCircuitOperator @ FromCircuitOperatorShorthand[qc], control1, control0}]


QuantumCircuitOperator[pauliString_String] := With[{chars = Characters[pauliString]},
    QuantumCircuitOperator[MapIndexed[QuantumOperator, chars]] /; ContainsOnly[chars, {"I", "X", "Y", "Z", "H", "S", "T", "V", "P"}]
]


trotterCoeffs[l_, 1, c_ : 1] := ConstantArray[c, l]
trotterCoeffs[l_, 2, c_ : 1] := With[{s = trotterCoeffs[l, 1, c / 2]}, Join[s, Reverse[s]]]
trotterCoeffs[l_, n_ ? EvenQ, c_ : 1] := With[{p = 1 / (4 - 4 ^ (1 / (n - 1)))},
	With[{s = trotterCoeffs[l, n - 2, c p]}, Join[s, s, trotterCoeffs[l, n - 2, (1 - 4 p) c], s, s]]
]
trotterCoeffs[l_, n_ ? OddQ, c_ : 1] := trotterCoeffs[l, Round[n, 2], c]

trotterExpand[l_List, 1] := l
trotterExpand[l_List, 2] := Join[l, Reverse[l]]
trotterExpand[l_List, n_ ? EvenQ] := Catenate @ Table[trotterExpand[l, n - 2], 5]
trotterExpand[l_List, n_ ? OddQ] := trotterExpand[l, Round[n, 2]]

Trotterization[ops : {__QuantumOperator}, order : _Integer ? Positive : 1, reps : _Integer ? Positive : 1, const_ : 1] := With[{
	newOps = Thread[Times[const trotterCoeffs[Length[ops], order, 1 / reps], trotterExpand[ops, order]]]
},
	Table[newOps, reps]
]

QuantumCircuitOperator[{"Trotterization", opArgs_, args___}] := Block[{
    ops = QuantumCircuitOperator[opArgs]["Flatten"]["Operators"],
    trotterization
},
    trotterization = Map[
        QuantumOperator[Exp[- I #], "Label" -> Replace[#["Label"], Times[Longest[c__], l_] :> Subscript["R", l][2 c]]] &,
        Trotterization[ops, args],
        {2}
    ];
    QuantumCircuitOperator[
        If[ Length[trotterization] > 1,
            MapIndexed[QuantumCircuitOperator[#1, First[#2]] &, trotterization],
            Catenate[trotterization]
        ],
        "Trotterization"
    ]
]

QuantumCircuitOperator["Magic"] := QuantumCircuitOperator[{"S" -> {1, 2}, "H" -> {2}, "CNOT" -> {2, 1}}]


QuantumCircuitOperator[{"Multiplexer"| "Multiplexor", ops__} -> defaultK : _Integer ? Positive | Automatic : Automatic, opts___] := Block[{
    n = Length[{ops}],
    m, k, seq
},
    m = Ceiling[Log2[n]];
    k = Replace[defaultK, Automatic :> m + 1];
    seq = Values[<|0 -> {}, 1 -> {}, PositionIndex[#]|>] & /@ Take[Tuples[{1, 0}, m], n];
    QuantumCircuitOperator[MapThread[If[MatchQ[#1, "I" | {"I"..}], Nothing, {"C", #1, Splice[#2 /. c_Integer /; c == k :> m + 1]}] &, {{ops}, seq}], opts]
]

QuantumCircuitOperator[{"Multiplexer"| "Multiplexor", ops__}, opts___] := QuantumCircuitOperator[{"Multiplexer", ops} -> Automatic, opts]



RZY[vec_ ? VectorQ] := Block[{a, b, phi, psi, y, z},
    If[Length[vec] == 0, Return[{}]];
    {{a, phi}, {b, psi}} = AbsArg[Simplify[Normal[vec]]];
    y = Simplify[If[TrueQ[Simplify[a == b == 0]], Pi / 2, 2 ArcSin[(a - b) / Sqrt[2 (a ^ 2 + b ^ 2)]]]];
    z = Simplify[phi - psi];
    Replace[
        {If[TrueQ[z == 0], Nothing, {"RZ", z}], If[TrueQ[y == 0], Nothing, {"RY", y}]},
        {} -> {"I"}
    ]
]


multiplexer[qs_, n_, i_] := Block[{rzy, rzyDagger, qc, multiplexer, multiplexerDagger},
    rzy = RZY /@ Partition[qs["StateVector"], 2];
    rzyDagger = Reverse /@ rzy /. {r : "RZ" | "RY", angle_} :> {r, - angle};
    {multiplexer, multiplexerDagger} = {"Multiplexer", Splice[#]} & /@ {rzy, rzyDagger};
    qc = If[i === 0,
        QuantumCircuitOperator[{multiplexer, {"H", qs["Qudits"]}}],
        QuantumCircuitOperator[{multiplexer, {"Permutation", Cycles[{{n, i}}]}}]
    ];
    Sow @ If[i === 0,
        {multiplexerDagger, {"H", qs["Qudits"]}},
        {multiplexerDagger, {"Permutation", Cycles[{{n, i}}]}}
    ];
    qc[qs]
]

stateEvolution[qs_] := With[{n = qs["Qudits"]},
    FoldList[multiplexer[#1, n, #2] &, qs, Range[n - 1, 0, -1]]
]

QuantumCircuitOperator[qs_QuantumState | {"QuantumState", qs_QuantumState}] /; MatchQ[qs["Dimensions"], {2 ..}] :=
    QuantumCircuitOperator[Reverse @ Catenate @ Reap[stateEvolution[qs]][[2, 1]], qs["Label"]]["Flatten"]

QuantumCircuitOperator["QuantumState"] := QuantumCircuitOperator[{"QuantumState", QuantumState[{"UniformSuperposition", 3}]}]

