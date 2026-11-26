// MARK: - Room Store Models & Detail View

struct RoomStoreApp: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let description: String?
    let category: String
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

    var safeDescription: String {
        description ?? "نسخة معدلة ومحدثة جاهزة للتثبيت المباشر على جهازك بدون قيود."
    }
    var safeMinIOS: String { minIOS ?? "iOS 15.0+" }
    var safeUpdatedAt: String { updatedAt ?? "حديثاً" }
    var safeDownloads: String { downloads ?? "120" }
    var safeLanguages: String { languages ?? "العربية" }
    var safeBundleId: String { bundleId ?? "com.room.\(id)" }
}

struct RoomStoreRepo: Codable {
    let name: String
    let apps: [RoomStoreApp]
}

@MainActor
class RoomStoreViewModel: ObservableObject {
    @Published var allApps: [RoomStoreApp] = []
    @Published var favoriteIDs: Set<String> = []
    @Published var downloadingAppID: String? = nil
    @Published var downloadProgress: Double = 0.0
    @Published var isLoading = false

    // ضع رابط Raw لملف apps.json الخاص بك على GitHub هنا
    private let defaultRepoURL = "https://raw.githubusercontent.com/USERNAME/REPO/main/apps.json"

    var todayFeatured: [RoomStoreApp] {
        let list = allApps.filter { $0.featured == true }
        return list.isEmpty ? Array(allApps.prefix(3)) : list
    }

    var gamesList: [RoomStoreApp] {
        allApps.filter { $0.category == "games" }
    }

    var appsList: [RoomStoreApp] {
        allApps.filter { $0.category == "apps" }
    }

    var deviceCompatibilityText: String {
        let sys = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        return "متوافق مع الجهاز • \(model) • iOS \(sys)"
    }

