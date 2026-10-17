"""Pesa Shield - Entry Point.

Combines the server-side endpoints with the client-side UI.
"""

# Name every service element here so REST callers can reach it
# (see jac guide jac-sv-endpoints -> pitfalls).
import from graph {
    Sender,
    Message,
    Pattern,
    PayTarget
}
import from endpoints {
    IngestMessage,
    WebFeed,
    Seed,
    Reset
}
import from guard {
    GuardMessage,
    GuardPending,
    Check
}

cl {
    import from .frontend {
        app as ClientApp
    }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
