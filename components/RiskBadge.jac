"""Risk as a word plus a shape plus colour - never colour alone (GLOSSARY: Risk)."""

import from .theme {
    RISK
}
import from .Icon {
    Icon
}


def:pub RiskBadge(risk: str, status: str = "analysed") -> JsxElement {
    pill = {
        "display": "inline-flex",
        "alignItems": "center",
        "gap": "6px",
        "height": "26px",
        "padding": "0 10px 0 8px",
        "borderRadius": "999px",
        "fontSize": "12px",
        "fontWeight": "700",
        "whiteSpace": "nowrap",
        "boxSizing": "border-box"
    };
    if status == "analysed" and risk in RISK {
        style = RISK[risk];
        return <span style={{**pill, "backgroundColor": style["bg"], "color": style["fg"]}}>
            <Icon name={style["icon"]} size={12} color={style["fg"]}/>
            {style["label"]}
        </span>;
    }
    if status == "analysing" {
        return <span style={{**pill, "backgroundColor": "#ece6d8", "color": "#4a6260"}}>
            <span
                style={{
                    "width": "8px",
                    "height": "8px",
                    "borderRadius": "50%",
                    "backgroundColor": "#6f817d",
                    "animation": "ps-pulse 1.4s ease-in-out infinite"
                }}
            />
            Checking…
        </span>;
    }
    return <span style={{**pill, "backgroundColor": "#ece6d8", "color": "#4a6260"}}>
        {"Check failed" if status == "failed" else (status or "unknown")}
    </span>;
}
