"""Small line icons drawn as inline SVG (24px grid), so the app needs no icon
font or image files."""


def:pub Icon(name: str, size: int = 18, color: str = "currentColor") -> JsxElement {
    box = {"width": str(size) + "px", "height": str(size) + "px", "flex": "none", "display": "block"};
    if name == "shield" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M12 2.5 4 5.5v6c0 5 3.4 8.6 8 10 4.6-1.4 8-5 8-10v-6l-8-3Z" fill={color}/>
        </svg>;
    }
    if name == "check" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M12 2.5 4 5.5v6c0 5 3.4 8.6 8 10 4.6-1.4 8-5 8-10v-6l-8-3Z" fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round"/>
            <path d="m8.5 12 2.5 2.5 4.5-5" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>;
    }
    if name == "feed" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <rect x="3.5" y="4" width="17" height="16" rx="4" fill="none" stroke={color} strokeWidth="2"/>
            <path d="M7.5 9.5h9M7.5 14h6" stroke={color} strokeWidth="2" strokeLinecap="round"/>
        </svg>;
    }
    if name == "graph" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <circle cx="12" cy="12" r="3" fill={color}/>
            <circle cx="5" cy="6" r="2.2" fill="none" stroke={color} strokeWidth="2"/>
            <circle cx="19" cy="6" r="2.2" fill="none" stroke={color} strokeWidth="2"/>
            <circle cx="12" cy="20" r="2.2" fill="none" stroke={color} strokeWidth="2"/>
            <path d="m6.7 7.4 3 2.6M17.3 7.4l-3 2.6M12 15v2.8" stroke={color} strokeWidth="2"/>
        </svg>;
    }
    if name == "case" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M4 7.5A2.5 2.5 0 0 1 6.5 5H10l2 2h5.5A2.5 2.5 0 0 1 20 9.5v8a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 17.5v-10Z" fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round"/>
        </svg>;
    }
    if name == "triangle" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M12 3 22 20H2L12 3Z" fill={color}/>
            <path d="M12 9.5v4.5" stroke="#ffffff" strokeWidth="2.2" strokeLinecap="round"/>
            <circle cx="12" cy="16.8" r="1.2" fill="#ffffff"/>
        </svg>;
    }
    if name == "diamond" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M12 2.5 21.5 12 12 21.5 2.5 12 12 2.5Z" fill={color}/>
        </svg>;
    }
    if name == "circle" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <circle cx="12" cy="12" r="9" fill={color}/>
        </svg>;
    }
    if name == "cross" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <circle cx="12" cy="12" r="9.5" fill={color}/>
            <path d="m8.8 8.8 6.4 6.4M15.2 8.8l-6.4 6.4" stroke="#ffffff" strokeWidth="2" strokeLinecap="round"/>
        </svg>;
    }
    if name == "stop" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <circle cx="12" cy="12" r="9" fill="none" stroke={color} strokeWidth="2.2"/>
            <path d="M5.8 5.8 18.2 18.2" stroke={color} strokeWidth="2.2"/>
        </svg>;
    }
    if name == "back" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M15 5 8 12l7 7" fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>;
    }
    if name == "link" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"/>
        </svg>;
    }
    if name == "phone" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <rect x="6.5" y="2.5" width="11" height="19" rx="3" fill="none" stroke={color} strokeWidth="2"/>
            <path d="M10.5 18h3" stroke={color} strokeWidth="2" strokeLinecap="round"/>
        </svg>;
    }
    if name == "badge" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <rect x="3" y="6" width="18" height="12" rx="3" fill="none" stroke={color} strokeWidth="2"/>
            <path d="M7 12h10" stroke={color} strokeWidth="2" strokeLinecap="round"/>
        </svg>;
    }
    if name == "bulb" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3Z" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>;
    }
    if name == "copy" {
        return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
            <rect x="8" y="8" width="12" height="12" rx="3" fill="none" stroke={color} strokeWidth="2"/>
            <path d="M16 5.5A2.5 2.5 0 0 0 13.5 3H6a3 3 0 0 0-3 3v7.5A2.5 2.5 0 0 0 5.5 16" fill="none" stroke={color} strokeWidth="2"/>
        </svg>;
    }
    # "tick"
    return <svg viewBox="0 0 24 24" style={box} aria-hidden="true">
        <path d="m5 12.5 4.5 4.5L19 7.5" fill="none" stroke={color} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>;
}
