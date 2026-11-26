import SwiftUI
import UIKit

struct StoreApp: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let description: String?
    let category: String // "apps" أو "games"
    let featured: Bool?
    let featuredTitle: String?
    let featuredSubtitle: String?
    let version: String
    let size: String
    let minIOS: String?
    let updatedAt: String?
    let downloads: String?
    let languages: String?
    let bundleId: String?
    let iconURL: String
    let bannerURL: String?
    let downloadURL: String

    // قيم افتراضية ذكية في حال نقص أي حقل في JSON
    var safeDescription: String {
        description ?? "نسخة معدلة ومحدثة جاهزة للتثبيت المباشر على جهازك بدون قيود."
    }
    var safeMinIOS: String { minIOS ?? "iOS 15.0+" }
    var safeUpdatedAt: String { updatedAt ?? "حديثاً" }
    var safeDownloads: String { downloads ?? "120" }
    var safeLanguages: String { languages ?? "العربية" }
    var safeBundleId: String { bundleId ?? "com.room.\(id)" }
}

struct StoreRepo: Codable {
    let name: String
    let apps: [StoreApp]
}

@MainActor
class AppStoreViewModel: ObservableObject {
    @Published var allApps: [StoreApp] = []
    @Published var favoriteIDs: Set<String> = []
    @Published var downloadingAppID: String? = nil
    @Published var downloadProgress: Double = 0.0
    @Published var isLoading = false

    // ضع رابط Raw لملف apps.json الخاص بك هنا
    private let defaultRepoURL = "https://raw.githubusercontent.com/USERNAME/REPO/main/apps.json"

    var todayFeatured: [StoreApp] {
        let featured = allApps.filter { $0.featured == true }
        return featured.isEmpty ? Array(allApps.prefix(3)) : featured
    }

    var gamesList: [StoreApp] {
        allApps.filter { $0.category == "games" }
    }

    var appsList: [StoreApp] {
        allApps.filter { $0.category == "apps" }
    }

    // قراءة نوع الجهاز وإصدار iOS تلقائياً لشريط التوافق الأخضر
    var deviceCompatibilityText: String {
        let systemVersion = UIDevice.current.systemVersion
        let deviceName = UIDevice.current.model
        return "متوافق مع الجهاز • \(deviceName) • iOS \(systemVersion)"
    }

    func fetchApps() async {
        guard let url = URL(string: defaultRepoURL) else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let repo = try JSONDecoder().decode(StoreRepo.self, from: data)
            self.allApps = repo.apps
        } catch {
            // بيانات احتياطية تعمل فوراً إذا لم يتم ضبط رابط GitHub بعد
            if self.allApps.isEmpty {
                self.allApps = Self.sampleApps
            }
        }
    }

    func toggleFavorite(_ app: StoreApp) {
        if favoriteIDs.contains(app.id) {
            favoriteIDs.remove(app.id)
        } else {
            favoriteIDs.insert(app.id)
        }
    }

    // تنزيل ملف الـ IPA إلى مجلد المستندات ليتم توقيعه في المكتبة
    func downloadAndImport(_ app: StoreApp, onComplete: @escaping (URL) -> Void) {
        guard let url = URL(string: app.downloadURL), downloadingAppID == nil else { return }
        downloadingAppID = app.id
        downloadProgress = 0.15

        Task {
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: url)
                self.downloadProgress = 0.85
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destURL = docs.appendingPathComponent("\(app.id).ipa")
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                self.downloadProgress = 1.0
                try? await Task.sleep(nanoseconds: 400_000_000)
                self.downloadingAppID = nil
                onComplete(destURL)
            } catch {
                self.downloadingAppID = nil
            }
        }
    }

    static let sampleApps: [StoreApp] = [
        StoreApp(
            id: "gta-v",
            name: "GTA V",
            subtitle: "العاب معدلة",
            description: "نسخة خاصة من GTA V من تطويرنا - تدعم اللغة العربية - تدعم تحميل ملف اللعبة مباشر (21 جيجا تحميل داخلي) - تدعم قائمة الغش.",
            category: "games",
            featured: true,
            featuredTitle: "GTA V للأيفون",
            featuredSubtitle: "تدعم اللغة العربية وقائمة الغش",
            version: "1.0",
            size: "100.32 MB",
            minIOS: "iOS 16.3+",
            updatedAt: "قبل 3 أيام",
            downloads: "28",
            languages: "-",
            bundleId: "com.macport.gtav",
            iconURL: "",
            bannerURL: nil,
            downloadURL: ""
        ),
        StoreApp(
            id: "instagram-bee",
            name: "إنستغرام النحلة",
            subtitle: "تطبيقات التواصل",
            description: "إصدار جديد للنحلة دخلت في أعماق إنستغرام وغيرت الكثير مع ميزات التحميل والتخفي الكاملة.",
            category: "apps",
            featured: true,
            featuredTitle: "اصدار جديد للنحلة",
            featuredSubtitle: "انها دخلت في اعماق انستكرام وغيرت الكثير",
            version: "350.0",
            size: "145.0 MB",
            minIOS: "iOS 15.0+",
            updatedAt: "اليوم",
            downloads: "94",
            languages: "العربية",
            bundleId: "com.burbn.instagram",
            iconURL: "",
            bannerURL: nil,
            downloadURL: ""
        )
    ]
}
