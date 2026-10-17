"""The client token, entered once as an "access code" and kept in
localStorage on this device only (Check and case actions need it)."""

glob TOKEN_KEY: str = "pesa_client_token";


def:pub getToken() -> str {
    return localStorage.getItem(TOKEN_KEY) or "";
}


def:pub saveToken(token: str) {
    localStorage.setItem(TOKEN_KEY, token.strip());
}
