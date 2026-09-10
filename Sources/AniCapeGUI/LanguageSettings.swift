import SwiftUI
import RoleKit
import L10nKit

/// 当前界面语言。默认中文（既有行为），切换后写进 UserDefaults，下次启动沿用。
///
/// 刻意**不**跟随系统语言：默认值必须与加入本功能之前完全一致，
/// 否则老用户升级后界面会自己变样。
@MainActor
final class LanguageSettings: ObservableObject {
    private static let defaultsKey = "appLanguage"

    @Published var language: Language {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        // 认不出的值（旧版本写的、手改的）一律回落到中文，不报错。
        language = stored.flatMap(Language.init(rawValue:)) ?? .zh
    }
}

extension MacRole {
    /// 按当前语言显示角色名。两个名字都是角色数据，住在 `RoleMap`；
    /// 识别逻辑用的始终是 `identifier`，与这里无关。
    func displayName(_ language: Language) -> String {
        language == .en ? englishName : name
    }
}
