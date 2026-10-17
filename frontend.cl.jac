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
import from .screens.ComingSoon {
    ComingSoon
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
                "padding": "0 1rem 6rem",
                "boxSizing": "border-box",
                "overflowX": "hidden",
                "fontFamily": "system-ui, -apple-system, sans-serif",
                "color": "#1a1a2e"
            }}
        >
            <header
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "minHeight": "56px"
                }}
            >
                <h1 style={{"fontSize": "1.15rem", "margin": "0"}}>Pesa Shield</h1>
                <button
                    type="button"
                    onClick={toggleLang}
                    aria-label={"Lugha: Kiswahili. Switch explanations to English" if lang == "sw" else "Language: English. Badili maelezo kuwa Kiswahili"}
                    style={{
                        "minHeight": "44px",
                        "minWidth": "88px",
                        "border": "1px solid #bbb",
                        "borderRadius": "22px",
                        "backgroundColor": "#fff",
                        "fontSize": "0.9rem"
                    }}
                >
                    {"English" if lang == "en" else "Kiswahili"}
                </button>
            </header>
            <main>
                <Routes>
                    <Route path="/" element={<FeedScreen/>}/>
                    <Route path="/message/:id" element={<MessageScreen lang={lang}/>}/>
                    <Route path="/check" element={<CheckScreen lang={lang}/>}/>
                    <Route path="/graph" element={<GraphScreen/>}/>
                    <Route
                        path="/cases"
                        element={<ComingSoon title="Cases" note="Lost money? Recovery cases arrive in a later slice."/>}
                    />
                </Routes>
            </main>
            <footer style={{"marginTop": "1.5rem", "fontSize": "0.75rem", "color": "#666", "lineHeight": "1.4"}}>
                Pesa Shield is a decision aid, not legal advice. Confirm reporting channels
                with your telco or the police before you act. Nothing is ever sent or
                reported for you.
            </footer>
        </div>
        <TabBar/>
    </Router>;
}
