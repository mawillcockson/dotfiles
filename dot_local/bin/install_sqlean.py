import json
from pathlib import Path
from urllib.request import urlopen

DEFAULT_LOCAL_APPS_DIR = Path("~/.local/bin").expanduser()


def latest_url() -> str:
    "what is the download url for the latest sqlean shell?"
    # --header "X-GitHub-Api-Version:2022-11-28"
    with urlopen(
        "https://api.github.com/repos/nalgeon/sqlite/releases/latest"
    ) as response:
        data = json.load(response)

    sqlean = tuple(filter(lambda n: n["name"] == "sqlean.exe", data["assets"]))
    assert len(sqlean) == 1, f"{sqlean=}"
    return sqlean[0]["browser_download_url"]


def download(destination: Path | str) -> Path:
    "download sqlean"
    url = latest_url()
    if isinstance(destination, str):
        destination = Path(destination)
    if not destination.is_dir():
        raise ValueError(f"Directory not found: {destination}")
    with (path := destination / "sqlean.exe").open(mode="wb") as file, urlopen(url) as response:
        file.write(response.read())
    return path


if __name__ == "__main__":
    DEFAULT_LOCAL_APPS_DIR.mkdir(parents=True, exist_ok=True)
    path = download(DEFAULT_LOCAL_APPS_DIR)
    print(f"downloaded to: {path}")

