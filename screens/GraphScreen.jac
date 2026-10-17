"""Graph: pay targets and the senders who asked people to pay them, drawn as
a small hand-written SVG (at most 20 nodes). Rings are labelled in words,
not colour alone. Tapping a node lists its messages."""

import from react {
    useEffect
}
import from ..components.MessageCard {
    MessageCard
}
import from ..components.Icon {
    Icon
}
import from ..components.theme {
    CARD,
    LABEL,
    TITLE,
    LEDE,
    ALERT,
    MUTED
}
import from ..services.api {
    callWalker
}

glob WIDTH: int = 340,
     CLUSTER_HEIGHT: int = 220,
     ORBIT: int = 80,
     # Unit offsets for up to 8 senders around a target (no trig needed):
     # upper arc and sides first, keeping the target's label below it clear.
     SPOKES: list[list[float]] = [
         [0.0, -1.0], [0.87, -0.5], [-0.87, -0.5], [1.0, 0.35],
         [-1.0, 0.35], [0.45, -0.9], [-0.45, -0.9], [0.0, 1.0]
     ];


"""Node id -> [x, y]: one cluster per pay target, its senders around it."""
def layout(nodes: list[dict[str, any]], edges: list[dict[str, any]]) -> dict[str, list[float]] {
    pos: dict[str, list[float]] = {};
    targets = [n for n in nodes if n["kind"] == "target"];
    for (i, t) in enumerate(targets) {
        cx = WIDTH / 2;
        cy = i * CLUSTER_HEIGHT + CLUSTER_HEIGHT / 2 + 10;
        pos[t["id"]] = [cx, cy];
        spoke = 0;
        for e in edges {
            if e["to"] == t["id"] and not pos[e["from"]] {
                offset = SPOKES[spoke % len(SPOKES)];
                pos[e["from"]] = [cx + offset[0] * ORBIT, cy + offset[1] * ORBIT];
                spoke += 1;
            }
        }
    }
    return pos;
}


"""Baseline of a node's text: the count inside the circle, or the label below it."""
def textY(pos: dict[str, list[float]], n: dict[str, any], below: bool) -> float {
    y = float(pos[str(n["id"])][1]);
    if not below {
        return y + 5.0;
    }
    return y + (48.0 if n["kind"] == "target" else 40.0);
}


