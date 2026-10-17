"""Pesa Shield - Entry Point.

Combines the server-side endpoints with the client-side UI.
"""

# Name every service element here so REST callers can reach it
# (see jac guide jac-sv-endpoints -> pitfalls).
import from model { Sender, Message, Pattern, PayTarget }
import from endpoints { IngestMessage, WebFeed, GetMessage, Seed, Reset }
import from guard { GuardMessage, GuardPending, Check }
import from rings { GraphView, NodeMessages }
import from recovery {
    StartCase,
    GetCase,
    ListCases,
    EditCase,
    ApproveCase,
    DiscardCase
}

import "./styles/global.css";
import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    return <ClientApp/>;
}
