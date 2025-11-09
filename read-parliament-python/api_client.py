# ReadParliament API Client
# HTTP wrapper for Parliament Commons Votes API using requests library

import requests
from typing import TypeVar, Optional
from datetime import datetime
from config import HTTP_TIMEOUT

T = TypeVar('T')


class ApiClient:
    """
    Wrapper around requests library for Parliament API communication.
    Handles connection pooling, JSON deserialisation, and error handling.
    """

    def __init__(self, timeout: int = HTTP_TIMEOUT):
        """
        Initialise API client with connection pooling.

        Args:
            timeout: Request timeout in seconds (default: HTTP_TIMEOUT from config)
        """
        # Session for connection pooling across multiple requests
        self.session = requests.Session()
        self.timeout = timeout

    def read_json(self, url: str) -> dict:
        """
        Fetch JSON from URL and deserialise to dictionary.

        Args:
            url: Full URL to fetch

        Returns:
            Parsed JSON as dictionary

        Raises:
            requests.RequestException: On network error or HTTP error (4xx/5xx)
        """
        response = self.session.get(url, timeout=self.timeout)
        # Raise exception for HTTP error codes
        response.raise_for_status()
        return response.json()

    def _deserialise_datetime(self, date_string: str) -> datetime:
        """
        Parse ISO datetime string from API.

        Args:
            date_string: ISO format datetime (may include Z for UTC)

        Returns:
            datetime object
        """
        # Remove 'Z' suffix and parse ISO format
        cleaned = date_string.replace('Z', '+00:00')
        return datetime.fromisoformat(cleaned)

    def close(self):
        """Close HTTP session and clean up resources."""
        self.session.close()

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()
