#!/usr/bin/env python3
"""Manual App Store signing for the iOS and macOS builds in CI.

Installs the app's and the extension's App Store provisioning profiles
where Xcode looks for them and finds the identity in the keychain that both
allow. For iOS it then switches each target of the project whose bundle id
has a profile to manual signing with it (see manual_signing.rb) and writes
the export options for flutter build ipa. For macOS, scripts/platform/macos.sh
does both from the profiles' UUIDs, which this hands back; it also checks the
Mac installer identity the .pkg is signed with.

Fails with a readable error for a profile Xcode would reject, so a bad secret
shows up here and not as an xcodebuild error.
"""

import argparse
import datetime
import hashlib
import json
import plistlib
import re
import shutil
import ssl
import subprocess
import sys
from pathlib import Path

PROFILE_DIRS = [
    # Xcode 16 and later only read profiles from here.
    Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    # Older Xcode versions.
    Path.home() / "Library/MobileDevice/Provisioning Profiles",
]

PLATFORMS = {
    # Profile "Platform" value, file extension Xcode gives the profile.
    "ios": ("iOS", ".mobileprovision"),
    "macos": ("OSX", ".provisionprofile"),
}

# The common name of a Mac Installer Distribution certificate starts with one
# of these.
INSTALLER_PREFIXES = ("3rd Party Mac Developer Installer:", "Mac Installer Distribution:")

# Warn when a profile or a certificate runs out within this many days.
EXPIRY_WARNING_DAYS = 30


def fail(message):
    print(f"::error::{message}")
    sys.exit(1)


def warn(message):
    print(f"::warning::{message}")


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)


def read_profile(path, platform):
    """Returns the fields of an App Store profile for the platform, or fails."""
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
    # The application identifier is "<App ID prefix>.<bundle id>"; macOS
    # profiles name the key differently.
    app_id = entitlements.get("application-identifier") or entitlements.get(
        "com.apple.application-identifier", ""
    )
    bundle_id = app_id.split(".", 1)[1] if "." in app_id else app_id

    wanted_platform = PLATFORMS[platform][0]
    if wanted_platform not in profile.get("Platform", []):
        fail(
            f'"{name}" is a profile for {", ".join(profile.get("Platform", []))}, '
            f"not {wanted_platform}. Profiles work for one platform only; make a "
            f"{'Mac App Store Connect' if platform == 'macos' else 'App Store Connect'} one."
        )
    if profile.get("IsXcodeManaged"):
        fail(
            f'"{name}" is managed by Xcode, which manual signing refuses. '
            "Create an App Store profile in the Apple Developer portal instead."
        )
    if (
        "ProvisionedDevices" in profile
        or profile.get("ProvisionsAllDevices")
        or entitlements.get("get-task-allow")
        or entitlements.get("com.apple.security.get-task-allow")
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


def check_expiry(what, der):
    """Prints when a certificate expires and warns when that is soon."""
    expires = certificate_expiry(der)
    days_left = (expires - utc_now()).days
    print(f"{what} expires {expires:%Y-%m-%d}")
    if days_left < EXPIRY_WARNING_DAYS:
        warn(
            f"{what} expires on {expires:%Y-%m-%d}, in {days_left} days. "
            "Builds signed after that fail; make a new one (and new profiles "
            "for a distribution certificate)."
        )


def keychain_identities(keychain, policy="codesigning"):
    """Returns {SHA-1: name} of the valid identities for the policy."""
    found = subprocess.run(
        ["security", "find-identity", "-v", "-p", policy, keychain],
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


def keychain_certificate(keychain, name, sha1):
    """The DER certificate with this name and SHA-1 in the keychain."""
    found = subprocess.run(
        ["security", "find-certificate", "-a", "-Z", "-p", "-c", name, keychain],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    # Each certificate: "SHA-1 hash: <hex>" ... "-----BEGIN CERTIFICATE-----"...
    for block in found.split("SHA-256 hash:")[1:] or found.split("SHA-1 hash:")[1:]:
        if sha1 in block.upper():
            pem = re.search(
                r"-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----", block, re.S
            )
            if pem:
                return ssl.PEM_cert_to_DER_cert(pem.group(0))
    fail(f'Could not read the certificate of "{name}" from the keychain.')


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
    parser.add_argument("--platform", choices=sorted(PLATFORMS), default="ios")
    parser.add_argument("--keychain", required=True)
    parser.add_argument("--app-profile", required=True, type=Path)
    parser.add_argument("--extension-profile", required=True, type=Path)
    parser.add_argument("--project", help="iOS: the project to switch to manual signing")
    parser.add_argument("--configuration", default="Release")
    parser.add_argument("--export-options", help="iOS: where to write ExportOptions.plist")
    parser.add_argument("--github-output", help="file to append app-profile= and extension-profile= to")
    args = parser.parse_args()
    if args.platform == "ios" and not (args.project and args.export_options):
        parser.error("iOS needs --project and --export-options")

    app = read_profile(args.app_profile, args.platform)
    extension = read_profile(args.extension_profile, args.platform)
    profiles = [app, extension]

    if app["bundle_id"] == extension["bundle_id"]:
        fail(f"Both profiles are for {app['bundle_id']}.")
    if app["team"] != extension["team"]:
        fail(f"The profiles belong to different teams: {app['team']}, {extension['team']}")
    team = app["team"]

    identities = keychain_identities(args.keychain)
    allowed = set(app["certificates"]) & set(extension["certificates"])
    usable = sorted(sha1 for sha1 in identities if sha1 in allowed)
    if not usable:
        found = ", ".join(f'"{name}"' for name in identities.values()) or "none"
        fail(
            "The certificate is not one both profiles allow, or it is not a "
            f"valid signing identity. Identities in the keychain: {found}. "
            f'Profiles: "{app["name"]}", "{extension["name"]}".'
        )
    identity_sha1 = usable[0]
    identity_name = identities[identity_sha1]
    # find-identity leaves out expired certificates, so this one is valid.
    check_expiry(f"Certificate {identity_sha1}", app["certificates"][identity_sha1])

    if args.platform == "macos":
        installers = {
            sha1: name
            for sha1, name in keychain_identities(args.keychain, "basic").items()
            if name.startswith(INSTALLER_PREFIXES)
        }
        if not installers:
            fail(
                "No valid Mac Installer Distribution identity in the keychain. "
                "The Mac App Store takes only a .pkg signed with one."
            )
        installer_sha1, installer_name = sorted(installers.items())[0]
        print(f'Installer identity "{installer_name}" ({installer_sha1})')
        check_expiry(
            f"Installer certificate {installer_sha1}",
            keychain_certificate(args.keychain, installer_name, installer_sha1),
        )

    extension_suffix = PLATFORMS[args.platform][1]
    for directory in PROFILE_DIRS:
        directory.mkdir(parents=True, exist_ok=True)
        for profile in profiles:
            shutil.copyfile(profile["path"], directory / f"{profile['uuid']}{extension_suffix}")

    for profile in profiles:
        print(
            f'Profile "{profile["name"]}" ({profile["uuid"]}) for {profile["bundle_id"]}, '
            f"expires {profile['expires']:%Y-%m-%d}"
        )
    print(f'Signing identity "{identity_name}" ({identity_sha1}), team {team}')

    if args.github_output:
        with open(args.github_output, "a") as file:
            file.write(f"app-profile={app['uuid']}\nextension-profile={extension['uuid']}\n")

    if args.platform != "ios":
        return

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
