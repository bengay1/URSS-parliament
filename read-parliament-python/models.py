# ReadParliament Data Models
# Dataclasses for type safety and JSON deserialisation

from dataclasses import dataclass, field
from enum import IntEnum
from datetime import datetime
from typing import Optional


class Vote(IntEnum):
    """
    Vote codes used in Parliament API responses.
    These correspond to member vote positions in divisions.
    """
    Missing = -9       # Vote not recorded / member absent
    AyeTeller = 1      # Voted Aye and acted as teller
    Aye = 2            # Voted Aye (for the motion)
    Both = 3           # Both (unused in current dataset)
    No = 4             # Voted No (against the motion)
    NoTeller = 5       # Voted No and acted as teller


@dataclass
class MemberDto:
    """
    Data Transfer Object for member from Parliament API JSON.
    Represents a single MP's vote record in a division response.
    """
    MemberId: int
    Name: str
    Party: str
    SubParty: Optional[str] = None
    PartyColour: Optional[str] = None
    PartyAbbreviation: Optional[str] = None
    MemberFrom: Optional[str] = None
    ListAs: Optional[str] = None
    ProxyName: Optional[str] = None


@dataclass
class DivisionDto:
    """
    Data Transfer Object for division (vote) from Parliament API JSON.
    Represents a single parliamentary division with all MP votes.
    """
    DivisionId: int
    Date: datetime
    Title: str
    AyeCount: int
    NoCount: int
    Ayes: list[MemberDto] = field(default_factory=list)
    AyeTellers: list[MemberDto] = field(default_factory=list)
    Noes: list[MemberDto] = field(default_factory=list)
    NoTellers: list[MemberDto] = field(default_factory=list)
    NoVoteRecorded: list[MemberDto] = field(default_factory=list)


@dataclass
class DivisionDat:
    """
    Internal data model for storing processed division information.
    Used for output file generation.
    """
    division_id: int
    date: datetime
    bill_name: str


@dataclass
class MemberDat:
    """
    Internal data model for storing processed member information.
    Tracks individual MP's votes across all divisions.

    division_votes: dict mapping DivisionId -> Vote code
    """
    member_id: int
    first_name: str
    surname: str
    party: str
    division_votes: dict[int, Vote] = field(default_factory=dict)
