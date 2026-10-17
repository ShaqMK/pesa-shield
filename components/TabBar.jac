"""Bottom dock: Feed, Check, Graph, Cases. A floating teal bar; the active
tab is a solid amber pill. Tap targets are at least 44px."""

import from "@jac/runtime" {
    Link,
    useLocation
}
import from .Icon {
    Icon
}

glob TABS: list[dict[str, str]] = [
    {"to": "/", "label": "Feed", "icon": "feed"},
    {"to": "/check", "label": "Check", "icon": "check"},
    {"to": "/graph", "label": "Graph", "icon": "graph"},
    {"to": "/cases", "label": "Cases", "icon": "case"}
];


"""A message detail page belongs to the Feed tab, a case page to Cases."""
def isActive(path: str, target: str) -> bool {
    return path == target
    or (target == "/" and path.startswith("/message"))
    or (target == "/cases" and path.startswith("/cases/"));
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
            "padding": "0 12px calc(12px + env(safe-area-inset-bottom, 0px))",
            "pointerEvents": "none"
        }}
    >
        <div
            style={{
                "display": "grid",
                "gridTemplateColumns": "repeat(4, 1fr)",
                "gap": "4px",
                "width": "100%",
                "maxWidth": "456px",
                "padding": "6px",
                "boxSizing": "border-box",
                "borderRadius": "24px",
                "backgroundColor": "#0f3d3e",
                "boxShadow": "0 14px 30px -12px rgba(15,61,62,0.6)",
                "pointerEvents": "auto"
            }}
        >
            {for tab in TABS {
                <Link
                    key={tab["to"]}
                    to={tab["to"]}
                    aria-current={"page" if isActive(path, tab["to"]) else None}
                    style={{
                        "minHeight": "56px",
                        "borderRadius": "18px",
                        "display": "flex",
                        "flexDirection": "column",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "gap": "3px",
                        "textDecoration": "none",
                        "fontSize": "12px",
                        "fontWeight": "700",
                        "backgroundColor": "#e8a33d" if isActive(path, tab["to"]) else "transparent",
                        "color": "#0f3d3e" if isActive(path, tab["to"]) else "#a9c6c0"
                    }}
                >
                    <Icon name={tab["icon"]} size={20}/>
                    {tab["label"]}
                </Link>
            }}
        </div>
    </nav>;
}
