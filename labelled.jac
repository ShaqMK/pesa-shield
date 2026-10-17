"""The labelled synthetic set's verdict cache (SPEC: Verdict caching).

config/verdict_cache.json maps cache_key(raw text) to a stored Judgement.
Only labelled messages are matched - on their exact raw text, while it is
still in hand at ingestion or Check - so live messages always hit the LLM.
"""

import os;
import json;
import hashlib;

glob _CONFIG_DIR: str = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config"),
     _cache: dict | None = None;


def config_path(name: str) -> str {
    return os.path.join(_CONFIG_DIR, name);
}


"""Cache key of a labelled synthetic message: sha256 of its exact raw text."""
def cache_key(raw_text: str) -> str {
    return hashlib.sha256(raw_text.strip().encode()).hexdigest();
}


"""The cache key if this raw message is in the labelled set, else "".

Called while the raw text is still in hand (ingestion, Check); only a hit
is stored, so live messages keep no hash of their raw text.
"""
def labelled_key(raw_text: str) -> str {
    key = cache_key(raw_text);
    return key if key in verdict_cache() else "";
}


"""Verdicts for the labelled synthetic set, keyed by cache_key(raw text)."""
def verdict_cache -> dict {
    global _cache;
    if _cache is None {
        with open(config_path("verdict_cache.json"), encoding="utf-8") as f {
            _cache = json.load(f) as dict;
        }
    }
    return _cache as dict;
}
