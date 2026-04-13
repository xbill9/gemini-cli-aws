# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging

import httpx
from google.adk.agents.remote_a2a_agent import DEFAULT_TIMEOUT

logger = logging.getLogger(__name__)


def create_authenticated_client(
    remote_service_url: str, timeout: float = DEFAULT_TIMEOUT
) -> httpx.AsyncClient:
    """Creates an httpx.AsyncClient for service-to-service communication.

    In an AWS ECS environment, authentication is typically handled via
    VPC security groups or internal service discovery. This client
    can be extended with custom authentication logic (e.g., SigV4) if needed.

    Args:
        remote_service_url: URL of the target service.
        timeout: Request timeout (defaults to ADK DEFAULT_TIMEOUT).

    Returns:
        An httpx.AsyncClient.
    """
    logger.info(f"Creating client for: {remote_service_url}")

    return httpx.AsyncClient(
        follow_redirects=True,
        timeout=timeout,
    )
