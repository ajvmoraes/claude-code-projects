# SSH Launcher

App nativo para macOS (SwiftUI + AppKit) para cadastrar servidores SSH e conectar
com um clique, com terminal embutido na própria janela.

Feito para macOS Tahoe (26.x) em Apple Silicon (testado em Mac M5).

## Funcionalidades

- Cadastro de servidores: nome, host, porta, usuário, grupo, notas.
- Autenticação por chave SSH (com seletor de arquivo) **ou** senha (salva no
  Keychain do macOS, nunca em texto puro em disco).
- Clique no nome do servidor na barra lateral → abre uma aba com um terminal
  SSH real e interativo (usa `/usr/bin/ssh` de verdade, com pty).
- Múltiplas sessões abertas ao mesmo tempo, cada uma em sua aba.
- Favoritos, agrupamento por pastas/grupo, busca.
- Menu de contexto: editar, duplicar, copiar comando `ssh ...`, excluir.
- Exportar/importar todos os servidores em um único arquivo `.json`:
  - Sempre inclui os dados de conexão (host, porta, usuário, grupo, etc.).
  - Opcionalmente inclui as senhas salvas, criptografadas (AES-GCM +
    PBKDF2) com uma senha de proteção escolhida na hora de exportar.
  - **Chaves SSH em si não são copiadas** — apenas o caminho referenciado.
    Se for usar em outro Mac, leve a chave (`~/.ssh/...`) separadamente.

## Como abrir/usar

```bash
open ssh-launcher/.build/SSHLauncher.app
```

Ou depois de rodar o build (veja abaixo).

Ao usar autenticação por senha, o app tenta digitar a senha sozinho quando
detecta um prompt `password:`/`senha:` na tela (por alguns segundos após
conectar). Se não detectar, é só digitar normalmente — o terminal é real e
interativo, igual ao Terminal.app.

## Build

**Importante:** este Mac só tem as "Command Line Tools" instaladas (sem Xcode
completo), e a versão instalada tem um bug conhecido onde o Swift Package
Manager (`swift build`/`swift run`) não compila (falha ao linkar o próprio
manifesto `Package.swift`). Por isso este projeto **não usa SPM**: a
biblioteca de terminal embutido ([SwiftTerm](https://github.com/migueldeicaza/SwiftTerm),
MIT license) está vendorizada em `Vendor/SwiftTerm/`, e um script próprio
compila tudo direto com `swiftc` e monta o `.app` manualmente.

```bash
./Scripts/build.sh
```

Gera `.build/SSHLauncher.app`, já assinado ad-hoc (suficiente para rodar
localmente neste Mac). O script:
1. Compila todos os `.swift` de `Sources/` + `Vendor/SwiftTerm/` num binário.
2. Monta a estrutura `.app` (`Info.plist`, `PkgInfo`, `Resources/`).
3. Assina com `codesign --sign -` (ad-hoc).

Se um dia você instalar o Xcode completo ou consertar as Command Line Tools
(`sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`),
dá para migrar para um `.xcodeproj`/pacote SPM padrão sem problemas — o código
em `Sources/` não depende de nada específico deste workaround, só o vendoring
do SwiftTerm.

## Onde os dados ficam salvos

- Lista de servidores: `~/Library/Application Support/SSHLauncher/servers.json`
  (sem senhas).
- Senhas: Keychain do macOS, serviço `com.avs.sshlauncher.password`, uma
  entrada por servidor (conta = UUID do servidor).

## Estrutura do projeto

```
ssh-launcher/
  Sources/
    App/        – entrada do app (SSHLauncherApp.swift)
    Models/     – SSHServer, AuthMethod
    Storage/    – ServerStore (JSON), KeychainService, CryptoService,
                  ExportImportService (backup/restore)
    Views/      – ContentView (sidebar + abas), ServerFormView,
                  TerminalHostView (embed do SwiftTerm), telas de
                  exportar/importar
  Vendor/SwiftTerm/  – SwiftTerm vendorizado (só as partes de macOS)
  Resources/Info.plist
  Scripts/build.sh
```

## Limitações conhecidas

- A digitação automática de senha é "melhor esforço": funciona para o prompt
  padrão do OpenSSH, mas não cobre MFA/2FA nem prompts customizados.
- Sem assinatura de desenvolvedor Apple (é ad-hoc) — é só para uso local
  neste Mac. Para distribuir para outra pessoa, seria necessário assinar e
  notarizar com uma conta de desenvolvedor Apple.
