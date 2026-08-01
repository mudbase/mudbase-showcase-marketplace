"""Mirrors the zod schemas in ../../web/src/components/auth/RegisterForm.tsx
and LoginForm.tsx. Both `client` and `freelancer` are self-signup roles here
(unlike the ecommerce showcase's hidden-role customer-only signup) — the
register form exposes a real role selector, matching the reference app.
"""

from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator

AppRole = Literal["client", "freelancer"]


class RegisterFormValues(BaseModel):
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)
    email: EmailStr
    password: str = Field(min_length=8)
    role: AppRole
    agreed_to_terms: bool

    @field_validator("agreed_to_terms")
    @classmethod
    def _must_agree(cls, value: bool) -> bool:
        if not value:
            raise ValueError("You must agree to the Terms of Service and Privacy Policy.")
        return value


class LoginFormValues(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)
