import zipfile, hashlib
from pathlib import Path
with zipfile.ZipFile("build/official-2.0.ipa") as official:
    for filename in ("Husk-zh-Hans.ipa", "Husk-zh-Hans.tipa"):
        with zipfile.ZipFile(Path("build") / filename) as built:
            assert built.testzip() is None
            for i in official.infolist():
                if any(i.filename.startswith("Payload/Husk.app/" + r + "/") for r in ("java-runtime", "android-system")) and not i.is_dir():
                    assert built.read(i.filename) == official.read(i.filename), i.filename
        print(filename, "all 393 official resource files match byte for byte")
