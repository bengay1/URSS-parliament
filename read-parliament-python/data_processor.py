# ReadParliament Data Processor
# Fetches parliamentary division data from API and processes votes

from models import DivisionDat, MemberDat, DivisionDto, MemberDto, Vote
from api_client import ApiClient
from config import DIVISION_START, DIVISION_END, DATE_START, DATE_END, API_BASE_URL
from datetime import datetime
from typing import Optional


class DataProcessor:
    """
    Core business logic for fetching and processing parliamentary voting data.
    Orchestrates API calls, data aggregation, and vote tracking.
    """

    def __init__(self):
        """
        Initialise data processor with empty storage dictionaries.
        """
        # divisions[DivisionId] = DivisionDat
        self.divisions: dict[int, DivisionDat] = {}

        # members[MemberId] = MemberDat (contains member metadata & votes)
        self.members: dict[int, MemberDat] = {}

        # API client for HTTP requests
        self.api_client = ApiClient()

    def process_divisions(self):
        """
        Main orchestrator method.
        Fetches divisions from API and processes vote data.
        """
        self.read_divisions()

    def read_divisions(self):
        """
        Fetch divisions from Parliament API (723-1809).
        Parse JSON responses into internal data structures.
        Aggregate member votes by category.
        Filter by date range.

        Prints progress to console (division numbers as fetched).
        Logs errors for missing/invalid divisions.
        """
        print(f"Fetching divisions {DIVISION_START}-{DIVISION_END-1}...")

        # Parse date range for filtering
        date_start = datetime.fromisoformat(DATE_START)
        date_end = datetime.fromisoformat(DATE_END)

        for division_no in range(DIVISION_START, DIVISION_END):
            print(f"{division_no}  ", end="", flush=True)

            try:
                # Construct API URL
                url = f"{API_BASE_URL}/division/{division_no}.json"

                # Fetch JSON from API
                raw_data = self.api_client.read_json(url)

                # Parse JSON to DivisionDto
                division_dto = self._parse_division_dto(raw_data)

                # Filter by date range
                if division_dto.Date < date_start or division_dto.Date > date_end:
                    continue

                # Store division metadata
                self.divisions[division_dto.DivisionId] = DivisionDat(
                    division_id=division_dto.DivisionId,
                    date=division_dto.Date,
                    bill_name=division_dto.Title
                )

                # Aggregate votes by category
                self._add_member_vote_category(
                    division_dto.DivisionId,
                    division_dto.Ayes,
                    Vote.Aye
                )
                self._add_member_vote_category(
                    division_dto.DivisionId,
                    division_dto.AyeTellers,
                    Vote.AyeTeller
                )
                self._add_member_vote_category(
                    division_dto.DivisionId,
                    division_dto.Noes,
                    Vote.No
                )
                self._add_member_vote_category(
                    division_dto.DivisionId,
                    division_dto.NoTellers,
                    Vote.NoTeller
                )
                self._add_member_vote_category(
                    division_dto.DivisionId,
                    division_dto.NoVoteRecorded,
                    Vote.Missing
                )

            except requests.RequestException:
                # Division API call failed (404, timeout, etc)
                print(f"\n{division_no} does not exist")
                continue
            except Exception as e:
                # JSON parse error or other unexpected error
                print(f"\n{division_no} error: {e}")
                continue

        print(f"\n\nProcessed {len(self.divisions)} divisions")
        print(f"Tracked {len(self.members)} MPs")

    def _filter_dataclass_fields(self, data: dict, dataclass_type) -> dict:
        """
        Filter dictionary to only include fields defined in dataclass.
        Ignores unknown fields from API responses gracefully.

        Args:
            data: Raw dictionary (likely from JSON)
            dataclass_type: Target dataclass (e.g., DivisionDto, MemberDto)

        Returns:
            Dictionary with only fields that exist in dataclass
        """
        # Get field names from dataclass definition
        if hasattr(dataclass_type, '__dataclass_fields__'):
            allowed_fields = set(dataclass_type.__dataclass_fields__.keys())
        else:
            # Not a dataclass, return as-is
            return data

        # Filter dictionary to only include allowed fields
        return {k: v for k, v in data.items() if k in allowed_fields}

    def _parse_division_dto(self, raw_data: dict) -> DivisionDto:
        """
        Parse raw JSON dictionary to DivisionDto.
        Handles datetime string conversion and nested MemberDto lists.
        Ignores unknown fields from API (only uses fields defined in dataclass).

        Args:
            raw_data: Raw JSON dictionary from API

        Returns:
            DivisionDto instance with parsed data
        """
        # Parse datetime string to datetime object
        if isinstance(raw_data.get('Date'), str):
            raw_data['Date'] = self.api_client._deserialise_datetime(raw_data['Date'])

        # Recursively parse member lists (JSON -> MemberDto objects)
        for field in ['Ayes', 'AyeTellers', 'Noes', 'NoTellers', 'NoVoteRecorded']:
            if field in raw_data and raw_data[field]:
                raw_data[field] = [
                    MemberDto(**self._filter_dataclass_fields(member_data, MemberDto))
                    for member_data in raw_data[field]
                ]
            else:
                raw_data[field] = []

        # Filter to only include fields defined in DivisionDto
        filtered_data = self._filter_dataclass_fields(raw_data, DivisionDto)
        return DivisionDto(**filtered_data)

    def _add_member_vote_category(
        self,
        division_id: int,
        members: list[MemberDto],
        vote: Vote
    ):
        """
        Add votes for a single vote category (Ayes, Noes, AyeTellers, etc).
        Creates member records if new.
        Handles duplicate votes with error logging.

        Args:
            division_id: Division ID for this vote
            members: List of MemberDto from API (may be empty)
            vote: Vote code (Aye, No, AyeTeller, NoTeller, Missing)
        """
        if not members:
            # Empty member list for this category
            return

        for member in members:
            member_id = member.MemberId

            # Create member record if first encounter
            if member_id not in self.members:
                # Extract firstname & surname from full name
                name_parts = member.Name.split(maxsplit=1)
                first_name = name_parts[0]
                surname = name_parts[1] if len(name_parts) > 1 else ""

                # Create MemberDat record
                self.members[member_id] = MemberDat(
                    member_id=member_id,
                    first_name=first_name,
                    surname=surname,
                    party=member.PartyAbbreviation or member.Party,
                    division_votes={}
                )

            # Add vote for this division
            # Note: duplicates should not occur in well-formed data
            if division_id in self.members[member_id].division_votes:
                msg = (
                    f"Duplicate MPid={member_id} DivisionId:{division_id} "
                    f"Vote:{vote} (existing={self.members[member_id].division_votes[division_id]})"
                )
                print(msg)
            else:
                self.members[member_id].division_votes[division_id] = vote

    def close(self):
        """Close API client and clean up resources."""
        self.api_client.close()

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()


# Import after class definition to avoid circular import
import requests
