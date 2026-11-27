<p align="center">
  <img src="res/icon.png" alt="Deskcel" width="96"><br>
  <b>Deskcel</b> · suporte remoto gratuito da <a href="https://hostcel.com.br/deskcel">Hostcel</a>
</p>

O Deskcel é um programa gratuito de acesso remoto. Com ele a equipe da Hostcel dá suporte aos clientes: o cliente abre o Deskcel, informa o ID e a senha que aparecem na tela e acompanha tudo; o acesso só começa quando ele aceita, e ele pode encerrar a qualquer momento.

O Deskcel é uma versão do [RustDesk](https://github.com/rustdesk/rustdesk) (licença AGPL-3.0) com o nome, as cores e o servidor da Hostcel. Este repositório é um fork público do RustDesk e contém todo o código-fonte usado para gerar os arquivos de download. O README original do RustDesk está em [docs/README-RustDesk.md](docs/README-RustDesk.md).

O que ele faz: ver e controlar a tela, transferir arquivos, chat, áudio, área de transferência, várias telas, conexão com criptografia de ponta a ponta. Funciona sem instalar (Windows portátil) ou instalado.

## Downloads

Sempre a versão mais nova, gerada pelo GitHub Actions a partir deste código ([todas as versões](https://github.com/edilsonlsouza/deskcel/releases), com as somas SHA-256).

| Sistema | Arquivo |
|---|---|
| Windows 10/11 (64 bits) | [Deskcel.exe](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel.exe) |
| macOS (Apple M1/M2/M3/M4) | [Deskcel-aarch64.dmg](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-aarch64.dmg) |
| macOS (Intel) | [Deskcel-x86_64.dmg](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-x86_64.dmg) |
| Ubuntu, Debian, Mint | [.deb x86_64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-x86_64.deb) · [.deb ARM64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-aarch64.deb) |
| Fedora, RHEL | [.rpm x86_64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-x86_64.rpm) · [.rpm ARM64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-aarch64.rpm) |
| openSUSE | [.rpm x86_64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-x86_64-suse.rpm) · [.rpm ARM64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-aarch64-suse.rpm) |
| Arch Linux | [.pkg.tar.zst](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-x86_64.pkg.tar.zst) |
| Qualquer Linux | [AppImage x86_64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-x86_64.AppImage) · [AppImage ARM64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-aarch64.AppImage) · [Flatpak x86_64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-x86_64.flatpak) · [Flatpak ARM64](https://github.com/edilsonlsouza/deskcel/releases/latest/download/Deskcel-aarch64.flatpak) |

No Mac, a primeira abertura pede confirmação: abra o Deskcel, feche o aviso, vá em Ajustes do Sistema › Privacidade e Segurança e clique em "Abrir Mesmo Assim".

## Como é gerado

Os arquivos são compilados só pelo GitHub Actions, a partir deste repositório, pelos workflows [deskcel.yml](.github/workflows/deskcel.yml) (Windows), [deskcel-macos.yml](.github/workflows/deskcel-macos.yml) (macOS) e [deskcel-linux.yml](.github/workflows/deskcel-linux.yml) (Linux). A marca e o servidor entram na compilação pelo script [deskcel-marca.py](.github/deskcel-marca.py). Nenhum arquivo é montado à mão.

## Privacidade

Ao abrir, o Deskcel se registra no servidor da Hostcel (`desck.hostcel.com.br`) para receber o seu ID; o servidor fica sabendo apenas o ID, o endereço IP e se o computador está online. Tela, teclado, mouse, arquivos e áudio só trafegam durante um acesso que a pessoa do computador aceitou, com criptografia de ponta a ponta. O Deskcel não coleta estatísticas de uso, não mostra anúncios e não vende dados.

## Política de assinatura de código (Code signing policy)

Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).
(Assinatura de código gratuita fornecida pela SignPath.io, certificado da SignPath Foundation; vale a partir da aprovação do projeto.)

Team roles:

- Committers and reviewers: [edilsonlsouza](https://github.com/edilsonlsouza)
- Approvers: [edilsonlsouza](https://github.com/edilsonlsouza)

Only binaries built by GitHub Actions from this repository are signed. Every release is approved manually before signing.

Privacy policy: this program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it, except the connection to the Hostcel rendezvous server described in "Privacidade" above, which is required to receive a remote support ID.

## Licença

AGPL-3.0, a mesma do RustDesk. Veja [LICENCE](LICENCE). Os créditos do código original são dos autores do RustDesk (Purslane Tech Pte. Ltd. e colaboradores).

## Contato

Hostcel · [hostcel.com.br/deskcel](https://hostcel.com.br/deskcel) · WhatsApp (81) 9326-7690
