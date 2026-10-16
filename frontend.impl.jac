"""Implementations for the Pesa Shield frontend component."""

impl app.loadFeed -> None {
    result = await root spawn WebFeed(limit=50);
    messages = [r for r in result.reports];
}
