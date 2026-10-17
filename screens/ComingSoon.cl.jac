"""Placeholder for tabs whose screens land in later slices."""

def:pub ComingSoon(title: str, note: str) -> JsxElement {
    return <section>
        <h2 style={{"fontSize": "1.05rem", "margin": "0 0 0.4rem"}}>{title}</h2>
        <p style={{"color": "#666"}}>{note}</p>
    </section>;
}
