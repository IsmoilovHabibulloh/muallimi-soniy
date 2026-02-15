"""Rate limiting middleware using Redis."""

import time
from typing import Optional

from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

# In-memory fallback rate limiter (used when Redis is unavailable)
_rate_limit_store: dict[str, list] = {}


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Simple rate limiter for specific endpoints."""

    # Endpoint-specific limits: (max_requests, window_seconds)
    LIMITS = {
        "/api/v1/feedback": (5, 60),        # 5 per minute
        "/api/v1/admin/auth/login": (10, 300),  # 10 per 5 min
    }

    async def dispatch(self, request: Request, call_next) -> Response:
        path = request.url.path
        limit_config = None

        for pattern, config in self.LIMITS.items():
            if path.startswith(pattern) and request.method == "POST":
                limit_config = config
                break

        if limit_config:
            max_requests, window = limit_config
            client_ip = request.client.host if request.client else "unknown"
            key = f"rl:{path}:{client_ip}"

            now = time.time()
            if key not in _rate_limit_store:
                _rate_limit_store[key] = []

            # Clean old entries
            _rate_limit_store[key] = [
                t for t in _rate_limit_store[key] if t > now - window
            ]

            if len(_rate_limit_store[key]) >= max_requests:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Juda ko'p so'rovlar. Biroz kuting.",
                )

            _rate_limit_store[key].append(now)

        return await call_next(request)
