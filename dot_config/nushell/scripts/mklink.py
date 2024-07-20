"""
tries to make a symbolic link on any platform
"""

from pathlib import Path


def main(link: Path, target: Path) -> Path:
    "tries to make a symbolic link on any platform"
    if link.exists():
        raise ValueError(f"link must not exist: {link}")
    if not target.exists():
        raise ValueError(f"target must exist: {link}")
    link.symlink_to(target)
    return link


if __name__ == "__main__":
    from argparse import ArgumentParser

    parser = ArgumentParser()
    parser.add_argument("link", type=Path, help="the path where the link should end up")
    parser.add_argument(
        "target", type=Path, help="the file that the link should point to"
    )

    args = parser.parse_args()
    main(link=args.link, target=args.target)
