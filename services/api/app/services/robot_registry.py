from __future__ import annotations

from datetime import datetime
from typing import Dict, Iterable

from ..schemas.robot import RobotEndpoint, RobotStatus


class RobotRegistry:
    def __init__(self) -> None:
        self._endpoints: Dict[str, RobotEndpoint] = {}
        self._status: Dict[str, RobotStatus] = {}

    def register_endpoint(self, endpoint: RobotEndpoint) -> None:
        self._endpoints[endpoint.id] = endpoint

    def update_status(self, status: RobotStatus) -> None:
        status.last_seen = status.last_seen or datetime.utcnow()
        self._status[status.id] = status

    def list_endpoints(self) -> Iterable[RobotEndpoint]:
        return self._endpoints.values()

    def get_status(self, robot_id: str) -> RobotStatus | None:
        return self._status.get(robot_id)

    def list_status(self) -> Iterable[RobotStatus]:
        return self._status.values()


robot_registry = RobotRegistry()
