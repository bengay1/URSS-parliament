# ReadParliament Configuration
# Parliament API settings, date ranges, output paths

# API Configuration
API_BASE_URL = "https://commonsvotes-api.parliament.uk/data"
DIVISION_START = 723
DIVISION_END = 1810

# Date filtering (divisions within this range are processed)
DATE_START = "2019-12-11"
DATE_END = "2024-07-03"

# Output defaults
OUTPUT_PATH_DEFAULT = "output"
OUTPUT_DAT_FILENAME = "votematrix-2019.dat"
OUTPUT_TXT_FILENAME = "votematrix-2019.txt"

# Member metadata default URL
MEMBER_URL = "<empty>"

# HTTP client timeout (seconds)
HTTP_TIMEOUT = 10
