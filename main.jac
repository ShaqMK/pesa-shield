"""Pesa Shield - Entry Point.

Combines the server-side endpoints with the client-side UI.
"""

# Name every service element here so REST callers can reach it
# (see jac guide jac-sv-endpoints -> pitfalls).
import from endpoints {
    Sender,
    Message,
    IngestMessage,
    WebFeed
}

import from .frontend {
    app as ClientApp
}

def:pub app -> JsxElement {
    <ClientApp/>
}
