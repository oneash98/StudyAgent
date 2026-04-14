from __future__ import annotations

import re
from contextlib import contextmanager
from typing import Iterator

import sqlalchemy as sa
from omop_alchemy import create_engine_with_dependencies

_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def safe_identifier(value: str, label: str) -> str:
    if not value or not _IDENTIFIER_RE.match(value):
        raise RuntimeError(f"invalid_{label}")
    return value


def create_engine(engine_name: str) -> sa.Engine:
    if not engine_name:
        raise RuntimeError("omop_db_engine_unconfigured")
    return create_engine_with_dependencies(engine_name, future=True)


@contextmanager
def connect(engine_name: str) -> Iterator[sa.Connection]:
    engine = create_engine(engine_name)
    with engine.connect() as connection:
        yield connection
