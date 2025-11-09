# ReadParliament Main Entry Point
# Orchestrates entire workflow: fetch divisions, process votes, write outputs

import argparse
import sys
from pathlib import Path
from data_processor import DataProcessor
from output_writer import OutputWriter
from config import OUTPUT_PATH_DEFAULT


def main():
    """
    Main entry point.
    Parses CLI arguments, runs data processor, writes outputs.

    Returns:
        0 on success, 1 on error
    """
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description="Fetch & process UK Parliament Commons voting data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py
  python main.py --output ./parliament-data
        """
    )
    parser.add_argument(
        '--output',
        type=str,
        default=OUTPUT_PATH_DEFAULT,
        help=f'Output directory for TSV files (default: {OUTPUT_PATH_DEFAULT})'
    )

    args = parser.parse_args()

    try:
        print("ReadParliament - UK Parliament Voting Data Processor\n")
        print(f"Output directory: {args.output}\n")

        # Fetch and process divisions
        processor = DataProcessor()
        processor.process_divisions()

        # Write output files
        writer = OutputWriter(args.output)
        writer.write_dat_file(processor.divisions, processor.members)
        writer.write_txt_file(processor.members)

        # Cleanup
        processor.close()

        print("\n✓ Complete")
        return 0

    except KeyboardInterrupt:
        print("\n\n✗ Interrupted by user")
        return 130

    except Exception as e:
        print(f"\n✗ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
