"""Pesa Shield look: deep teal, warm cream and amber, with the kanga stripe as
the one brand flourish. Colours, fonts and shared style blocks live here so
every screen draws from one palette."""

glob C: dict[str, str] = {
    "cream": "#fbf6ec",
    "paper": "#ffffff",
    "line": "#eadfc8",
    "ink": "#173232",
    "ink2": "#4a6260",
    "ink3": "#6f817d",
    "teal": "#0f3d3e",
    "teal2": "#1d5f5c",
    "tealSoft": "#e7f0ec",
    "amber": "#e8a33d",
    "amberSoft": "#fbecd0",
    "amberInk": "#8a5a0b",
    "gold": "#f3c06b",
    "mist": "#cfe3dd",
    "high": "#b23a24",
    "highBg": "#fbe3dc",
    "low": "#22694a",
    "lowBg": "#dff0e5",
    "wait": "#ece6d8"
},
     DISPLAY: str = "'Fraunces', Georgia, serif",
     BODY: str = "'DM Sans', 'Segoe UI', system-ui, sans-serif",
     STRIPE: str = "repeating-linear-gradient(90deg, #e8a33d 0 18px, #c4452d 18px 27px, #fbf6ec 27px 31px, #0f3d3e 31px 40px)",
     # Risk is a word plus a shape plus a colour - never colour alone.
     RISK: dict[str, dict[str, str]] = {
         "high": {"label": "High risk", "icon": "triangle", "bg": "#fbe3dc", "fg": "#b23a24"},
         "medium": {"label": "Medium risk", "icon": "diamond", "bg": "#fbecd0", "fg": "#8a5a0b"},
         "low": {"label": "Low risk", "icon": "circle", "bg": "#dff0e5", "fg": "#22694a"}
     },
     CARD: dict[str, str] = {
         "backgroundColor": "#ffffff",
         "borderRadius": "20px",
         "padding": "16px",
         "boxShadow": "0 1px 0 #eadfc8, 0 8px 20px -14px rgba(15,61,62,0.35)",
         "boxSizing": "border-box"
     },
     LABEL: dict[str, str] = {
         "margin": "0 0 10px",
         "fontSize": "12px",
         "fontWeight": "700",
         "letterSpacing": "0.08em",
         "textTransform": "uppercase",
         "color": "#6f817d"
     },
     TITLE: dict[str, str] = {
         "fontFamily": "'Fraunces', Georgia, serif",
         "fontSize": "28px",
         "fontWeight": "700",
         "lineHeight": "1.1",
         "color": "#0f3d3e",
         "margin": "4px 0 6px"
     },
     LEDE: dict[str, str] = {"margin": "0 0 16px", "color": "#4a6260", "fontSize": "14px"},
     BUTTON: dict[str, str] = {
         "minHeight": "52px",
         "width": "100%",
         "borderRadius": "999px",
         "border": "none",
         "display": "flex",
         "alignItems": "center",
         "justifyContent": "center",
         "gap": "8px",
         "fontSize": "15px",
         "fontWeight": "700",
         "cursor": "pointer"
     },
     PRIMARY: dict[str, str] = {"backgroundColor": "#0f3d3e", "color": "#fbf6ec"},
     QUIET: dict[str, str] = {"backgroundColor": "#ffffff", "color": "#173232", "boxShadow": "inset 0 0 0 1px #eadfc8"},
     INPUT: dict[str, str] = {
         "display": "block",
         "width": "100%",
         "boxSizing": "border-box",
         "minHeight": "48px",
         "fontSize": "16px",
         "padding": "0 14px",
         "border": "none",
         "borderRadius": "14px",
         "backgroundColor": "#ffffff",
         "boxShadow": "inset 0 0 0 1px #eadfc8",
         "color": "#173232"
     },
     BACK: dict[str, str] = {
         "display": "inline-flex",
         "alignItems": "center",
         "gap": "4px",
         "minHeight": "44px",
         "color": "#4a6260",
         "fontWeight": "500",
         "textDecoration": "none"
     },
     ALERT: dict[str, str] = {"color": "#b23a24", "fontSize": "14px"},
     MUTED: dict[str, str] = {"color": "#6f817d", "fontSize": "14px"};
