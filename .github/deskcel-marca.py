# Deskcel (Hostcel): grava nome, servidor e chave do servidor no hbb_common (submódulo do upstream).
# Usado pelos workflows deskcel.yml (Windows) e deskcel-linux.yml.
import os
import re

p = "libs/hbb_common/src/config.rs"
s = open(p, encoding="utf-8").read()
assert os.environ.get("DESKCEL_KEY"), "segredo DESKCEL_KEY vazio"
subs = [
    (r'APP_NAME: RwLock<String> = RwLock::new\("RustDesk"', f'APP_NAME: RwLock<String> = RwLock::new("{os.environ["DESKCEL_NAME"]}"'),
    (r'RENDEZVOUS_SERVERS: &\[&str\] = &\["rs-ny\.rustdesk\.com"\]', f'RENDEZVOUS_SERVERS: &[&str] = &["{os.environ["DESKCEL_SERVER"]}"]'),
    (r'RS_PUB_KEY: &str = "[^"]+"', f'RS_PUB_KEY: &str = "{os.environ["DESKCEL_KEY"]}"'),
]
for pat, rep in subs:
    s, n = re.subn(pat, rep, s)
    assert n == 1, f"padrão não encontrado: {pat}"
open(p, "w", encoding="utf-8").write(s)
for linha in s.splitlines():
    if "APP_NAME: RwLock" in linha or "RENDEZVOUS_SERVERS:" in linha or "RS_PUB_KEY:" in linha:
        print(linha.strip())
