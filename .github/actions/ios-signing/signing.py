#!/usr/bin/env python3
"""Manual App Store signing for the iOS build in CI.

Installs the given App Store provisioning profiles where Xcode looks for
them, finds the identity in the keychain that all of them allow, switches
each target of the project whose bundle id has a profile to manual signing
with it (see manual_signing.rb), and writes the export options for
flutter build ipa. Fails with a readable error for a profile Xcode would
reject, so a bad secret shows up here and not as an xcodebuild error.
"""

import argparse
import datetime
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROFILE_DIRS = [
    # Xcode 16 and later only read profiles from here.
    Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    # Older Xcode versions.
    Path.home() / "Library/MobileDevice/Provisioning Profiles",
]

# Warn when a profile or the certificate runs out within this many days.
EXPIRY_WARNING_DAYS = 30


def fail(message):
    print(f"::error::{message}")
    sys.exit(1)


def warn(message):
    print(f"::warning::{message}")


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)


def read_profile(path):
    """Returns the fields of an App Store profile, or fails."""
    decoded = subprocess.run(
        ["security", "cms", "-D", "-i", str(path)], capture_output=True
    )
    if decoded.returncode != 0 or not decoded.stdout:
        fail(
            f"{path.name} is not a provisioning profile: "
            f"{decoded.stderr.decode(errors='replace').strip()}"
        )
    profile = plistlib.loads(decoded.stdout)

    name = profile["Name"]
    entitlements = profile.get("Entitlements", {})
    # The application identifier is "<App ID prefix>.<bundle id>".
    bundle_id = entitlements["application-identifier"].split(".", 1)[1]

    if profile.get("IsXcodeManaged"):
        fail(
            f'"{name}" is managed by Xcode, which manual signing refuses. '
            "Create an App Store profile in the Apple Developer portal instead."
        )
    if (
        "ProvisionedDevices" in profile
        or profile.get("ProvisionsAllDevices")
        or entitlements.get("get-task-allow")
    ):
        fail(f'"{name}" is a development, ad hoc or enterprise profile, not an App Store one.')
    if "*" in bundle_id:
        fail(f'"{name}" is for the wildcard App ID {bundle_id}; it needs an explicit one.')

    expires = profile["ExpirationDate"]
    days_left = (expires - utc_now()).days
    if expires <= utc_now():
        fail(f'"{name}" for {bundle_id} expired on {expires:%Y-%m-%d}.')
    if days_left < EXPIRY_WARNING_DAYS:
        warn(f'"{name}" for {bundle_id} expires on {expires:%Y-%m-%d}, in {days_left} days.')

    return {
        "path": path,
        "uuid": profile["UUID"],
        "name": name,
        "team": profile["TeamIdentifier"][0],
        "bundle_id": bundle_id,
        "expires": expires,
        # Identities are known by the SHA-1 of their certificate.
        "certificates": {
            hashlib.sha1(certificate).hexdigest().upper(): certificate
            for certificate in profile.get("DeveloperCertificates", [])
        },
    }


def certificate_expiry(der):
    """The notAfter date of a DER certificate, as a naive UTC datetime."""
    end = subprocess.run(
        ["openssl", "x509", "-inform", "DER", "-noout", "-enddate"],
        input=der,
        capture_output=True,
        check=True,
    ).stdout.decode()
    # notAfter=Jan  1 12:00:00 2027 GMT
    return datetime.datetime.strptime(
        " ".join(end.split("=", 1)[1].split()), "%b %d %H:%M:%S %Y %Z"
    )


def keychain_identities(keychain):
    """Returns {SHA-1: name} of the valid code signing identities."""
    found = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning", keychain],
        capture_output=True,
        text=True,
        check=True,
    )
    identities = {}
    for line in found.stdout.splitlines():
        match = re.match(r'\s*\d+\)\s+([0-9A-F]{40})\s+"(.+)"\s*$', line)
        if match:
            identities[match.group(1)] = match.group(2)
    return identities


def cocoapods_ruby():
    """The Ruby that runs CocoaPods, whose gems include xcodeproj."""
    pod = shutil.which("pod")
    if pod:
        with open(pod, "rb") as file:
            shebang = file.readline().decode(errors="replace").strip()
        interpreter = shebang[2:].split()[0] if shebang.startswith("#!") else ""
        if Path(interpreter).name.startswith("ruby") and Path(interpreter).exists():
            return interpreter
    return "ruby"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keychain", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--configuration", default="Release")
    parser.add_argument("--export-options", required=True)
    parser.add_argument("profiles", nargs="+", type=Path)
    args = parser.parse_args()

    profiles = [read_profile(path) for path in args.profiles]

    bundle_ids = [profile["bundle_id"] for profile in profiles]
    if len(set(bundle_ids)) != len(bundle_ids):
        fail(f"Two profiles are for the same bundle id: {', '.join(bundle_ids)}")
    teams = {profile["team"] for profile in profiles}
    if len(teams) != 1:
        fail(f"The profiles belong to different teams: {', '.join(sorted(teams))}")
    team = teams.pop()

    identities = keychain_identities(args.keychain)
    allowed = set.intersection(*(set(profile["certificates"]) for profile in profiles))
    usable = sorted(sha1 for sha1 in identities if sha1 in allowed)
    if not usable:
        found = ", ".join(f'"{name}"' for name in identities.values()) or "none"
        fail(
            "The certificate is not one every profile allows, or it is not a "
            f"valid signing identity. Identities in the keychain: {found}. "
            "Profiles: " + ", ".join(f'"{p["name"]}"' for p in profiles) + "."
        )
    identity_sha1 = usable[0]
    identity_name = identities[identity_sha1]

    # find-identity leaves out expired certificates, so this one is valid.
    expires = certificate_expiry(profiles[0]["certificates"][identity_sha1])
    days_left = (expires - utc_now()).days
    print(f"Certificate {identity_sha1} expires {expires:%Y-%m-%d}")
    if days_left < EXPIRY_WARNING_DAYS:
        warn(
            f"The signing certificate expires on {expires:%Y-%m-%d}, in {days_left} "
            "days. Builds signed after that fail; make a new one and its profiles."
        )

    for directory in PROFILE_DIRS:
        directory.mkdir(parents=True, exist_ok=True)
        for profile in profiles:
            shutil.copyfile(profile["path"], directory / f"{profile['uuid']}.mobileprovision")

    for profile in profiles:
        print(
            f'Profile "{profile["name"]}" ({profile["uuid"]}) for {profile["bundle_id"]}, '
            f"expires {profile['expires']:%Y-%m-%d}"
        )
    print(f'Signing identity "{identity_name}" ({identity_sha1}), team {team}')

    manual_signing = Path(__file__).with_name("manual_signing.rb")
    subprocess.run(
        [cocoapods_ruby(), str(manual_signing), args.project],
        input=json.dumps(
            {
                "configuration": args.configuration,
                "team": team,
                "identity": identity_name,
                "profiles": {
                    profile["bundle_id"]: {"uuid": profile["uuid"], "name": profile["name"]}
                    for profile in profiles
                },
            }
        ),
        text=True,
        check=True,
    )

    export_options = {
        "method": "app-store-connect",
        "destination": "export",
        "teamID": team,
        "signingStyle": "manual",
        "signingCertificate": identity_sha1,
        "provisioningProfiles": {
            profile["bundle_id"]: profile["uuid"] for profile in profiles
        },
    }
    with open(args.export_options, "wb") as file:
        plistlib.dump(export_options, file)
    print(f"Wrote {args.export_options}")


if __name__ == "__main__":
    main()
