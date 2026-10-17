"""Bottom tab bar: Feed, Check, Graph, Cases. Tap targets are at least 44px."""

import from "@jac/runtime" {
    Link,
    useLocation
}

glob TABS: list[dict[str, str]] = [
    {"to": "/", "label": "Feed"},
    {"to": "/check", "label": "Check"},
    {"to": "/graph", "label": "Graph"},
    {"to": "/cases", "label": "Cases"}
];


"""A message detail page belongs to the Feed tab."""
def isActive(path: str, target: str) -> bool {
    return path == target or (target == "/" and path.startswith("/message"));
}


def:pub TabBar() -> JsxElement {
    path: str = str(useLocation().pathname);
    return <nav
        aria-label="Main"
        style={{
            "position": "fixed",
            "left": "0",
            "right": "0",
            "bottom": "0",
            "display": "flex",
            "justifyContent": "center",
            "backgroundColor": "#ffffff",
            "borderTop": "1px solid #ddd"
        }}
    >
        <div style={{"display": "flex", "width": "100%", "maxWidth": "480px"}}>
            {for tab in TABS {
                <Link
                    key={tab["to"]}
                    to={tab["to"]}
                    aria-current={"page" if isActive(path, tab["to"]) else None}
                    style={{
                        "flex": "1",
                        "minHeight": "56px",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "textDecoration": "none",
                        "fontSize": "0.9rem",
                        "fontWeight": "600" if isActive(path, tab["to"]) else "400",
                        "color": "#1a3fb0" if isActive(path, tab["to"]) else "#555",
                        "borderTop": "3px solid " + ("#1a3fb0" if isActive(path, tab["to"]) else "transparent")
                    }}
                >
                    {tab["label"]}
                </Link>
            }}
        </div>
    </nav>;
}
