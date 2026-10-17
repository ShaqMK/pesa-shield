"""Pesa Shield - client app shell.

Mobile-first (360px up, a centred column on a laptop) with a bottom tab bar:
Feed, Check, Graph, Cases. One language toggle (EN/SW) switches verdict
explanations everywhere and is remembered on this device.
"""

import from "@jac/runtime" {
    Router,
    Routes,
    Route
}
import from .components.TabBar {
    TabBar
}
import from .screens.FeedScreen {
    FeedScreen
}
import from .screens.MessageScreen {
    MessageScreen
}
import from .screens.CheckScreen {
    CheckScreen
}
import from .screens.GraphScreen {
    GraphScreen
}
import from .screens.CasesScreen {
    CasesScreen
}
import from .screens.CaseScreen {
    CaseScreen
}
import from .components.Icon {
    Icon
}
import from .components.theme {
    BODY,
    DISPLAY
}

glob LANG_KEY: str = "pesa_lang";


def:pub app -> JsxElement {
    has lang: str = localStorage.getItem(LANG_KEY) or "en";

    def toggleLang(e: MouseEvent) {
        next = "sw" if lang == "en" else "en";
        localStorage.setItem(LANG_KEY, next);
        lang = next;
    }

    return <Router>
        <div
            style={{
                "maxWidth": "480px",
                "margin": "0 auto",
                "padding": "0 16px 120px",
                "boxSizing": "border-box",
                "overflowX": "hidden",
                "fontFamily": BODY,
                "color": "#173232"
            }}
        >
            <header
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "minHeight": "64px"
                }}
            >
                <h1
                    style={{
                        "display": "flex",
                        "alignItems": "center",
                        "gap": "8px",
                        "margin": "0",
                        "fontFamily": DISPLAY,
                        "fontSize": "21px",
                        "fontWeight": "700",
                        "color": "#0f3d3e"
                    }}
                >
                    <Icon name="shield" size={26} color="#0f3d3e"/>
                    Pesa Shield
                </h1>
                <button
                    type="button"
                    onClick={toggleLang}
                    aria-label={"Lugha: Kiswahili. Switch explanations to English" if lang == "sw" else "Language: English. Badili maelezo kuwa Kiswahili"}
                    style={{
                        "display": "flex",
                        "minHeight": "44px",
                        "padding": "4px",
                        "border": "1px solid #eadfc8",
                        "borderRadius": "999px",
                        "backgroundColor": "#ffffff",
                        "cursor": "pointer"
                    }}
                >
                    {for code in ["en", "sw"] {
                        <span
                            key={code}
                            style={{
                                "minWidth": "42px",
                                "display": "grid",
                                "placeItems": "center",
                                "borderRadius": "999px",
                                "fontSize": "13px",
                                "fontWeight": "700",
                                "backgroundColor": "#0f3d3e" if lang == code else "transparent",
                                "color": "#fbf6ec" if lang == code else "#6f817d"
                            }}
                        >
                            {"EN" if code == "en" else "SW"}
                        </span>
                    }}
                </button>
            </header>
            <main>
                <Routes>
                    <Route path="/" element={<FeedScreen/>}/>
                    <Route path="/message/:id" element={<MessageScreen lang={lang}/>}/>
                    <Route path="/check" element={<CheckScreen lang={lang}/>}/>
                    <Route path="/graph" element={<GraphScreen/>}/>
                    <Route path="/cases" element={<CasesScreen/>}/>
                    <Route path="/cases/:id" element={<CaseScreen lang={lang}/>}/>
                </Routes>
            </main>
            <footer style={{"marginTop": "24px", "fontSize": "12px", "color": "#6f817d", "lineHeight": "1.5", "textAlign": "center"}}>
                Pesa Shield is a decision aid, not legal advice. Confirm reporting channels
                with your telco or the police before you act. Nothing is ever sent or
                reported for you.
            </footer>
        </div>
        <TabBar/>
    </Router>;
}
