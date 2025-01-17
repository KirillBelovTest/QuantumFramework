Package["Wolfram`QuantumFramework`"]

PackageScope["CircuitDraw"]



$DefaultGray = RGBColor[0.537254, 0.537254, 0.537254];

$GateDefaultBoundaryStyle = {
	"H" -> RGBColor[0.368417, 0.506779, 0.709798],
	"T" | "S" -> RGBColor[0.922526, 0.385626, 0.209179],
	"X" | "Y" | "Z" | "NOT" -> RGBColor[0.880722, 0.611041, 0.142051],
	"P"[_] | (Superscript | Power)["P"[_], _] | "PhaseShift"[_] | _Integer -> RGBColor[0.560181, 0.691569, 0.194885],
	Subscript["R", _][_] -> RGBColor[0.528488, 0.470624, 0.701351],
	"Measurement" -> RGBColor[0.7367, 0.358, 0.5030],
	"Channel" -> $DefaultGray,
	_ -> $DefaultGray
};

$GateDefaultBackgroundStyle = Append[
	MapAt[Directive[#, Opacity[0.15]] &, Most[$GateDefaultBoundaryStyle], {All, 2}],
	_ -> Directive[RGBColor[0.898039, 0.898039, 0.898039], Opacity[.5]]
]

$DefaultFontStyleOptions = {FontFamily -> "Roboto", FontSize -> 11, FontColor -> Black};

$DefaultWireLabelStyle = {FontSlant -> Italic, FontSize -> 10, FontColor -> $DefaultGray};

positionCorners[{vpos_, hpos_}, size_, vGapSize_, hGapSize_] := Thread[{MinMax[hGapSize hpos] + size / 2 {-1, 1}, MinMax[-vpos vGapSize] + size / 2 {-1, 1}}]

simpleLabel[label_] := Replace[label,
	{
		Subscript["R", _][_] -> "Rotate",
		_Integer | "PhaseShift"[_] -> "PhaseShift"
	}
]

selectNonOverlappingIntervals[l_List] := Fold[If[Length[#1] == 0 || #1[[-1, 2]] < #2[[1]], Append[#1, #2], #1] &, {}, l]

Options[drawGate] := DeleteDuplicatesBy[First] @ Join[{
	"RotateGateLabel" -> Automatic,
	"ShowGateLabels" -> True,
	"GateLabels" -> {},
	"Size" -> .75,
	"VerticalGapSize" -> 1,
	"HorizontalGapSize" -> 1,
	"GateBackgroundStyle" -> Automatic,
	"GateBoundaryStyle" -> Automatic,
	"GateShapeFunction" -> Automatic,
	"ShowConnectors" -> False,
	"WireStyle" -> Automatic
},
	Options[Style], Options[Rectangle]
];
drawGate[pos : {vpos_, hpos_}, label_, opts : OptionsPattern[]] := Block[{
	size = OptionValue["Size"],
	vGapSize = OptionValue["VerticalGapSize"],
	hGapSize = OptionValue["HorizontalGapSize"],
	rotateLabel = Replace[OptionValue["RotateGateLabel"], {True | Automatic -> If[Length[vpos] > 1, Pi / 2, 0], False | None -> 0}],
	labelStyleOpts = {Background -> Transparent, FilterRules[{opts}, Options[Style]], $DefaultFontStyleOptions},
	gateBackgroundStyle = DeleteDuplicatesBy[First] @
		Flatten[{Replace[OptionValue["GateBackgroundStyle"], Automatic -> $GateDefaultBackgroundStyle], $GateDefaultBackgroundStyle}],
	gateBoundaryStyle = DeleteDuplicatesBy[First] @
		Flatten[{Replace[OptionValue["GateBoundaryStyle"], Automatic -> $GateDefaultBoundaryStyle], $GateDefaultBoundaryStyle}],
	gateShapeFunction = Replace[label, Flatten[{Replace[OptionValue["GateShapeFunction"], Automatic -> Nothing], _ -> None}]],
	corners,
	center,
	vposIndex = PositionIndex[Developer`ToList[vpos]],
	gateLabelsQ = TrueQ[OptionValue["ShowGateLabels"]],
	connectorsQ = TrueQ[OptionValue["ShowConnectors"]],
	backgroundStyle,
	boundaryStyle,
	drawControlWires,
	wireStyle = Replace[OptionValue["WireStyle"], Automatic -> Directive[$DefaultGray, Opacity[.3]]]
},
	corners = positionCorners[pos, size, vGapSize, hGapSize];
	center = Mean[corners];
	backgroundStyle = Replace[label, gateBackgroundStyle];
	boundaryStyle = Replace[label, gateBoundaryStyle];
	drawControlWires = Function[{
		boundaryStyle,
		Line[{
			{center[[1]], - vGapSize #1[[1]] - size Switch[#2[[1]], "NOT", 1 / 5, "SWAP", 0, "1" | "0", 1 / 8, _, 1 / 2]},
			{center[[1]], - vGapSize #1[[2]] + size Switch[#2[[2]], "NOT", 1 / 5, "SWAP", 0, "1" | "0", 1 / 8, _, 1 / 2]}
		}]
	}];
	Replace[label, {
		_ /; gateShapeFunction =!= None -> gateShapeFunction[center, label, hGapSize hpos, - vGapSize vpos],
		Subscript["C", subLabel_][control1_, control0_] :> Block[{
			target = DeleteCases[vpos, Alternatives @@ Join[control1, control0]],
			control = Join[control1, control0],
			index
		},
			index = First /@ PositionIndex[target];
			{
				Replace[subLabel, {
					subSubLabels_CircleTimes :> With[{
						labels = Catenate @ Replace[List @@ subSubLabels, {Superscript[subSubLabel_, CircleTimes[n_Integer]] :> Table[subSubLabel, n], subSubLabel_ :> {subSubLabel}}, {1}]
					},
						{
							With[{boundaryStyles = Replace[labels, gateBoundaryStyle, {1}]},
								If[	Equal @@ boundaryStyles,
									backgroundStyle = Replace[First[labels], gateBackgroundStyle];
									boundaryStyle = First[boundaryStyles];
								]
							];
							Map[drawGate[{{#}, hpos}, labels[[index[#]]], opts] &, target],
							drawControlWires[#, {If[MemberQ[target, #[[1]]], labels[[index[#[[1]]]]], "1"], If[MemberQ[target, #[[2]]], labels[[index[#[[2]]]]], "1"]}] & /@ Partition[Sort[vpos], 2, 1]
						} /; Length[labels] == Length[target]
					],
					Superscript[subSubLabel_, CircleTimes[n_Integer]] /; n == Length[target] :>
						{
							backgroundStyle = Replace[subSubLabel, gateBackgroundStyle];
							boundaryStyle = Replace[subSubLabel, gateBoundaryStyle];
							MapIndexed[drawGate[{{#1}, hpos}, subSubLabel, opts] &, target],
							drawControlWires[#, {If[MemberQ[target, #[[1]]], subSubLabel, "1"], If[MemberQ[target, #[[2]]], subSubLabel, "1"]}] & /@ Partition[Sort[vpos], 2, 1]
						},
					_ :> {
						backgroundStyle = Replace[subLabel, gateBackgroundStyle];
						boundaryStyle = Replace[subLabel, gateBoundaryStyle];
						Which[
							Length[target] == 1,
							{
								drawGate[{target, hpos}, subLabel, opts],
								drawControlWires[#, {
									If[MemberQ[target, #[[1]]], subLabel, "1"],
									If[MemberQ[target, #[[2]]], subLabel, "1"]
								}] & /@ Partition[Sort[vpos], 2, 1]
							},
							MatchQ[subLabel, "SWAP"],
							{
								Map[drawGate[{{#}, hpos}, "*", opts] &, target],
								drawControlWires[#, {
									If[MemberQ[target, #[[1]]], subLabel, "1"],
									If[MemberQ[target, #[[2]]], subLabel, "1"]
								}] & /@ Partition[Sort[vpos], 2, 1]
							},
							True,
							{
								Map[drawGate[{{#}, hpos}, Subscript[subLabel, #], opts] &, target],
								drawControlWires[#, {
									If[MemberQ[target, #[[1]]], Subscript[subLabel, #[[1]]], "1"],
									If[MemberQ[target, #[[2]]], Subscript[subLabel, #[[2]]], "1"]
								}] & /@ Partition[Sort[vpos], 2, 1]
							}
						]
					}
				}],
				drawGate[{{#}, hpos}, "1",
					"GateBoundaryStyle" -> {"1" -> boundaryStyle},
					"GateBackgroundStyle" -> {"1" -> Directive[backgroundStyle, Opacity[.8]]},
					opts
				] & /@ control1,
				drawGate[{{#}, hpos}, "0",
					"GateBoundaryStyle" -> {"0" -> boundaryStyle},
					"GateBackgroundStyle" -> {"0" -> backgroundStyle},
					opts
				] & /@ control0
			}
		],
		Subscript["R", subSubLabels_CircleTimes][angle_] :> With[{
			labels = Catenate @ Replace[List @@ subSubLabels, {Superscript[subSubLabel_, CircleTimes[n_Integer]] :> Table[subSubLabel, n], subSubLabel_ :> {subSubLabel}}, {1}]
		},
			With[{index = First /@ PositionIndex[vpos]}, {
				Map[drawGate[{{#1}, hpos}, Subscript["R", labels[[index[#1]]]][angle], opts] &, vpos],
				drawControlWires[#, {Subscript["R", labels[[index[#[[1]]]]]][angle], Subscript["R", labels[[index[#[[2]]]]]][angle]}] & /@ Partition[Sort[vpos], 2, 1]
			}] /; Length[labels] == Length[vpos]
		],
		Subscript["R", Superscript[subSubLabel_, CircleTimes[n_Integer]]][angle_] /; n == Length[vpos] :> {
			MapIndexed[drawGate[{{#1}, hpos}, Subscript["R", subSubLabel][angle], opts] &, vpos],
			drawControlWires[#, {Subscript["R", subSubLabel][angle], Subscript["R", subSubLabel][angle]}] & /@ Partition[Sort[vpos], 2, 1]
		},
		Subscript["R", subLabel : Except[_Subscript]][angle_] /; Length[vpos] > 1 :> {
			Map[drawGate[{{#}, hpos}, Subscript["R", Subscript[subLabel, #]][angle], opts] &, vpos],
			drawControlWires[#, {Subscript["R", Subscript[subLabel, #[[1]]]][angle], Subscript["R", Subscript[subLabel, #[[2]]]][angle]}] & /@ Partition[Sort[vpos], 2, 1]
		},
		"I" :> {
			wireStyle,
			Line[{center - {size / 2, 0}, center + {size / 2, 0}}]
		},
		"1" :> {
			wireStyle,
			Line[{center - {size / 2, 0}, center - {size / 8, 0}}],
			Line[{center + {size / 8, 0}, center + {size / 2, 0}}],
			EdgeForm[Replace["1", gateBoundaryStyle]],
			FaceForm[Replace["1", gateBackgroundStyle]],
			Disk[center, size / 8]
		},
		"0" :> {
			wireStyle,
			Line[{center - {size / 2, 0}, center - {size / 8, 0}}],
			Line[{center + {size / 8, 0}, center + {size / 2, 0}}],
			EdgeForm[Replace["0", gateBoundaryStyle]],
			FaceForm[Transparent],
			Disk[center, size / 8]},
		"NOT" :> {
			wireStyle,
			Line[{center - {size / 2, 0}, center - {size / 5, 0}}],
			Line[{center + {size / 5, 0}, center + {size / 2, 0}}],
			EdgeForm[Replace["NOT", gateBoundaryStyle]],
			FaceForm[Replace["NOT", gateBackgroundStyle]],
			Disk[center, size / 5],
			Replace["NOT", gateBackgroundStyle], Opacity[1],
			Line[{center + size / 5 {-1, 0}, center + size / 5 {1, 0}}], Line[{center + size / 5 {0, -1}, center + size / 5 {0, 1}}]
		},
		"SWAP" :> With[{bottom = {center[[1]], -vpos[[1]] vGapSize}, top = {center[[1]], -vpos[[-1]] vGapSize}}, {
			wireStyle,
		    Line[{bottom, top}],
			$DefaultGray, Opacity[0.8], Thickness[Medium],
			MapThread[drawGate[{{#1}, {#2}}, "*", opts] &, {vpos, hpos}]
		}],
		"*" :> {
			wireStyle,
		    Line[{center - {size / 2, 0}, center + {size / 2, 0}}],
			$DefaultGray, Opacity[0.8], Thickness[Medium],
		    Line[{center + size / 5 {-1, -1} / Sqrt[2], center + size / 5 {1, 1} / Sqrt[2]}],
		    Line[{center + size / 5 {1, -1} / Sqrt[2], center + size / 5 {-1, 1} / Sqrt[2]}]
		},
		"RootSWAP" :> With[{bottom = {center[[1]], -vpos[[1]] vGapSize}, top = {center[[1]], -vpos[[-1]] vGapSize}}, {
			wireStyle,
		    Line[{bottom - {size / 2, 0}, bottom + {size / 2, 0}}],
		    Line[{top - {size / 2, 0}, top + {size / 2, 0}}],
		    Line[{bottom, center + {0, size / 5}}],
			Line[{center - {0, size / 5}, top}],
			$DefaultGray, Opacity[0.8], Thickness[Medium],
		    Line[{bottom + size / 5 {-1, -1} / Sqrt[2], bottom + size / 5 {1, 1} / Sqrt[2]}],
		    Line[{bottom + size / 5 {1, -1} / Sqrt[2], bottom + size / 5 {-1, 1} / Sqrt[2]}],
			Line[{top + size / 5 {-1, -1} / Sqrt[2], top + size / 5 {1, 1} / Sqrt[2]}],
		    Line[{top + size / 5 {1, -1} / Sqrt[2], top + size / 5 {-1, 1} / Sqrt[2]}],
			EdgeForm[Replace[subLabel, gateBoundaryStyle]],
			FaceForm[Replace[subLabel, gateBackgroundStyle]],
			Rectangle[center - size / 5, center + size / 5, Sequence @@ FilterRules[{opts}, Options[Rectangle]]],
			If[gateLabelsQ, Text[Style["1 / 2", labelStyleOpts], center], Nothing]
		}],
		"\[Pi]"[perm__] :> {
			wireStyle,
			MapThread[Line[{{center[[1]] - size / 2, - #1 vGapSize}, {center[[1]] + size / 2, - #2 vGapSize}}] &, {vpos, vpos[[{perm}]]}]
		},
		"PhaseShift"[n_] | n_Integer :> {
			EdgeForm[Replace[label, gateBoundaryStyle]],
			FaceForm[Replace[label, gateBackgroundStyle]],
			Disk[center, size / 2],
			If[connectorsQ, {FaceForm[Directive[$DefaultGray, Opacity[1]]], Disk[#, size / 32] & /@ {{center[[1]] - size / 2, - vGapSize #}, {center[[1]] + size / 2, - vGapSize #}} & /@ vpos}, Nothing],
			If[gateLabelsQ, Rotate[Text[Style[Superscript[If[TrueQ[Negative[n]], -Pi, Pi], InputForm[2 ^ (1 - Abs[n])]], labelStyleOpts], center], rotateLabel], Nothing]
		},
		subLabels_CircleTimes :> With[{
			labels = Catenate @ Replace[List @@ subLabels, {Superscript[subSubLabel_, CircleTimes[n_Integer]] :> Table[subSubLabel, n], subSubLabel_ :> {subSubLabel}}, {1}]
		},
			{
				With[{boundaryStyles = Replace[labels, gateBoundaryStyle, {1}]},
					If[	Equal @@ boundaryStyles,
						boundaryStyle = First[boundaryStyles];
					]
				];
				With[{index = First /@ PositionIndex[vpos]}, {
					Map[drawGate[{{#1}, hpos}, labels[[index[#1]]], opts] &, vpos],
					drawControlWires[#, {labels[[index[#[[1]]]]], labels[[index[#[[1]]]]]}] & /@ Partition[Sort[vpos], 2, 1]
				}]
			} /; Length[labels] == Length[vpos]
		],
		Superscript[subLabel_, CircleTimes[n_Integer]] /; n == Length[vpos] :> {
			boundaryStyle = Replace[subLabel, gateBoundaryStyle];
			MapIndexed[drawGate[{{#1}, hpos}, subLabel, opts] &, vpos],
			drawControlWires[#, {subLabel, subLabel}] & /@ Partition[Sort[vpos], 2, 1]
		},
		SuperDagger[subLabel_] | subLabel_ :> {
			EdgeForm[Replace[subLabel, gateBoundaryStyle]],
			FaceForm[Replace[subLabel, gateBackgroundStyle]],
			Rectangle[Sequence @@ corners, Sequence @@ FilterRules[{opts}, Options[Rectangle]]],
			If[connectorsQ, {FaceForm[Directive[$DefaultGray, Opacity[1]]], Disk[#, size / 32] & /@ {{center[[1]] - size / 2, - vGapSize #}, {center[[1]] + size / 2, - vGapSize #}} & /@ vpos}, Nothing],
			If[gateLabelsQ, Rotate[Text[Style[Replace[label, OptionValue["GateLabels"]], labelStyleOpts], center], rotateLabel], Nothing]
		}
	}]
]

Options[drawMeasurement] = Join[{
	"Size" -> .75,
	"VerticalGapSize" -> 1,
	"HorizontalGapSize" -> 1,
	"Arrowhead" -> 0.005,
	"MeasurementBackgroundStyle" -> Replace["Measurement", $GateDefaultBackgroundStyle],
	"MeasurementBoundaryStyle" -> Replace["Measurement", $GateDefaultBoundaryStyle],
	"MeasurementWirePosition" -> Top,
	"ShowMeasurementWire" -> True,
	"ShowConnectors" -> False
},
	Options[Style],
	Options[Rectangle]
];
drawMeasurement[pos : {vpos_, hpos_}, width_, opts : OptionsPattern[]] := Block[{
	size = OptionValue["Size"],
	vGapSize = OptionValue["VerticalGapSize"],
	hGapSize = OptionValue["HorizontalGapSize"],
	arrowhead = OptionValue["Arrowhead"],
	showMeasurementWireQ = OptionValue["ShowMeasurementWire"],
	connectorsQ = TrueQ[OptionValue["ShowConnectors"]],
	corners,
	center
},
	corners = positionCorners[pos, size, vGapSize, hGapSize];
	center = Mean[corners];
	{
		EdgeForm[OptionValue["MeasurementBoundaryStyle"]], FaceForm[OptionValue["MeasurementBackgroundStyle"]],
		Rectangle[Sequence @@ corners, Sequence @@ FilterRules[{opts}, Options[Rectangle]]],

		Thickness[Small],
		Table[Line[{center + 0.25 size {Cos[a], Sin[a]} - {0, size / 4}, center + 0.35 size {Cos[a], Sin[a]} - {0, size / 4}}], {a, Pi Subdivide[.2, .8, 7]}],
		Thickness[Medium],
		With[{a = 0.35 Pi}, Line[{center - {0, size / 4}, center + 0.5 size {Cos[a], Sin[a]} - {0, size / 4}}]],
		If[connectorsQ, {FaceForm[Directive[$DefaultGray, Opacity[1]]], Disk[#, size / 32] & /@ {{center[[1]] - size / 2, - vGapSize #}, {center[[1]] + size / 2, - vGapSize #}} & /@ vpos}, Nothing],
		If[	showMeasurementWireQ, {
			$DefaultGray,
			If[ OptionValue["MeasurementWirePosition"] === Top, {
				Line[{{center[[1]], corners[[2, 2]]}, {center[[1]], - size / 4 - size / 32}}]
			}, {
				Line[{{center[[1]], corners[[1, 2]]}, {center[[1]], - vGapSize width - vGapSize + size / 4 + size / 32}}]
			}
			],
			EdgeForm[Directive[$DefaultGray, Opacity[0.3]]], FaceForm[Directive[$DefaultGray, Opacity[0.8]]],
			If[ OptionValue["MeasurementWirePosition"] === Top,
				Polygon[{center[[1]], - size / 4 - size / 32} + size # / 4 & /@ {{- 1 / 2, 0}, {1 / 2, 0}, {0, 1}}],
				Polygon[{center[[1]], - vGapSize width - vGapSize + size / 4 + size / 32} + size # / 4 & /@ {{- 1 / 2, 0}, {1 / 2, 0}, {0, -1}}]
			]
		},
			Nothing
		]
	}
]

Options[drawChannel] = Join[{
	"Size" -> .75,
	"VerticalGapSize" -> 1,
	"HorizontalGapSize" -> 1,
	"ChannelBackgroundStyle" -> Replace["Channel", $GateDefaultBackgroundStyle],
	"ChannelBoundaryStyle" -> Directive[Dotted, Replace["Channel", $GateDefaultBoundaryStyle]],
	"ShowConnectors" -> False,
	"ShowGateLabels" -> True,
	"GateLabels" -> {},
	"RotateGateLabel" -> Automatic
},
	Options[Style],
	Options[Rectangle]
];
drawChannel[pos : {vpos_, hpos_}, label_, opts : OptionsPattern[]] := Block[{
	size = OptionValue["Size"],
	vGapSize = OptionValue["VerticalGapSize"],
	hGapSize = OptionValue["HorizontalGapSize"],
	connectorsQ = TrueQ[OptionValue["ShowConnectors"]],
	gateLabelsQ = TrueQ[OptionValue["ShowGateLabels"]],
	rotateLabel = Replace[OptionValue["RotateGateLabel"], {True | Automatic -> If[Length[vpos] > 1, Pi / 2, 0], False | None -> 0}],
	labelStyleOpts = {Background -> Transparent, FilterRules[{opts}, Options[Style]], $DefaultFontStyleOptions},
	corners,
	center
},
	corners = positionCorners[pos, size, vGapSize, hGapSize];
	center = Mean[corners];
	{
		EdgeForm[OptionValue["ChannelBoundaryStyle"]], FaceForm[OptionValue["ChannelBackgroundStyle"]],
		Rectangle[Sequence @@ corners, Sequence @@ FilterRules[{opts}, Options[Rectangle]]],
		If[connectorsQ, {FaceForm[Directive[$DefaultGray, Opacity[1]]], Disk[#, size / 32] & /@ {{center[[1]] - size / 2, - vGapSize #}, {center[[1]] + size / 2, - vGapSize #}} & /@ vpos}, Nothing],
		If[gateLabelsQ, Rotate[Text[Style[Replace[label, OptionValue["GateLabels"]], labelStyleOpts], center], rotateLabel], Nothing]
	}
]

Options[drawWires] = {"Size" -> .75,
	"VerticalGapSize" -> 1, "HorizontalGapSize" -> 1,
	"ShortOuterWires" -> True, "ShowWireEndpoints" -> False,
	"WireStyle" -> Automatic
};
drawWires[wires_List, OptionsPattern[]] := With[{
	size = OptionValue["Size"],
	vGapSize = OptionValue["VerticalGapSize"],
	hGapSize = OptionValue["HorizontalGapSize"],
	height = Max[wires[[All, 2, 1]]],
	endpointsQ = TrueQ[OptionValue["ShowWireEndpoints"]]
},
	{
		Replace[OptionValue["WireStyle"], Automatic -> Directive[$DefaultGray, Opacity[.3]]],
		Map[ Apply[With[{
			points = If[TrueQ[OptionValue["ShortOuterWires"]],
					{{hGapSize #1[[1]] + size / 2, - vGapSize #1[[2]]}, {hGapSize #2[[1]] - size / 2, - vGapSize #2[[2]]}},
					Which[
						#1[[1]] == 0,
						{{hGapSize - size / 2, - vGapSize #1[[2]]}, {hGapSize #2[[1]] - size / 2, - vGapSize #2[[2]]}},
						#2[[1]] == height,
						{{hGapSize #1[[1]] + size / 2, - vGapSize #1[[2]]}, {hGapSize (#2[[1]] - 1) + size / 2, - vGapSize #2[[2]]}},
						True,
						{{hGapSize #1[[1]] + size / 2, - vGapSize #1[[2]]}, {hGapSize #2[[1]] - size / 2, - vGapSize #2[[2]]}}
					]
				]},
			{
				Line[points],
				If[endpointsQ, {Opacity[1], PointSize[Scaled[0.003]], Point /@ points} , Nothing]
	 		}
		 ] &],
			wires
		]
	}
]

Options[drawMeasurementWire] = Join[{
	"Size" -> .75,
	"VerticalGapSize" -> 1,
	"HorizontalGapSize" -> 1,
	"MeasurementWirePosition" -> Top,
	"MeasurementWireLabel" -> "c",
	"ShowGateLabels" -> True,
	"WireStyle" -> Automatic
}, Options[Style]];
drawMeasurementWire[x_, width_, opts : OptionsPattern[]] := With[{
	size = OptionValue["Size"],
	vGapSize = OptionValue["VerticalGapSize"],
	hGapSize = OptionValue["HorizontalGapSize"],
	label = OptionValue["MeasurementWireLabel"],
	gateLabelsQ = OptionValue["ShowGateLabels"]
}, With[{
	y = If[OptionValue["MeasurementWirePosition"] === Top, 0, - vGapSize width - vGapSize]
},
	{
		{
			Replace[OptionValue["WireStyle"], Automatic -> Directive[$DefaultGray, Opacity[.3]]],
			Line[{{size / 2, y - size / 32}, {hGapSize x - size / 2, y - size / 32}}],
			Line[{{size / 2, y + size / 32}, {hGapSize x - size / 2, y + size / 32}}]
		},
		If[	gateLabelsQ,
			Replace[label, {
				Placed[l_, p_] :> Text[Style[l, Background -> Transparent, FilterRules[{opts}, Options[Style]], $DefaultWireLabelStyle],
					{Replace[p, {Left -> 3 size / 8, Right -> hGapSize x - 3 size / 8}], y},
					Replace[p, {Left -> {1, 0}, Right -> {-1, 0}}]
				],
				l_ :> Text[Style[l, Background -> Transparent, FilterRules[{opts}, Options[Style]], $DefaultWireLabelStyle], {3 size / 8, y}, {1, 0}]
			}],
			Nothing
		]
	}
]]

Options[drawWireLabels] = Join[{"Size" -> .75, "VerticalGapSize" -> 1, "HorizontalGapSize" -> 1}, Options[Style]];
drawWireLabels[wireLabels_, width_, height_, pad_, opts : OptionsPattern[]] := Block[{
	size = OptionValue["Size"],
	vGapSize = OptionValue["VerticalGapSize"],
	hGapSize = OptionValue["HorizontalGapSize"],
	labels
},
	labels = Replace[wireLabels, {
		rules : {_Rule...} | _Association :> ReplacePart[Range[width], Cases[Normal[rules], HoldPattern[i_Integer /; 1 <= i <= width -> _]]],
		l : Placed[Automatic, _] :> Table[l, width],
		Automatic -> Range[width],
		None -> {}
	}];
    labels = MapIndexed[{label, index} |-> With[{i = vGapSize (pad + First[index])},
        Map[
            Replace[{
                Placed[l_, p_] :> With[{
					text = Style[Replace[l, Automatic -> i], Background -> Transparent, FilterRules[{opts}, Options[Style]], $DefaultWireLabelStyle],
					ps = Developer`ToList[Replace[p, Automatic -> {Left, Center}]]
				},
                    Text[
                        text,
                        Total @ Replace[If[MemberQ[#, Left | Right], #, Append[#, Left]] & @
								If[MemberQ[#, Center], #, Append[#, Center]] & @ ps, {
							Center -> {0, -i},
                            Above -> {0, size / 8},
                            Below -> {0, - size / 8},
                            Left -> {3 size / 8, 0},
                            Right -> {hGapSize height - 3 size / 8, 0}
                        },
						{1}],
						If[MemberQ[ps, Right], {-1, 0}, {1, 0}]
					]
				],
                l_ :> Text[Style[l, Background -> Transparent, FilterRules[{opts}, Options[Style]], $DefaultWireLabelStyle], {3 size / 8, -i}, {1, 0}]
                }
            ],
            Developer`ToList[label]
        ]
    ],
        labels
    ];
    labels
]

Options[drawOutline] = Join[{"Size" -> .75, "VerticalGapSize" -> 1, "HorizontalGapSize" -> 1, "OutlineStyle" -> Directive[
	EdgeForm[Directive[Dashing[{Tiny, Tiny}], $DefaultGray, Opacity[0.8]]],
	FaceForm[RGBColor[0.898039, 0.898039, 0.898039, .3]]
	]},
	Options[Rectangle]
];
drawOutline[width_, height_, pad_, opts : OptionsPattern[]] := With[{size = OptionValue["Size"], vGapSize = OptionValue["VerticalGapSize"], hGapSize = OptionValue["HorizontalGapSize"]},
	{OptionValue["OutlineStyle"], Rectangle[{hGapSize - 5 size / 8, - pad - vGapSize / 2}, {hGapSize (height - 1) + 5 size / 8, - pad - vGapSize width - vGapSize / 2}, Sequence @@ FilterRules[{opts}, Options[Rectangle]]]}
]

Options[drawLabel] = Join[{"VerticalGapSize" -> 1, "HorizontalGapSize" -> 1}, Options[Style]];
drawLabel[label_, height_, pad_, opts : OptionsPattern[]] := With[{vGapSize = OptionValue["VerticalGapSize"], hGapSize = OptionValue["HorizontalGapSize"]},
	Text[Style[label, Background -> Transparent, FilterRules[{opts}, Options[Style]], FontFamily -> "Times"], {hGapSize height / 2, - vGapSize (pad + 1 / 2)}]
]

Options[drawBarrier] = {"Size" -> .75, "VerticalGapSize" -> 1, "HorizontalGapSize" -> 1, "BarrierStyle" -> Automatic, "WireStyle" -> Automatic}
drawBarrier[{vpos_, hpos_}, OptionsPattern[]] := Block[{
	size = OptionValue["Size"], vGapSize = OptionValue["VerticalGapSize"], hGapSize = OptionValue["HorizontalGapSize"],
	x
},
	x = hGapSize First[hpos];
	{
		Replace[OptionValue["WireStyle"], Automatic -> Directive[$DefaultGray, Opacity[.3]]],
		Line[{{x - size / 2, - vGapSize #}, {x + size / 2, - vGapSize #}}] & /@ vpos,

		Replace[OptionValue["BarrierStyle"], Automatic -> Directive[$DefaultGray, Dashed, Opacity[.8], Thickness[Large]]],
		Line[Map[{x, #} &, List @@ Interval @@ (vGapSize {- # + 1 / 2, - # - 1 / 2} & /@ vpos), {2}]]
	}
]

Options[circuitDraw] := DeleteDuplicatesBy[First] @ Join[
	{
		"WireLabels" -> Automatic, "MeasurementWireLabel" -> "c", "ShowWires" -> True, "ShowLabel" -> False,
		"ShowMeasurementWire" -> True, "ShowEmptyWires" -> True,
		"ShowOutline" -> False,
		"SubcircuitLevel" -> 1,
		"GateOverlap" -> False,
		"MeasurementWirePosition" -> Top,
		"HorizontalGapSize" -> 1,
		"ShowGateLabels" -> True,
		"SubcircuitOptions" -> {}
	},
	Options[drawGate], Options[drawMeasurement], Options[drawChannel],
	Options[drawWires], Options[drawWireLabels],
	Options[drawOutline], Options[drawBarrier],
	Options[Style]
];
circuitDraw[circuit_QuantumCircuitOperator, opts : OptionsPattern[]] := Block[{
	numGates = circuit["Gates"],
	width = circuit["Width"],
	order = circuit["InputOrder"],
	level = Max[OptionValue["SubcircuitLevel"]],
	hGapSize = OptionValue["HorizontalGapSize"],
	span,
	pad,
	height,
	orders = #["InputOrder"] & /@ circuit["Operators"],
	labels = #["Label"] & /@ circuit["Operators"],
	positions,
	gatePositions,
	wires,
	emptyWiresQ = TrueQ[OptionValue["ShowEmptyWires"]],
	showMeasurementWireQ = TrueQ[OptionValue["ShowMeasurementWire"]] && circuit["Measurements"] > 0,
	labelCount = 0,
	labelCounter,
	gateLabelsQ = TrueQ[OptionValue["ShowGateLabels"]]
},
	labelCounter = ReplaceAll[None :> (labelCount++; Subscript["U", labelCount])];
	span = If[showMeasurementWireQ, width, Max[0, #2 - #1 + 1] & @@ MinMax @ order];
	pad = width - span;
	positions = circuitPositions[circuit, level, MatchQ[OptionValue["GateOverlap"], Automatic | True]];
	height = Max[0, positions] + 1;
	wires = circuitWires[circuit];
	If[ !emptyWiresQ,
		wires = DeleteCases[wires, _[_, _, i_ /; ! MemberQ[order, i]]]
	];
	gatePositions = MapThread[With[{gateOrder = circuitElementOrder[#1, width]}, {gateOrder, #2[[gateOrder]]}] &, {circuit["FullElements"], positions[[All, 2]]}];
	wires = Replace[wires, _[from_, to_, i_] :> {{If[from == 0, 0, positions[[from, 2, i]]], i}, {If[to == -1, height, positions[[to, 1, i]] + 1], i}}, {1}];
	{
		If[TrueQ[OptionValue["ShowOutline"]], drawOutline[If[emptyWiresQ, width, span], height, pad, FilterRules[{opts}, Options[drawOutline]]], Nothing],
		If[TrueQ[OptionValue["ShowWires"]], drawWires[wires, FilterRules[{opts}, Options[drawWires]]], Nothing],
		If[showMeasurementWireQ, drawMeasurementWire[height, width, FilterRules[{opts}, Options[drawMeasurementWire]]], Nothing],
		MapThread[
			Which[
				BarrierQ[#1],
				drawBarrier[#2, FilterRules[{opts}, Options[drawBarrier]]],
				QuantumCircuitOperatorQ[#1],
				If[ level > 0,
					Translate[
						circuitDraw[#1,
							OptionValue["SubcircuitOptions"],
							"SubcircuitLevel" -> level - 1,
							"WireLabels" -> None, "ShowOutline" -> True, "ShowLabel" -> True,
							"ShowMeasurementWire" -> False, "ShowEmptyWires" -> False, "ShortOuterWires" -> False,
							opts
						],
						{hGapSize Max[#3[[#1["InputOrder"]]]], 0}
					],
					drawGate[#2, labelCounter @ #1["Label"], FilterRules[{opts}, Options[drawGate]]]
				],
				QuantumMeasurementOperatorQ[#1],
				drawMeasurement[#2, width, FilterRules[{opts}, Options[drawMeasurement]]],
				QuantumChannelQ[#1],
				drawChannel[#2, labelCounter @ #1["Label"], FilterRules[{opts}, Options[drawChannel]]],
				True,
				drawGate[#2, labelCounter @ #1["Label"], FilterRules[{opts}, Options[drawGate]]]
			] &,
			{circuit["FullElements"], gatePositions, positions[[All, 1]]}
		],
		drawWireLabels[
			If[emptyWiresQ, Identity, Replace[Automatic -> Range[width - span + 1, width]]] @ OptionValue["WireLabels"],
			If[emptyWiresQ, width, span], height, If[emptyWiresQ, 0, pad],
			FilterRules[{opts}, Options[drawWireLabels]]
		],
		If[TrueQ[OptionValue["ShowLabel"]], drawLabel[Replace[circuit["Label"], None -> ""], height, pad, FilterRules[{opts}, Options[drawLabel]]], Nothing]
	}
]

circuitPositions[circuit_QuantumCircuitOperator, level_Integer : 1, overlapQ : True | False : False] := With[{width = circuit["Width"]},
	Rest @ FoldList[
		Block[{
			order = circuitElementOrder[#2, width],
			gatePos = #1[[2]],
			ranges = #1[[3]],
			shift,
			overlapShift = Function[x, If[! overlapQ, NestWhile[# + 1 &, 0, ContainsAny[Lookup[ranges, x + #, {}], order] &], 0]]
		},
			shift = Which[
				BarrierQ[#2],
				ReplacePart[ConstantArray[0, width], Thread[order -> 1]],
				QuantumMeasurementOperatorQ[#2],
				ReplacePart[ConstantArray[0, width], Thread[Range[Max[order]] -> 1]],
				level > 0 && QuantumCircuitOperatorQ[#2],
				ReplacePart[ConstantArray[0, width], Thread[Range @@ MinMax[order] -> Max[Replace[circuitPositions[#2, level - 1, overlapQ], {{___, {_, o_}} :> o, _ -> 0}]]]],
				True,
				ReplacePart[ConstantArray[0, width], Thread[order -> 1]]
			];
			{
				gatePos = Which[
					BarrierQ[#2],
					SubsetMap[With[{x = Max[#]}, overlapShift[x] + ConstantArray[x, Length[order]]] &, gatePos, List /@ order],
					QuantumMeasurementOperatorQ[#2],
					SubsetMap[ConstantArray[Max[#], Length[#]] &, gatePos, List /@ Range[Max[order]]],
					True,
					SubsetMap[With[{x = Max[gatePos[[Span @@ MinMax[order]]]]}, overlapShift[x] + ConstantArray[x, Length[order]]] &, gatePos, List /@ order]
				],
				gatePos + shift,
				Merge[{ranges, Max[gatePos[[order]]] -> Range @@ MinMax[order]}, Apply[Union]]
			}
		] &,
		{ConstantArray[0, width], ConstantArray[0, width], <|0 -> {}|>},
		circuit["FullElements"]
	][[All, ;; 2]]
]

circuitWires[qc_QuantumCircuitOperator] := Block[{
	width = qc["Width"], orders
},
	orders = Select[circuitElementOrder[#, width], Positive] & /@ qc["FullElements"];
	Catenate @ ReplacePart[{-1, _, 2} -> -1] @ FoldPairList[
		{prev, order} |-> Block[{next = prev},
			next[[ order ]] = Max[prev] + 1;
			{DirectedEdge[prev[[#]], next[[#]], #] & /@ order, next}
		],
		Table[0, width],
		Append[orders, Range[width]]
	]
]

Options[CircuitDraw] := Join[Options[circuitDraw], Options[Graphics]];
CircuitDraw[circuit_QuantumCircuitOperator, opts : OptionsPattern[]] := If[
	And @@ Equal @@@ Map[Select[GreaterThan[0]], circuit["Orders"], {2}],
	Graphics[
		circuitDraw[
			circuit,
			FilterRules[{opts}, Options[circuitDraw]],
			RoundingRadius -> 0.1
		],
		FilterRules[{opts}, Options[Graphics]]
	],
	Show[QuantumCircuitOperator["Magic"]["Icon"] /. {_RGBColor -> Gray, rect_Rectangle :> {EdgeForm[Dotted], rect}}, ImageSize -> 64]
]

