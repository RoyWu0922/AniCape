import Foundation
import AniKit
import CapeKit
import RoleKit
import Core

// 参数解析辅助：从 arguments 中取 -o / --author / --name / --role 的值
func optionValue(_ args: [String], _ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func isDirectory(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

func printUsage() {
    print("""
    anicap: 把 Windows .ani 动画光标转换为 Mousecape .cape
    用法:
      anicap pack <ani文件夹> [-o 输出.cape] [--author X] [--name Y]
      anicap file <x.ani> [<y.ani>…] [--role <角色名|identifier>] [-o <输出.cape|输出目录>]
    """)
}

// ---- pack ----
if CommandLine.arguments.count >= 2, CommandLine.arguments[1] == "pack" {
    let args = Array(CommandLine.arguments.dropFirst(2))
    guard let folderPath = args.first, !folderPath.hasPrefix("-") else { printUsage(); exit(2) }
    let folder = URL(fileURLWithPath: folderPath).standardizedFileURL
    let outPath = optionValue(args, "-o") ?? folder.deletingLastPathComponent()
        .appendingPathComponent(folder.lastPathComponent + ".cape").path
    let author = optionValue(args, "--author") ?? "anicap"
    let name = optionValue(args, "--name") ?? folder.lastPathComponent
    do {
        let result = try Converter.pack(folder: folder, outURL: URL(fileURLWithPath: outPath),
                                        author: author, name: name)
        print("✅ \(result.url.path)：\(result.cursors) 个光标")
        if !result.skipped.isEmpty { print("跳过：\(result.skipped.joined(separator: "，"))") }
        exit(result.cursors == 0 ? 1 : 0)
    } catch {
        print("❌ \(folderPath): \(error)"); exit(1)
    }
}

// ---- file ----
if CommandLine.arguments.count >= 2, CommandLine.arguments[1] == "file" {
    let args = Array(CommandLine.arguments.dropFirst(2))
    let roleArg = optionValue(args, "--role")
    let outOpt = optionValue(args, "-o")
    if outOpt == "-" { print("❌ -o - 不支持：本期不做 stdout 合并包"); exit(1) }
    // 收集位置参数（<x.ani> …），跳过选项本身及其取值
    let valueOpts: Set<String> = ["-o", "--role", "--author", "--name"]
    var files: [String] = []
    var skipNext = false
    for a in args {
        if skipNext { skipNext = false; continue }
        if valueOpts.contains(a) { skipNext = true; continue }
        if a.hasPrefix("-") { continue }
        files.append(a)
    }
    if let outOpt, !isDirectory(outOpt), files.count > 1 {
        printUsage(); exit(2)
    }
    guard !files.isEmpty else { printUsage(); exit(2) }
    var anyProduced = false
    var produced: [URL] = []
    var good: [String: CapeCursor] = [:]
    for path in files {
        let url = URL(fileURLWithPath: path)
        let base = url.deletingPathExtension().lastPathComponent
        let identifier: String?
        if let roleArg {
            identifier = RoleMap.identifier(forRoleName: roleArg)
        } else {
            identifier = RoleMap.identifier(forFileName: base)
        }
        guard let identifier else {
            print("⚠️ 跳过 \(url.lastPathComponent)（无法识别角色）"); continue
        }
        do {
            let cur = try Converter.capeCursor(fromANI: url, identifier: identifier)
            anyProduced = true
            if let outOpt, outOpt != "-", !isDirectory(outOpt) {
                // 单文件：-o 指向文件
                try CapeWriter.write(document: CapeDocument(name: base, author: "anicap",
                                                            identifier: "local.anicap.\(Converter.slug(base))",
                                                            cursors: [identifier: cur]),
                                     to: URL(fileURLWithPath: outOpt))
                produced.append(URL(fileURLWithPath: outOpt))
            } else {
                good[identifier] = cur
            }
        } catch {
            print("❌ \(path): \(error)")
        }
    }
    if let outOpt, isDirectory(outOpt) {
        let dir = URL(fileURLWithPath: outOpt)
        let name = dir.lastPathComponent
        let dest = dir.appendingPathComponent(name + ".cape")
        try? CapeWriter.write(document: CapeDocument(name: name, author: "anicap",
                                                     identifier: "local.anicap.\(Converter.slug(name))",
                                                     cursors: good),
                              to: dest)
        if !good.isEmpty { produced.append(dest) }
    } else if !good.isEmpty {
        // 无 -o 或 -o=-：逐文件已在上面的单文件分支处理；此分支只在 outOpt 为 nil 时按原名逐个写出
        for path in files {
            let url = URL(fileURLWithPath: path)
            let base = url.deletingPathExtension().lastPathComponent
            guard let identifier = RoleMap.identifier(forFileName: base) ?? roleArg.flatMap(RoleMap.identifier(forRoleName:)) else { continue }
            guard let cur = good[identifier] else { continue }
            let dest = url.deletingLastPathComponent().appendingPathComponent(base + ".cape")
            try? CapeWriter.write(document: CapeDocument(name: base, author: "anicap",
                                                         identifier: "local.anicap.\(Converter.slug(base))",
                                                         cursors: [identifier: cur]),
                                  to: dest)
            produced.append(dest)
        }
    }
    for p in produced { print("✅ \(p.path)") }
    exit(anyProduced ? 0 : 1)
}

printUsage()
exit(2)
