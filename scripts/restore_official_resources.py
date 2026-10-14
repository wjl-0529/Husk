import hashlib, zipfile
from pathlib import Path
p = Path("build/official-2.0.ipa")
assert hashlib.sha256(p.read_bytes()).hexdigest() == "55ca8a6a8a9194759be578ef340553372a4427257093c659d5dc3b2971d722e7"
with zipfile.ZipFile(p) as z:
    for root in ("android-system", "java-runtime"):
        prefix = "Payload/Husk.app/" + root + "/"
        files = [i for i in z.infolist() if i.filename.startswith(prefix) and not i.is_dir()]
        assert files, root
        for i in files:
            dst = Path("build") / root / i.filename[len(prefix):]
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(z.read(i))
        print(root, len(files), "official resources restored")