def:pub GraphScreen() -> JsxElement {
    has view: dict[str, any] | None = None,
        selected: dict[str, any] | None = None,
        messages: list[dict[str, any]] = [],
        error: str = "";

    async def loadGraph -> None {
        reply = await callWalker("GraphView", {});
        error = str(reply["error"]);
        if not error {
            view = (reply["reports"] as list[dict[str, any]])[0];
        }
    }

    async def openNode(picked: dict[str, any]) -> None {
        selected = picked;
        reply = await callWalker("NodeMessages", {"node_id": picked["id"]});
        messages = reply["reports"] as list[dict[str, any]];
    }

    useEffect(lambda {
        loadGraph();
        interval = setInterval(lambda { loadGraph(); }, 8000);
        return lambda { clearInterval(interval); };
    }, []);

    if error {
        return <p role="alert" style={ALERT}>{error}</p>;
    }
    if not view {
        return <p style={MUTED}>Loading…</p>;
    }
    data = view as dict[str, any];
    rings = data["rings"] as list[dict[str, any]];
    nodes = data["nodes"] as list[dict[str, any]];
    edges = data["edges"] as list[dict[str, any]];
    pos = layout(nodes, edges);
    targetCount = len([n for n in nodes if n["kind"] == "target"]);
    height = max(targetCount, 1) * CLUSTER_HEIGHT;

    return <section style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
        <div>
        <h2 style={TITLE}>Scam rings</h2>
        <p style={{**LEDE, "margin": "0"}}>
            A ring is three or more numbers asking people to pay the same till,
            paybill, number or link. Only medium and high risk messages count.
        </p>
        </div>
        {if len(rings) == 0 {
            <p style={MUTED}>No rings yet.</p>
        }}
        {for r in rings {
            <div key={r["ring_id"]} style={{**CARD, "display": "flex", "flexDirection": "column", "gap": "12px"}}>
                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "8px"}}>
                    <strong style={{"fontFamily": "'Fraunces', Georgia, serif", "fontSize": "19px", "color": "#0f3d3e"}}>
                        Ring around {r["target"]}
                    </strong>
                    <span style={{"display": "inline-flex", "alignItems": "center", "gap": "6px", "height": "26px", "padding": "0 10px 0 8px", "borderRadius": "999px", "fontSize": "12px", "fontWeight": "700", "backgroundColor": "#fbe3dc", "color": "#b23a24"}}>
                        <Icon name="triangle" size={12} color="#b23a24"/>
                        Ring
                    </span>
                </div>
                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "8px"}}>
                    <div style={{"backgroundColor": "#fbf6ec", "borderRadius": "14px", "padding": "8px 10px"}}>
                        <strong style={{"display": "block", "fontSize": "20px", "color": "#0f3d3e"}}>{str(r["senders"])}</strong>
                        <span style={{"fontSize": "12px", "color": "#6f817d"}}>numbers</span>
                    </div>
                    <div style={{"backgroundColor": "#fbf6ec", "borderRadius": "14px", "padding": "8px 10px"}}>
                        <strong style={{"display": "block", "fontSize": "20px", "color": "#0f3d3e"}}>{str(r["reports"])}</strong>
                        <span style={{"fontSize": "12px", "color": "#6f817d"}}>reports</span>
                    </div>
                </div>
            </div>
        }}
        {if len(nodes) > 0 {
            <svg
                viewBox={"0 0 " + str(WIDTH) + " " + str(height)}
                width="100%"
                role="img"
                aria-label="Graph of senders linked to pay targets"
                style={{"display": "block", "backgroundColor": "#ffffff", "borderRadius": "20px", "boxShadow": "0 1px 0 #eadfc8"}}
            >
                {for (i, e) in enumerate(edges) {
                    <line
                        key={"e" + str(i)}
                        x1={pos[e["from"]][0]}
                        y1={pos[e["from"]][1]}
                        x2={pos[e["to"]][0]}
                        y2={pos[e["to"]][1]}
                        stroke="#e8a33d"
                        strokeDasharray="5 5"
                        strokeWidth={1.5 + e["count"]}
                    />
                }}
                {for n in nodes {
                    <g
                        key={n["id"]}
                        role="button"
                        tabIndex={0}
                        aria-label={("Ring pay target " if n["ring_id"] else "") + str(n["label"]) + ", " + str(n["count"]) + " reports"}
                        onClick={lambda { openNode(n); }}
                        style={{"cursor": "pointer"}}
                    >
                        <circle
                            cx={pos[n["id"]][0]}
                            cy={pos[n["id"]][1]}
                            r={32 if n["kind"] == "target" else 26}
                            fill={("#b23a24" if n["ring_id"] else "#0f3d3e") if n["kind"] == "target" else "#fbe3dc"}
                            stroke={"#e8a33d" if selected and selected["id"] == n["id"] else ("#fbf6ec" if n["kind"] == "target" else "#b23a24")}
                            strokeWidth={4 if selected and selected["id"] == n["id"] else 2}
                        />
                        <text
                            x={pos[n["id"]][0]}
                            y={textY(pos, n, False)}
                            textAnchor="middle"
                            fontSize="13"
                            fontWeight="700"
                            fill={"#fbf6ec" if n["kind"] == "target" else "#b23a24"}
                        >
                            {str(n["count"])}
                        </text>
                        <text
                            x={pos[n["id"]][0]}
                            y={textY(pos, n, True)}
                            textAnchor="middle"
                            fontSize="11"
                            fontWeight="500"
                            fill="#173232"
                        >
                            {("RING · " if n["ring_id"] else "") + str(n["label"])}
                        </text>
                    </g>
                }}
            </svg>
        }}
        {if selected {
            <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>
                <h3 style={{**LABEL, "margin": "0"}}>
                    Messages for {selected["label"]}
                </h3>
                {for m in messages {
                    <MessageCard key={m["id"]} message={m}/>
                }}
            </div>
        }}
    </section>;
}
