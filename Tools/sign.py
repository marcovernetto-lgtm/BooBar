#!/usr/bin/env python3
"""Keep one local signing identity across builds; never modify system trust."""
import os
from pathlib import Path
import secrets
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
private = root / ".signing"
private.mkdir(mode=0o700, exist_ok=True)
os.chmod(private, 0o700)
secret_file = private / "keychain-password"
if not secret_file.exists():
    secret_file.write_text(secrets.token_hex(32))
    os.chmod(secret_file, 0o600)
password = secret_file.read_text().strip()
keychain = private / "BooBar.keychain-db"
legacy_keychain = private / "Hidebar.keychain-db"
if legacy_keychain.exists() and not keychain.exists():
    legacy_keychain.rename(keychain)

def run(arguments):
    result = subprocess.run(arguments, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Comando di firma fallito.")
    return result.stdout

try:
    if not keychain.exists():
        config = private / "certificate.cnf"
        config.write_text("""[req]
distinguished_name=subject
x509_extensions=signing
prompt=no
[subject]
CN=BooBar Local Code Signing
O=BooBar Local Development
[signing]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
""")
        key = private / "key.pem"
        certificate = private / "certificate.pem"
        archive = private / "identity.p12"
        run(["/usr/bin/openssl", "req", "-new", "-x509", "-newkey", "rsa:2048",
             "-nodes", "-sha256", "-days", "3650", "-config", str(config),
             "-keyout", str(key), "-out", str(certificate)])
        os.chmod(key, 0o600)
        run(["/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(key),
             "-in", str(certificate), "-out", str(archive), "-passout", "file:" + str(secret_file)])
        os.chmod(archive, 0o600)
        run(["/usr/bin/security", "create-keychain", "-p", password, str(keychain)])
        run(["/usr/bin/security", "unlock-keychain", "-p", password, str(keychain)])
        run(["/usr/bin/security", "import", str(archive), "-k", str(keychain), "-P", password,
             "-T", "/usr/bin/codesign"])
        run(["/usr/bin/security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
             "-s", "-k", password, str(keychain)])
        key.unlink()
        archive.unlink()
    run(["/usr/bin/security", "unlock-keychain", "-p", password, str(keychain)])
    fingerprint = run(["/usr/bin/openssl", "x509", "-in", str(private / "certificate.pem"),
                       "-noout", "-fingerprint", "-sha1"]).strip().split("=")[-1].replace(":", "")
    run(["/usr/bin/codesign", "--force", "--keychain", str(keychain), "--sign", fingerprint, sys.argv[1]])
    run(["/usr/bin/codesign", "--verify", "--strict", sys.argv[1]])
    print("Firma locale stabile applicata. Nessuna modifica alle impostazioni di attendibilità del Mac.")
except (RuntimeError, IndexError) as error:
    sys.exit(str(error))
