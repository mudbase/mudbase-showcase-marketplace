"""Auth flows: register (client or freelancer role — a real selector, see
app/schemas/auth.py), login, logout.
"""

import asyncio
from typing import Any

from app.mudbase_client import login_sync, logout_sync, register_with_role_sync
from app.schemas.auth import AppRole


async def register(
    role: AppRole,
    email: str,
    password: str,
    first_name: str,
    last_name: str,
    agreed_to_terms: bool,
) -> dict[str, Any]:
    return await asyncio.to_thread(
        register_with_role_sync,
        role,
        email,
        password,
        first_name,
        last_name,
        agreed_to_terms,
    )


async def login(email: str, password: str) -> dict[str, Any]:
    return await asyncio.to_thread(login_sync, email, password)


async def logout(access_token: str) -> None:
    await asyncio.to_thread(logout_sync, access_token)
