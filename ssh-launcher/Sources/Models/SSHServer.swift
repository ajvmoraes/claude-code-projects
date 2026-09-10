import Foundation

enum SSHAuthMethod: String, Codable, CaseIterable, Identifiable {
    case key
    case password
    case agentOrDefault

    var id: String { rawValue }

    var label: String {
        switch self {
        case .key: return "Chave SSH"
        case .password: return "Senha"
        case .agentOrDefault: return "Agente / padrão do sistema"
        }
    }
}

struct SSHServer: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var host: String = ""
    var port: Int = 22
    var username: String = ""
    var authMethod: SSHAuthMethod = .key
    var identityFilePath: String = ""
    var proxyJump: String = ""
    var extraArgs: String = ""
    var group: String = ""
    var notes: String = ""
    var isFavorite: Bool = false

    var displayTarget: String {
        username.isEmpty ? host : "\(username)@\(host)"
    }

    var subtitle: String {
        port == 22 ? displayTarget : "\(displayTarget):\(port)"
    }

    /// Command-line arguments for `/usr/bin/ssh`, ready to hand to a spawned process.
    func buildSSHArguments() -> [String] {
        var args: [String] = []
        if port != 22 {
            args += ["-p", String(port)]
        }
        let identity = identityFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if authMethod == .key, !identity.isEmpty {
            args += ["-i", (identity as NSString).expandingTildeInPath]
        }
        let jump = proxyJump.trimmingCharacters(in: .whitespacesAndNewlines)
        if !jump.isEmpty {
            args += ["-J", jump]
        }
        let extra = extraArgs.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            args += extra.split(separator: " ").map(String.init)
        }
        args.append(displayTarget)
        return args
    }

    /// Human-readable `ssh ...` command, useful for copying to clipboard or debugging.
    func shellCommandDescription() -> String {
        (["ssh"] + buildSSHArguments()).joined(separator: " ")
    }
}
