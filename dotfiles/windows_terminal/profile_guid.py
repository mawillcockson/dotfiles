"""
Helps with working with GUIDs for Windows Terminal profiles

https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions#how-to-determine-the-guid-of-an-existing-profile
"""
from __future__ import annotations
import uuid

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from typing import Final

FRAGMENT_NAMESPACE: Final = uuid.UUID("{f65ddb7e-706b-4499-8a50-40313caf510a}")
INTERNAL_NAMESPACE: Final = uuid.UUID("{2bde4a90-d05f-401c-9492-e40884ead1d8}")

def fragment(app: str, profile: str) -> str:
    "generate a GUID for a fragment profile"
    # https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions#generating-a-new-profile-guid
    app_namespace = uuid.uuid5(FRAGMENT_NAMESPACE, app.encode("UTF-16LE").decode("ASCII"))
    fragment_guid = uuid.uuid5(app_namespace, profile.encode("UTF-16LE").decode("ASCII"))
    return "{" + str(fragment_guid) + "}"


def internal(profile: str) -> str:
    "generate the GUID for an internally-created profile"
    internal_guid = uuid.uuid5(INTERNAL_NAMESPACE, profile.encode("UTF-16LE").decode("ASCII"))
    return "{" + str(internal_guid) + "}"

if __name__ == "__main__":
    from argparse import ArgumentParser

    parser = ArgumentParser()
    subparsers = parser.add_subparsers(title="type", required=True, dest="kind")

    internal_cmd = subparsers.add_parser("internal")
    internal_cmd.add_argument("profile_name")

    fragment_cmd = subparsers.add_parser("fragment")
    fragment_cmd.add_argument("app_name")
    fragment_cmd.add_argument("profile_name")

    args = parser.parse_args()
    if args.kind == "internal":
        print(internal(profile=args.profile_name))
    else:
        print(fragment(app=args.app_name, profile=args.profile_name))
