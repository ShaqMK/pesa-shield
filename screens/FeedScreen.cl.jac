"""Live feed, newest first; polls every 4s while mounted."""

import from react {
    useEffect
}
import from ..components.MessageCard {
    MessageCard
}
import from ..services.api {
    callWalker
}


def:pub FeedScreen() -> JsxElement {
    has messages: list[dict] = [],
        loaded: bool = False,
        error: str = "";

    async def loadFeed -> None {
        reply = await callWalker("WebFeed", {"limit": 50});
        error = str(reply["error"]);
        if not error {
            messages = reply["reports"] as list[dict];
            loaded = True;
        }
    }

    useEffect(lambda {
        loadFeed();
        interval = setInterval(lambda { loadFeed(); }, 4000);
        return lambda { clearInterval(interval); };
    }, []);

    return <section>
        <p style={{"color": "#666", "fontSize": "0.85rem", "margin": "0 0 0.8rem"}}>
            Forwarded messages, checked before you act. Updates every few seconds.
        </p>
        {if error {
            <p role="alert" style={{"color": "#a61b1b", "fontSize": "0.85rem"}}>{error}</p>
        }}
        {if len(messages) == 0 {
            <p style={{"color": "#888", "fontSize": "0.9rem"}}>
                {"No messages yet." if loaded else "Loading…"}
            </p>
        }}
        {for msg in messages {
            <MessageCard key={msg["id"]} message={msg}/>
        }}
    </section>;
}
