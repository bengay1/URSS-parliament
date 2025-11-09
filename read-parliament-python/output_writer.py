# ReadParliament Output Writer
# Generates TSV output files for vote matrices

from pathlib import Path
from models import DivisionDat, MemberDat, Vote
from config import OUTPUT_DAT_FILENAME, OUTPUT_TXT_FILENAME, MEMBER_URL


class OutputWriter:
    """
    Writes processed voting data to TSV (tab-separated values) output files.
    Generates two files: votematrix-2019.dat (vote matrix) and votematrix-2019.txt (member metadata).
    """

    def __init__(self, output_path: str):
        """
        Initialise output writer with output directory.

        Args:
            output_path: Path to output directory (created if doesn't exist)
        """
        self.output_path = Path(output_path)
        # Create output directory if missing
        self.output_path.mkdir(parents=True, exist_ok=True)

    def write_dat_file(
        self,
        divisions: dict[int, DivisionDat],
        members: dict[int, MemberDat]
    ):
        """
        Write vote matrix to TSV file (votematrix-2019.dat).
        Format: rowid, date, voteno, Bill, then vote codes for each MP (sorted by ID).
        One row per division. Cells contain vote codes: -9, 1, 2, 4, 5.

        Args:
            divisions: Dict of DivisionId -> DivisionDat
            members: Dict of MemberId -> MemberDat (with vote tracking)
        """
        dat_file = self.output_path / OUTPUT_DAT_FILENAME

        # Sort MP IDs for consistent column ordering (reproducible output)
        mp_ids = sorted(members.keys())

        with open(dat_file, 'w', encoding='utf-8') as f:
            # Header row
            header_fields = ['rowid', 'date', 'voteno', 'Bill']
            header_fields += [f'mpid{mp_id}' for mp_id in mp_ids]
            f.write('\t'.join(header_fields) + '\n')

            # Data rows (one per division, ordered by DivisionId)
            for division_id in sorted(divisions.keys()):
                division = divisions[division_id]

                # Build row: metadata + votes
                row_fields = [
                    str(division.division_id),
                    division.date.strftime('%Y-%m-%d'),
                    str(division.division_id),
                    division.bill_name
                ]

                # Vote code for each MP (in sorted order)
                for mp_id in mp_ids:
                    # Get vote, default to Missing (-9) if not found
                    vote = members[mp_id].division_votes.get(
                        division.division_id,
                        Vote.Missing
                    )
                    row_fields.append(str(int(vote)))

                f.write('\t'.join(row_fields) + '\n')

        print(f"Written {dat_file}")

    def write_txt_file(self, members: dict[int, MemberDat]):
        """
        Write member metadata to TSV file (votematrix-2019.txt).
        Format: 19 padding rows, then header, then member records (sorted by ID).

        Args:
            members: Dict of MemberId -> MemberDat
        """
        txt_file = self.output_path / OUTPUT_TXT_FILENAME

        with open(txt_file, 'w', encoding='utf-8') as f:
            # 19 padding rows (legacy format compatibility)
            for i in range(19):
                f.write(f"ignore {i}\n")

            # Header row
            f.write("mpid\tfirstname\tsurname\tparty\tPublicWhip URL\n")

            # Member data rows (sorted by ID for consistency)
            for member_id in sorted(members.keys()):
                member = members[member_id]
                f.write(
                    f"{member.member_id}\t{member.first_name}\t"
                    f"{member.surname}\t{member.party}\t"
                    f"{MEMBER_URL}\n"
                )

        print(f"Written {txt_file}")
