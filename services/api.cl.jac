"""Client-side walker calls.

Plain fetch, not `root spawn`: the jac-client runtime caches read-only
walker results for 60s, which would freeze the polled feed and a message
still `analysing`. Server rejections arrive as HTTP 200 with the reason in
`data.error` (jac 0.16.7); both shapes come back here as `error`.
"""

async def:pub callWalker(name: str, body: dict, timeoutMs: int = 60000) -> dict {
    payload: any = None;
    signals: any = globalThis["AbortSignal"];
    try {
        response: any = await fetch(
            "/walker/" + name,
            {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify(body),
                "signal": signals.timeout(timeoutMs)
            }
        );
        payload = await response.json();
    } except Exception {
        return {"reports": [], "error": "network: no answer from Pesa Shield, try again"};
    }
    if not payload or not payload["ok"] {
        reason = payload["error"]["message"] if payload and payload["error"] else "request failed";
        return {"reports": [], "error": str(reason)};
    }
    data = payload["data"] or {};
    if data["error"] {
        return {"reports": [], "error": str(data["error"])};
    }
    return {"reports": data["reports"] or [], "error": ""};
}
