version = None

with open("pubspec.yaml", "r", encoding="utf8") as f:
    for line in f:
        line = line.strip()
        if line.startswith("version:"):
            version = line.split("version:", 1)[1].strip().split("+")[0]
            break

if not version:
    raise Exception("Version not found in pubspec.yaml")

print(version)
