"""Download the Duolingo Spaced Repetition Dataset (Settles & Meeder, ACL 2016).

Source: Harvard Dataverse, doi:10.7910/DVN/N8XJME
License: CC BY-NC 4.0 (non-commercial)
"""

import gzip
import shutil
import subprocess
from pathlib import Path

DATAVERSE_FILE_URL = "https://dataverse.harvard.edu/api/access/datafile/3091087"
DATA_DIR = Path(__file__).resolve().parents[1] / "data"
GZ_PATH = DATA_DIR / "settles.acl16.learning_traces.13m.csv.gz"
CSV_PATH = DATA_DIR / "settles.acl16.learning_traces.13m.csv"


def download(url: str, dest: Path) -> None:
    # urllib's default User-Agent gets a 403 from the S3-backed Dataverse
    # download endpoint; curl (with its own default UA) works fine.
    print(f"downloading {url} -> {dest}")
    subprocess.run(["curl", "-L", "--fail", "-o", str(dest), url], check=True)


def extract(gz_path: Path, csv_path: Path) -> None:
    print(f"extracting {gz_path} -> {csv_path}")
    with gzip.open(gz_path, "rb") as f_in, open(csv_path, "wb") as f_out:
        shutil.copyfileobj(f_in, f_out)


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not GZ_PATH.exists():
        download(DATAVERSE_FILE_URL, GZ_PATH)
    else:
        print(f"{GZ_PATH} already exists, skipping download")

    if not CSV_PATH.exists():
        extract(GZ_PATH, CSV_PATH)
    else:
        print(f"{CSV_PATH} already exists, skipping extraction")


if __name__ == "__main__":
    main()
