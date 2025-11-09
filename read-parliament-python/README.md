# ReadParliament

Fetch and process UK Parliament Commons voting data into analysable vote matrices.

## Overview

ReadParliament scrapes parliamentary division (vote) records from the official UK Parliament API and generates two TSV output files suitable for statistical analysis:

- **votematrix-2019.dat** – Vote matrix with member voting records across all divisions
- **votematrix-2019.txt** – Member metadata (ID, name, party)

### What It Does

1. **Fetches divisions** – Calls Parliament Commons Votes API for ~1,087 divisions (divisions 723–1809)
2. **Filters by date** – Retains only divisions between 11 Dec 2019 and 3 Jul 2024
3. **Aggregates votes** – Maps each member's vote across all divisions
4. **Outputs matrices** – Writes two TSV files for downstream analysis

### Data Schema

#### Vote Matrix (votematrix-2019.dat)

Tab-separated with columns:
- `rowid` – Division ID
- `date` – Vote date (YYYY-MM-DD)
- `voteno` – Division number
- `Bill` – Motion/bill title
- `mpid{N}` – Vote code for each MP (columns sorted by member ID)

Vote codes:
```
-9  Missing / not recorded
 1  Aye Teller
 2  Aye
 4  No
 5  No Teller
```

**Example row:**
```
736	2019-12-20	736	European Union...	2	2	4	-9	5	...
```

#### Member Metadata (votematrix-2019.txt)

Tab-separated with columns:
- `mpid` – Member ID
- `firstname` – First name
- `surname` – Surname
- `party` – Party abbreviation (Con, Lab, etc)
- `PublicWhip URL` – Reference URL

**Format:**
- Lines 0–18: Padding rows ("ignore 0" through "ignore 18") for legacy compatibility
- Line 19: Header row
- Lines 20+: Member records (sorted by ID)

**Example:**
```
ignore 0
...
ignore 18
mpid	firstname	surname	party	PublicWhip URL
8	Theresa	 May	Con	http://martingay.co.uk
14	John	 Redwood	Con	http://martingay.co.uk
```

---

## Installation

### Requirements
- Python 3.9 or later
- `requests` library (HTTP client)

### Setup

1. Clone or download project
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

---

## Usage

### Basic

Run with default output directory (`output/`):

```bash
python main.py
```

### Custom Output Directory

```bash
python main.py --output /path/to/output
```

### Output

Generates two files in output directory:
- `votematrix-2019.dat` – Vote matrix (~1.7 MB)
- `votematrix-2019.txt` – Member metadata (~18 KB)

### Console Output

```
ReadParliament - UK Parliament Voting Data Processor

Output directory: output

Fetching divisions 723-1809...
723  724  725  726  727  ...  1808  1809

Processed 1087 divisions
Tracked 1247 MPs
Written output/votematrix-2019.dat
Written output/votematrix-2019.txt

✓ Complete
```

---

## Project Structure

```
read-parliament/
├── main.py                # Entry point & CLI handler
├── config.py              # Constants (API URLs, date ranges, defaults)
├── models.py              # Data models (Vote enum, DTOs, internal classes)
├── api_client.py          # HTTP wrapper for Parliament API
├── data_processor.py      # Core logic (fetch, parse, aggregate)
├── output_writer.py       # TSV file generation
├── requirements.txt       # Python dependencies
├── README.md              # This file
└── output/                # Generated output files (created by script)
    ├── votematrix-2019.dat
    └── votematrix-2019.txt
```

### Module Responsibilities

| Module | Purpose |
|--------|---------|
| `config.py` | Centralised configuration (API URLs, date range, output paths) |
| `models.py` | Type-safe dataclasses for API responses & internal data |
| `api_client.py` | HTTP communication with Parliament API; connection pooling |
| `data_processor.py` | Main business logic: fetch divisions, parse JSON, aggregate votes |
| `output_writer.py` | Format and write TSV output files |
| `main.py` | CLI entry point, orchestration, error handling |

---

## API Details

### Data Source
Parliament UK Commons Votes API
Base URL: `https://commonsvotes-api.parliament.uk/data`

### Divisions
- Fetches divisions 723–1809 (covers ~4.5 years of voting data)
- Each division includes lists of voting members by category (Ayes, Noes, etc)

### Date Range
- **Start:** 11 December 2019
- **End:** 3 July 2024
- Out-of-range divisions are filtered and excluded

---

## Implementation Notes

### Column Ordering
- MP columns in output sorted by member ID (ensures reproducible, consistent output)

### Error Handling
- **Missing divisions** – Logged to console; processing continues
- **Duplicate votes** – Logged to console (shouldn't occur in valid data)
- **Network errors** – Reported; script continues with next division

### Performance
- Single-threaded HTTP requests (~15 mins for full dataset)
- Can be optimised with async HTTP if needed

---

## Troubleshooting

### "requests" module not found
```bash
pip install requests
```

### Connection timeout
Network latency to Parliament API. Retry or increase timeout in `config.py`:
```python
HTTP_TIMEOUT = 10  # Increase to 20+ for slow connections
```

### Missing output files
Ensure output directory is writable. Check console output for errors.

---

## License & Attribution

Parliament data sourced from UK Parliament Commons Votes API (public data).
Python port from original C# implementation.

---

## Development

### Running with Custom Date Range

Edit `config.py`:
```python
DATE_START = "2023-01-01"
DATE_END = "2023-12-31"
```

### Adding Features

Extend `DataProcessor` in `data_processor.py` for custom analysis or filtering.

---

## Contact

For issues or improvements, refer to the C# original project documentation.
