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
import subprocess
from urllib.parse import urlparse

import httpx
from google.adk.agents.remote_a2a_agent import DEFAULT_TIMEOUT
from google.auth.exceptions import DefaultCredentialsError
from google.auth.transport.requests import AuthorizedSession, Request
from google.oauth2.credentials import Credentials
from google.oauth2.id_token import fetch_id_token_credentials

logger = logging.getLogger(__name__)


class _IdentityTokenAuth(httpx.Auth):
    """Internal helper for Google identity token authentication."""

    requires_request_body = False

    def __init__(self, remote_service_url: str):
        parsed_url = urlparse(remote_service_url)
        self.root_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
        self.session = None

    def auth_flow(self, request):
        id_token = None

        # 1. Try to use existing session token
        if self.session and self.session.credentials:
            id_token = self.session.credentials.token

        # 2. If no token, attempt to fetch from Identity Provider or Local gcloud
        if not id_token:
            try:
                # Attempt metadata fetch (works on some cloud environments)
                credentials = fetch_id_token_credentials(audience=self.root_url)
                credentials.refresh(Request())
                self.session = AuthorizedSession(credentials)
                id_token = self.session.credentials.token
            except (DefaultCredentialsError, Exception) as e:
                logger.debug(f"Cloud credentials not found, falling back to local: {e}")

            if not id_token:
                # Local development fallback: use gcloud CLI
                id_token = self._get_local_identity_token()

        if id_token:
            request.headers["Authorization"] = f"Bearer {id_token}"
        else:
            logger.warning(f"Failed to obtain identity token for {self.root_url}")

        yield request

    def _get_local_identity_token(self) -> str | None:
        """Fetches identity token from gcloud CLI for local development."""
        try:
            # Use -q to avoid interactive prompts
            token = (
                subprocess.check_output(
                    ["gcloud", "auth", "print-identity-token", "-q"],
                    stderr=subprocess.DEVNULL,
                )
                .decode()
                .strip()
            )

            if token:
                # Also try to fetch refresh token to populate session for consistency
                try:
                    refresh_token = (
                        subprocess.check_output(
                            ["gcloud", "auth", "print-refresh-token", "-q"],
                            stderr=subprocess.DEVNULL,
                        )
                        .decode()
                        .strip()
                    )
                    self.session = AuthorizedSession(
                        Credentials(
                            token=token, id_token=token, refresh_token=refresh_token
                        )
                    )
                except subprocess.SubprocessError:
                    pass
                return token
        except (subprocess.SubprocessError, FileNotFoundError):
            logger.error(
                "gcloud CLI not found or not authenticated. Run 'gcloud auth login'."
            )
        return None


def create_authenticated_client(
    remote_service_url: str, timeout: float = DEFAULT_TIMEOUT, force_bypass: bool = False
) -> httpx.AsyncClient:
    """Creates an httpx.AsyncClient with Google identity token authentication.

    Identity tokens are automatically sourced from the environment:
      - Locally: Uses 'gcloud auth print-identity-token'.
      - Cloud: Uses the environment's metadata server.

    Args:
        remote_service_url: URL of the target service.
        timeout: Request timeout (defaults to ADK DEFAULT_TIMEOUT).
        force_bypass: If True, skip authentication regardless of URL.

    Returns:
        An authenticated httpx.AsyncClient.
    """
    parsed_url = urlparse(remote_service_url)
    # Check if it's a local or internal service call
    skip_auth = force_bypass or \
                "localhost" in remote_service_url or \
                "127.0.0.1" in remote_service_url or \
                "." not in parsed_url.netloc or \
                "lambda-url" in remote_service_url or \
                ".on.aws" in remote_service_url

    if skip_auth:
        logger.info(f"Bypassing authentication for: {remote_service_url}")
        # Return a client with NO default headers to prevent leakage
        return httpx.AsyncClient(
            base_url=remote_service_url,
            follow_redirects=True,
            timeout=timeout,
            headers={}, # Explicitly clear headers
        )

    return httpx.AsyncClient(
        base_url=remote_service_url,
        auth=_IdentityTokenAuth(remote_service_url),
        follow_redirects=True,
        timeout=timeout,
    )
