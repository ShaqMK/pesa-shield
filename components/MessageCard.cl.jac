"""A single feed message card."""

def:pub MessageCard(display: str, senderDisplay: str, status: str) -> JsxElement {
    return <div
        style={{
            "padding": "0.7rem 0.9rem",
            "marginBottom": "0.5rem",
            "backgroundColor": "#f8f9fa",
            "border": "1px solid #e9ecef",
            "borderRadius": "10px",
            "minHeight": "44px"
        }}
    >
        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "0.5rem"}}>
            <strong style={{"fontSize": "0.82rem"}}>{senderDisplay}</strong>
            <span
                style={{
                    "fontSize": "0.72rem",
                    "padding": "0.15rem 0.5rem",
                    "borderRadius": "999px",
                    "backgroundColor": "#e0e0e0",
                    "color": "#555"
                }}
            >
                {status}
            </span>
        </div>
        <p style={{"margin": "0.35rem 0 0", "color": "#333", "fontSize": "0.88rem"}}>{display}</p>
    </div>;
}