    func fetchApps() async {
        if allApps.isEmpty {
            allApps = Self.fallbackApps
        }
        guard let url = URL(string: defaultRepoURL) else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let repo = try JSONDecoder().decode(RoomStoreRepo.self, from: data)
            if !repo.apps.isEmpty {
                self.allApps = repo.apps
            }
        } catch {
            print("Room Repo Error: \(error)")
        }
    }

    func toggleFavorite(_ app: RoomStoreApp) {
        if favoriteIDs.contains(app.id) {
            favoriteIDs.remove(app.id)
        } else {
            favoriteIDs.insert(app.id)
        }
    }

    func downloadAndImport(_ app: RoomStoreApp, onComplete: ((URL) -> Void)? = nil) {
        guard let url = URL(string: app.downloadURL), downloadingAppID == nil else { return }
        downloadingAppID = app.id
        downloadProgress = 0.2

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
                try? await Task.sleep(nanoseconds: 300_000_000)
                self.downloadingAppID = nil
                onComplete?(destURL)
            } catch {
                self.downloadingAppID = nil
            }
        }
    }

    static let fallbackApps: [RoomStoreApp] = [
        RoomStoreApp(
            id: "gta-v",
            name: "GTA V",
            subtitle: "العاب معدلة",
            description: "نسخة خاصة من GTA V من تطويرنا - تدعم اللغة العربية - تدعم تحميل ملف اللعبة مباشر (21 جيجا تحميل داخلي) - تدعم قائمة الغش.",
            category: "games",
            featured: true,
            featuredTitle: "GTA V للأيفون",
            featuredSubtitle: "نسخة معدلة تدعم العربية وقائمة الغش",
            version: "1.0",
            size: "100.32 MB",
            minIOS: "iOS 16.3+",
            updatedAt: "قبل 3 أيام",
            downloads: "28",
            languages: "العربية",
            bundleId: "com.macport.gtav",
            iconURL: "",
            bannerURL: nil,
            downloadURL: ""
        ),
        RoomStoreApp(
            id: "instagram-bee",
            name: "إنستغرام النحلة",
            subtitle: "تطبيقات التواصل",
            description: "اصدار جديد للنحلة دخلت في اعماق انستكرام وغيرت الكثير مع ميزات تحميل الوسائط والتخفي الكاملة.",
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

struct RoomAppDetailView: View {
    let app: RoomStoreApp
    @ObservedObject var viewModel: RoomStoreViewModel
    var onInstallIPA: ((URL) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var copiedBundle = false
    @State private var showReportAlert = false
    @State private var selectedSimilarApp: RoomStoreApp? = nil

    private var similarApps: [RoomStoreApp] {
        viewModel.allApps.filter { $0.id != app.id }
    }

    private var isDownloadingThis: Bool {
        viewModel.downloadingAppID == app.id
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ZStack(alignment: .bottom) {
                        AsyncImage(url: URL(string: app.bannerURL ?? app.iconURL)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            LinearGradient(
                                colors: [Color(white: 0.16), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .frame(height: 210)
                        .frame(maxWidth: .infinity)
                        .blur(radius: 18)
                        .opacity(0.45)
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.85), .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipped()

                        VStack(spacing: 10) {
                            RoomAppIconView(urlString: app.iconURL, size: 88, radius: 20)
                                .shadow(color: .black.opacity(0.5), radius: 12, y: 6)

                            Text(app.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)

                            Text(app.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.gray)

                            HStack(spacing: 8) {
                                Text("v\(app.version)")
                                Text("•")
                                Text("\(app.safeDownloads) تحميل")
                            }
                            .font(.caption)
                            .foregroundStyle(.gray)
                        }
                        .padding(.bottom, 6)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        // التبديل بين نظرة عامة والتقييمات
                        HStack(spacing: 0) {
                            RoomPillButton(title: "نظرة عامة", isSelected: selectedTab == 0) {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
                            }
                            RoomPillButton(title: "التقييمات", isSelected: selectedTab == 1) {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 }
                            }
                        }
                        .padding(4)
                        .background(Color(white: 0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // شريط التوافق الأخضر
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield")
                                .font(.subheadline.bold())
                            Text(viewModel.deviceCompatibilityText)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Spacer()
                        }
                        .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.45))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if selectedTab == 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("عن التطبيق")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)

                                Text(app.safeDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .lineSpacing(5)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("المواصفات")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)

                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        RoomSpecCell(title: "الإصدار", value: app.version)
                                        Divider().background(Color.white.opacity(0.1))
                                        RoomSpecCell(title: "الحجم", value: app.size)
                                        Divider().background(Color.white.opacity(0.1))
                                        RoomSpecCell(title: "يتطلب", value: app.safeMinIOS)
                                    }
                                    Divider().background(Color.white.opacity(0.1))
                                    HStack(spacing: 0) {
                                        RoomSpecCell(title: "التحديث", value: app.safeUpdatedAt)
                                        Divider().background(Color.white.opacity(0.1))
                                        RoomSpecCell(title: "التحميلات", value: app.safeDownloads)
                                        Divider().background(Color.white.opacity(0.1))
                                        RoomSpecCell(title: "اللغات", value: app.safeLanguages)
                                    }
                                }
                                .background(Color(white: 0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            HStack(spacing: 12) {
                                Text("المعرف")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)

                                Spacer()

                                Text(app.safeBundleId)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Button {
                                    UIPasteboard.general.string = app.safeBundleId
                                    withAnimation { copiedBundle = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation { copiedBundle = false }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: copiedBundle ? "checkmark" : "doc.on.doc")
                                        Text(copiedBundle ? "تم" : "نسخ")
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.blue.opacity(0.22))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            if !similarApps.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("تطبيقات مشابهة")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(similarApps) { item in
                                                Button {
                                                    selectedSimilarApp = item
                                                } label: {
                                                    VStack(spacing: 6) {
                                                        RoomAppIconView(urlString: item.iconURL, size: 64, radius: 15)
                                                        Text(item.name)
                                                            .font(.caption2)
                                                            .foregroundStyle(.white)
                                                            .lineLimit(1)
                                                            .frame(width: 68)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }

                            Button {
                                showReportAlert = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "flag")
                                        .foregroundStyle(.orange)
                                    Text("الإبلاغ عن مشكلة")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                    Spacer()
                                    Image(systemName: "chevron.left")
                                        .font(.caption.bold())
                                        .foregroundStyle(.gray)
                                }
                                .padding(14)
                                .background(Color(white: 0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "star.leadinghalf.filled")
                                    .font(.largeTitle)
                                    .foregroundStyle(.yellow)
                                Text("4.9 من 5")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("تقييم المستخدمين لهذه النسخة المعدلة")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(white: 0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 105)
            }
            .ignoresSafeArea(edges: .top)

            // أزرار التنقل العلوية
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            )
                    }
                    Spacer()
                    if let shareURL = URL(string: app.downloadURL) {
                        ShareLink(item: shareURL) {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }

            // شريط التثبيت السفلي الثابت
            HStack(spacing: 10) {
                Button {
                    viewModel.downloadAndImport(app) { localURL in
                        onInstallIPA?(localURL)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isDownloadingThis {
                            ProgressView().tint(.white)
                            Text("جاري التنزيل \(Int(viewModel.downloadProgress * 100))%")
                                .font(.headline)
                        } else {
                            Image(systemName: "arrow.down.to.line")
                                .font(.headline)
                            Text("تثبيت • \(app.size)")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isDownloadingThis)

                Button {
                    UIPasteboard.general.string = app.downloadURL
                } label: {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.14))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "square.on.square").foregroundStyle(.white))
                }

                Button {
                    viewModel.toggleFavorite(app)
                } label: {
                    let isFav = viewModel.favoriteIDs.contains(app.id)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.14))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .foregroundStyle(isFav ? .pink : .pink.opacity(0.8))
                        )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.92))
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(item: $selectedSimilarApp) { nextApp in
            RoomAppDetailView(app: nextApp, viewModel: viewModel, onInstallIPA: onInstallIPA)
        }
        .alert("الإبلاغ عن مشكلة", isPresented: $showReportAlert) {
            Button("حسناً", role: .cancel) { }
        } message: {
            Text("تم إرسال بلاغك بخصوص \(app.name) وسيتم فحص الرابط قريباً.")
        }
    }
}

private struct RoomPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color(white: 0.22) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct RoomSpecCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

struct RoomAppIconView: View {
    let urlString: String
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.22), Color(white: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(.white.opacity(0.85))
                )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
