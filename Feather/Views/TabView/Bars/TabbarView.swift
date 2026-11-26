//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI
import UIKit

struct TabbarView: View {
	@State private var selectedTab: TabEnum = .sources
	@StateObject private var roomStoreVM = RoomStoreViewModel()

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				tabContent(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab)
			}
		}
		.task {
			await roomStoreVM.fetchApps()
		}
	}

	@ViewBuilder
	private func tabContent(for tab: TabEnum) -> some View {
		let key = "\(tab) \(tab.title)".lowercased()
		if key.contains("اليوم") || key.contains("today") || key.contains("home") {
			RoomTodayView(viewModel: roomStoreVM)
		} else if key.contains("الألعاب") || key.contains("العاب") || key.contains("game") {
			RoomGamesView(viewModel: roomStoreVM)
		} else if key.contains("التطبيقات") || key.contains("library") {
			RoomAppsView(viewModel: roomStoreVM)
		} else if key.contains("المصادر") || key.contains("source") {
			RoomSourcesAndLibraryView(sourcesTab: tab)
		} else if key.contains("البحث") || key.contains("بحث") || key.contains("search") {
			RoomSearchView(viewModel: roomStoreVM)
		} else {
			TabEnum.view(for: tab)
		}
	}
}

// MARK: - 0. دمج المصادر + استيراد وتوقيع ملفات IPA
struct RoomSourcesAndLibraryView: View {
	let sourcesTab: TabEnum
	@State private var selectedSection = 0 // 0 = المصادر, 1 = المكتبة و IPA
	@State private var showSettings = false

	private var libraryTab: TabEnum {
		TabEnum.defaultTabs.first {
			let k = "\($0) \($0.title)".lowercased()
			return k.contains("التطبيقات") || k.contains("library") || k.contains("المكتبة")
		} ?? sourcesTab
	}

	var body: some View {
		VStack(spacing: 0) {
			// شريط تبديل علوي يدمج المصادر مع مكتبة ملفات IPA
			HStack(spacing: 10) {
				Picker("", selection: $selectedSection) {
					Text("المصادر").tag(0)
					Text("المكتبة (IPA)").tag(1)
				}
				.pickerStyle(.segmented)

				Button {
					showSettings = true
				} label: {
					Image(systemName: "gearshape.fill")
						.font(.subheadline)
						.foregroundStyle(.white)
						.frame(width: 32, height: 32)
						.background(Color(white: 0.16))
						.clipShape(Circle())
				}
			}
			.padding(.horizontal)
			.padding(.vertical, 8)
			.background(Color.black)

			if selectedSection == 0 {
				TabEnum.view(for: sourcesTab)
			} else {
				TabEnum.view(for: libraryTab)
			}
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(isPresented: $showSettings) {
			TabEnum.view(for: .settings)
		}
	}
}

// MARK: - 1. نماذج البيانات وجلب الملف من GitHub
struct RoomStoreApp: Identifiable, Codable, Hashable {
	let id: String
	let name: String
	let subtitle: String
	let description: String?
	let category: String // "apps" أو "games"
	let subCategory: String // "social", "media", "tools", "design", "games"
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

	enum CodingKeys: String, CodingKey {
		case name, type, bundleID, bundleIdentifier, version, versionDate, fullDate
		case size, down, downloadURL, localizedDescription, icon, iconURL
	}

	init(
		id: String,
		name: String,
		subtitle: String,
		description: String? = nil,
		category: String = "apps",
		subCategory: String = "tools",
		featured: Bool? = nil,
		featuredTitle: String? = nil,
		featuredSubtitle: String? = nil,
		version: String,
		size: String,
		minIOS: String? = "iOS 15.0+",
		updatedAt: String? = "حديثاً",
		downloads: String? = "1.2K",
		languages: String? = "العربية",
		bundleId: String? = nil,
		iconURL: String,
		bannerURL: String? = nil,
		downloadURL: String
	) {
		self.id = id
		self.name = name
		self.subtitle = subtitle
		self.description = description
		self.category = category
		self.subCategory = subCategory
		self.featured = featured
		self.featuredTitle = featuredTitle
		self.featuredSubtitle = featuredSubtitle
		self.version = version
		self.size = size
		self.minIOS = minIOS
		self.updatedAt = updatedAt
		self.downloads = downloads
		self.languages = languages
		self.bundleId = bundleId
		self.iconURL = iconURL
		self.bannerURL = bannerURL
		self.downloadURL = downloadURL
	}

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)

		let rawBundle = (try? c.decode(String.self, forKey: .bundleIdentifier))
			?? (try? c.decode(String.self, forKey: .bundleID))
			?? UUID().uuidString

		let rawName = (try? c.decode(String.self, forKey: .name))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let resolvedName = rawName.isEmpty ? (rawBundle.components(separatedBy: ".").last ?? "تطبيق معدل") : rawName

		let rawVersion = (try? c.decode(String.self, forKey: .version)) ?? "1.0"
		let rawDate = (try? c.decode(String.self, forKey: .versionDate)) ?? "حديثاً"
		let rawFullDate = (try? c.decode(String.self, forKey: .fullDate)) ?? rawVersion

		self.id = "\(rawBundle)_\(rawVersion)_\(rawFullDate)"
		self.name = resolvedName
		self.bundleId = rawBundle
		self.version = rawVersion
		self.updatedAt = rawDate

		let desc = (try? c.decode(String.self, forKey: .localizedDescription)) ?? "نسخة معدلة ومفتوحة المزايا"
		self.subtitle = desc
		self.description = "\(desc) • الإصدار \(rawVersion) (تحديث \(rawDate))"

		if let byteSize = try? c.decode(Int64.self, forKey: .size) {
			let formatter = ByteCountFormatter()
			formatter.allowedUnits = [.useMB, .useGB]
			formatter.countStyle = .file
			self.size = formatter.string(fromByteCount: byteSize)
		} else if let strSize = try? c.decode(String.self, forKey: .size) {
			self.size = strSize
		} else {
			self.size = "غير محدد"
		}

		let appType = (try? c.decode(Int.self, forKey: .type)) ?? 1
		let lower = "\(resolvedName) \(rawBundle)".lowercased()

		let gameKeywords = ["game", "piano", "gta", "minecraft", "8ball", "pool", "sudoku", "wordscape", "guesser", "elevate", "chess", "roblox", "pubg", "simcity"]
		let socialKeywords = ["insta", "tiktok", "musically", "snap", "telegram", "swiftgram", "locket", "purestatus", "wa.", "whatsapp", "unfold", "mojo", "inpreview", "social", "vibes"]
		let mediaKeywords = ["photo", "camera", "video", "picsart", "inshot", "vsco", "lightroom", "lrmobile", "epik", "polish", "dazz", "proccd", "remini", "videoleap", "premiere", "kinemaster", "vlog", "lut", "infuse", "b612", "soda", "foodie", "peachy", "prequel", "bazaart", "facetune"]
		let designKeywords = ["notability", "collanote", "goodnotes", "alight", "fresco", "sketch", "draw", "pixel", "color", "mockup", "animock", "scrl", "canva", "noteplan", "drafts"]

		let isGame = (appType == 2) || gameKeywords.contains(where: { lower.contains($0) })
		self.category = isGame ? "games" : "apps"

		if isGame {
			self.subCategory = "games"
		} else if socialKeywords.contains(where: { lower.contains($0) }) {
			self.subCategory = "social"
		} else if mediaKeywords.contains(where: { lower.contains($0) }) {
			self.subCategory = "media"
		} else if designKeywords.contains(where: { lower.contains($0) }) {
			self.subCategory = "design"
		} else {
			self.subCategory = "tools"
		}

		self.iconURL = (try? c.decode(String.self, forKey: .iconURL))
			?? (try? c.decode(String.self, forKey: .icon))
			?? ""
		self.bannerURL = self.iconURL

		self.downloadURL = (try? c.decode(String.self, forKey: .downloadURL))
			?? (try? c.decode(String.self, forKey: .down))
			?? ""

		self.featured = nil
		self.featuredTitle = resolvedName
		self.featuredSubtitle = desc
		self.minIOS = "iOS 15.0+"
		self.downloads = "1.2K"
		self.languages = "متعدد اللغات"
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(name, forKey: .name)
		try c.encodeIfPresent(bundleId, forKey: .bundleIdentifier)
		try c.encode(version, forKey: .version)
		try c.encodeIfPresent(updatedAt, forKey: .versionDate)
		try c.encode(subtitle, forKey: .localizedDescription)
		try c.encode(iconURL, forKey: .iconURL)
		try c.encode(downloadURL, forKey: .downloadURL)
	}

	var safeDescription: String {
		description ?? "نسخة معدلة ومحدثة جاهزة للتثبيت المباشر على جهازك بدون قيود."
	}
	var safeMinIOS: String { minIOS ?? "iOS 15.0+" }
	var safeUpdatedAt: String { updatedAt ?? "حديثاً" }
	var safeDownloads: String { downloads ?? "1.2K" }
	var safeLanguages: String { languages ?? "العربية" }
	var safeBundleId: String { bundleId ?? "com.room.\(id)" }
}

struct RoomStoreRepo: Codable {
	let name: String?
	let apps: [RoomStoreApp]
}

@MainActor
class RoomStoreViewModel: ObservableObject {
	@Published var allApps: [RoomStoreApp] = []
	@Published var favoriteIDs: Set<String> = []
	@Published var downloadingAppID: String? = nil
	@Published var isLoading = false

	private let defaultRepoURL = "https://raw.githubusercontent.com/hassan201211/123456qwert/refs/heads/main/apps.json"

	var todayFeatured: [RoomStoreApp] {
		let socialOrMedia = allApps.filter { $0.subCategory == "social" || $0.subCategory == "media" }
		return socialOrMedia.isEmpty ? Array(allApps.prefix(4)) : Array(socialOrMedia.prefix(4))
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
			allApps = Self.featuredStarterApps
		}
		guard let url = URL(string: defaultRepoURL) else { return }
		isLoading = true
		defer { isLoading = false }

		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let repo = try JSONDecoder().decode(RoomStoreRepo.self, from: data)
			var seenBundles = Set<String>()
			var uniqueApps: [RoomStoreApp] = []

			// إضافة تطبيق إنستغرام المعدل في المقدمة إذا لم يكن موجوداً في المستودع
			let hasInsta = repo.apps.contains { ($0.name.lowercased().contains("insta")) }
			if !hasInsta {
				uniqueApps.append(Self.instagramBeeApp)
				seenBundles.insert("com.burbn.instagram")
			}

			for app in repo.apps {
				let key = app.bundleId ?? app.name
				if !seenBundles.contains(key) {
					seenBundles.insert(key)
					uniqueApps.append(app)
				}
			}
			if !uniqueApps.isEmpty {
				self.allApps = uniqueApps
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

	func startInstall(_ app: RoomStoreApp) {
		guard let url = URL(string: app.downloadURL), !app.downloadURL.isEmpty else { return }
		downloadingAppID = app.id
		_ = DownloadManager.shared.startDownload(from: url, id: app.id)
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
			self.downloadingAppID = nil
		}
	}

	static let instagramBeeApp = RoomStoreApp(
		id: "instagram-bee-mod",
		name: "إنستغرام النحلة",
		subtitle: "تحميل الوسائط والقصص وإخفاء الظهور",
		description: "إصدار معدل من إنستغرام يتيح تحميل الصور والفيديوهات والريلز والقصص بجودة عالية مع إخفاء حالة القراءة والظهور.",
		category: "apps",
		subCategory: "social",
		featured: true,
		featuredTitle: "إصدار جديد للنحلة",
		featuredSubtitle: "انها دخلت في أعماق إنستغرام وغيرت الكثير",
		version: "350.0",
		size: "145.0 MB",
		minIOS: "iOS 15.0+",
		updatedAt: "حديثاً",
		downloads: "4.8K",
		languages: "العربية",
		bundleId: "com.burbn.instagram",
		iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/4b/98/0d/4b980d65-6b3e-8d1e-24a7-22e6f9814d12/Prod-0-0-1x_U007emarketing-0-7-0-85-220.png/512x512bb.jpg",
		bannerURL: nil,
		downloadURL: ""
	)

	static let featuredStarterApps: [RoomStoreApp] = [instagramBeeApp]
}

// MARK: - 2. واجهة اليوم (Today - بصور حقيقية + قسم الألعاب + قسم التطبيقات)
struct RoomTodayView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var selectedApp: RoomStoreApp? = nil
	@State private var showSettings = false

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				// 1. الترويسة + زر الإعدادات المفعّل
				HStack {
					VStack(alignment: .leading, spacing: 2) {
						Text("اليوم")
							.font(.system(size: 34, weight: .bold))
							.foregroundStyle(.white)
					}
					Spacer()
					Button {
						showSettings = true
					} label: {
						Circle()
							.fill(Color.blue)
							.frame(width: 36, height: 36)
							.overlay(
								Image(systemName: "gearshape.fill")
									.font(.subheadline.bold())
									.foregroundStyle(.white)
							)
					}
				}
				.padding(.horizontal)

				// 2. البطاقات المميزة الكبيرة بصور وأيقونات واضحة
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 16) {
						ForEach(viewModel.todayFeatured) { app in
							Button {
								selectedApp = app
							} label: {
								TodayVisualCard(app: app)
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.horizontal)
				}

				// 3. قسم الألعاب أسفل البطاقة الرئيسية
				if !viewModel.gamesList.isEmpty {
					VStack(alignment: .leading, spacing: 14) {
						HStack(spacing: 4) {
							Text("أبرز الألعاب")
								.font(.title2.bold())
								.foregroundStyle(.white)
							Image(systemName: "chevron.left")
								.font(.headline.bold())
								.foregroundStyle(.gray)
						}
						.padding(.horizontal)

						VStack(spacing: 12) {
							ForEach(viewModel.gamesList.prefix(4)) { game in
								Button {
									selectedApp = game
								} label: {
									RoomStoreAppRow(app: game)
										.padding(.horizontal)
								}
								.buttonStyle(.plain)
							}
						}
					}
				}

				// 4. قسم التطبيقات المعدلة أسفل الألعاب
				if !viewModel.appsList.isEmpty {
					VStack(alignment: .leading, spacing: 14) {
						HStack(spacing: 4) {
							Text("أبرز التطبيقات")
								.font(.title2.bold())
								.foregroundStyle(.white)
							Image(systemName: "chevron.left")
								.font(.headline.bold())
								.foregroundStyle(.gray)
						}
						.padding(.horizontal)

						VStack(spacing: 12) {
							ForEach(viewModel.appsList.prefix(6)) { app in
								Button {
									selectedApp = app
								} label: {
									RoomStoreAppRow(app: app)
										.padding(.horizontal)
								}
								.buttonStyle(.plain)
							}
						}
					}
				}
			}
			.padding(.top, 10)
			.padding(.bottom, 95)
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedApp) { app in
			RoomAppDetailView(app: app, viewModel: viewModel)
		}
		.sheet(isPresented: $showSettings) {
			TabEnum.view(for: .settings)
		}
	}
}

struct TodayVisualCard: View {
	let app: RoomStoreApp

	var body: some View {
		ZStack {
			// خلفية متوهجة من صورة التطبيق نفسها
			AsyncImage(url: URL(string: app.iconURL)) { image in
				image
					.resizable()
					.scaledToFill()
					.frame(width: 330, height: 320)
					.blur(radius: 26)
					.opacity(0.65)
			} placeholder: {
				LinearGradient(
					colors: [Color(red: 0.06, green: 0.25, blue: 0.42), Color(red: 0.02, green: 0.08, blue: 0.16)],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			}
			.frame(width: 330, height: 320)
			.clipped()

			LinearGradient(
				colors: [.black.opacity(0.15), .black.opacity(0.45), .black.opacity(0.92)],
				startPoint: .top,
				endPoint: .bottom
			)

			VStack(alignment: .leading, spacing: 12) {
				HStack {
					Text("تطبيق مميز")
						.font(.caption.bold())
						.padding(.horizontal, 10)
						.padding(.vertical, 5)
						.background(.ultraThinMaterial)
						.foregroundStyle(.white)
						.clipShape(Capsule())
					Spacer()
				}

				Spacer()

				// أيقونة التطبيق الحقيقية بحجم واضح
				RoomAppIconView(urlString: app.iconURL, size: 76, radius: 18)
					.shadow(color: .black.opacity(0.5), radius: 10, y: 5)

				HStack(alignment: .bottom) {
					VStack(alignment: .leading, spacing: 4) {
						Text(app.featuredTitle ?? app.name)
							.font(.title2.bold())
							.foregroundStyle(.white)
							.lineLimit(1)
						Text(app.featuredSubtitle ?? app.subtitle)
							.font(.caption)
							.foregroundStyle(.white.opacity(0.8))
							.lineLimit(2)
					}

					Spacer()

					Text("حصول")
						.font(.subheadline.bold())
						.padding(.horizontal, 18)
						.padding(.vertical, 7)
						.background(Color.white.opacity(0.22))
						.foregroundStyle(.white)
						.clipShape(Capsule())
				}
			}
			.padding(20)
		}
		.frame(width: 330, height: 320)
		.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
	}
}

// MARK: - 3. واجهة التطبيقات (Apps - مع شريط التصنيفات الأفقي)
struct RoomAppsView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var selectedFilter = "all"
	@State private var selectedApp: RoomStoreApp? = nil
	@State private var showSettings = false

	private struct AppFilterChip: Identifiable {
		let id: String
		let title: String
	}

	private let filters: [AppFilterChip] = [
		AppFilterChip(id: "all", title: "الكل"),
		AppFilterChip(id: "social", title: "إنستغرام وتواصل"),
		AppFilterChip(id: "media", title: "تصوير ومونتاج"),
		AppFilterChip(id: "tools", title: "أدوات"),
		AppFilterChip(id: "design", title: "تصميم وإنتاجية")
	]

	private var filteredApps: [RoomStoreApp] {
		if selectedFilter == "all" {
			return viewModel.appsList
		}
		return viewModel.appsList.filter { $0.subCategory == selectedFilter }
	}

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 18) {
				// الترويسة + زر الإعدادات
				HStack {
					Text("التطبيقات")
						.font(.system(size: 34, weight: .bold))
						.foregroundStyle(.white)
					Spacer()
					Button {
						showSettings = true
					} label: {
						Circle()
							.fill(Color(white: 0.16))
							.frame(width: 36, height: 36)
							.overlay(
								Image(systemName: "gearshape.fill")
									.font(.subheadline)
									.foregroundStyle(.white)
							)
					}
				}
				.padding(.horizontal)

				// شريط الكبسولات الأفقي (الكل / إنستغرام وتواصل / تصوير / أدوات / تصميم)
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 10) {
						ForEach(filters) { chip in
							let isSelected = (selectedFilter == chip.id)
							Button {
								withAnimation(.easeInOut(duration: 0.2)) {
									selectedFilter = chip.id
								}
							} label: {
								Text(chip.title)
									.font(.subheadline.bold())
									.padding(.horizontal, 18)
									.padding(.vertical, 9)
									.background(isSelected ? Color.blue : Color(white: 0.16))
									.foregroundStyle(.white)
									.clipShape(Capsule())
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.horizontal)
				}

				// بطاقات مميزة للتطبيقات في القسم المختار
				if !filteredApps.isEmpty {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 14) {
							ForEach(filteredApps.prefix(4)) { app in
								Button {
									selectedApp = app
								} label: {
									FeaturedHorizontalCard(app: app, badge: "تطبيق مميز")
								}
								.buttonStyle(.plain)
							}
						}
						.padding(.horizontal)
					}

					// القائمة العمودية للتطبيقات
					VStack(alignment: .leading, spacing: 14) {
						Text(filters.first(where: { $0.id == selectedFilter })?.title ?? "جميع التطبيقات")
							.font(.title2.bold())
							.foregroundStyle(.white)
							.padding(.horizontal)

						ForEach(filteredApps) { app in
							Button {
								selectedApp = app
							} label: {
								RoomStoreAppRow(app: app)
									.padding(.horizontal)
							}
							.buttonStyle(.plain)
						}
					}
				} else {
					VStack(spacing: 12) {
						Image(systemName: "square.stack.3d.up")
							.font(.largeTitle)
							.foregroundStyle(.gray)
						Text("لا توجد تطبيقات في هذا القسم حالياً")
							.foregroundStyle(.gray)
					}
					.frame(maxWidth: .infinity)
					.padding(.top, 70)
				}
			}
			.padding(.top, 10)
			.padding(.bottom, 95)
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedApp) { app in
			RoomAppDetailView(app: app, viewModel: viewModel)
		}
		.sheet(isPresented: $showSettings) {
			TabEnum.view(for: .settings)
		}
	}
}

// MARK: - 4. واجهة الألعاب (Games - بنفس التصميم مع تفعيل صور الألعاب في البطاقات العلوية)
struct RoomGamesView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var selectedApp: RoomStoreApp? = nil
	@State private var showSettings = false

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 22) {
				HStack {
					Text("الألعاب")
						.font(.system(size: 34, weight: .bold))
						.foregroundStyle(.white)
					Spacer()
					Button {
						showSettings = true
					} label: {
						Circle()
							.fill(Color(white: 0.16))
							.frame(width: 36, height: 36)
							.overlay(
								Image(systemName: "gearshape.fill")
									.font(.subheadline)
									.foregroundStyle(.white)
							)
					}
				}
				.padding(.horizontal)

				if viewModel.gamesList.isEmpty {
					VStack(spacing: 12) {
						Image(systemName: "gamecontroller")
							.font(.largeTitle)
							.foregroundStyle(.gray)
						Text("لا توجد ألعاب مضافة حالياً")
							.foregroundStyle(.gray)
					}
					.frame(maxWidth: .infinity)
					.padding(.top, 80)
				} else {
					// البطاقات العلوية مع صور وأيقونات الألعاب الحقيقية
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 14) {
							ForEach(viewModel.gamesList.prefix(4)) { game in
								Button {
									selectedApp = game
								} label: {
									FeaturedHorizontalCard(app: game, badge: "لعبة مميزة")
								}
								.buttonStyle(.plain)
							}
						}
						.padding(.horizontal)
					}

					VStack(alignment: .leading, spacing: 14) {
						Text("جميع الألعاب")
							.font(.title2.bold())
							.foregroundStyle(.white)
							.padding(.horizontal)

						ForEach(viewModel.gamesList) { game in
							Button {
								selectedApp = game
							} label: {
								RoomStoreAppRow(app: game)
									.padding(.horizontal)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
			.padding(.top, 10)
			.padding(.bottom, 95)
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedApp) { app in
			RoomAppDetailView(app: app, viewModel: viewModel)
		}
		.sheet(isPresented: $showSettings) {
			TabEnum.view(for: .settings)
		}
	}
}

struct FeaturedHorizontalCard: View {
	let app: RoomStoreApp
	let badge: String

	var body: some View {
		ZStack(alignment: .bottomLeading) {
			AsyncImage(url: URL(string: app.iconURL)) { image in
				image
					.resizable()
					.scaledToFill()
					.frame(width: 295, height: 185)
					.blur(radius: 22)
					.opacity(0.6)
			} placeholder: {
				LinearGradient(
					colors: [Color(red: 0.18, green: 0.12, blue: 0.35), Color.black],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			}
			.frame(width: 295, height: 185)
			.clipped()

			LinearGradient(
				colors: [.black.opacity(0.15), .black.opacity(0.88)],
				startPoint: .top,
				endPoint: .bottom
			)

			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 12) {
					RoomAppIconView(urlString: app.iconURL, size: 58, radius: 14)
						.shadow(color: .black.opacity(0.4), radius: 6, y: 3)

					VStack(alignment: .leading, spacing: 3) {
						Text(badge)
							.font(.caption.bold())
							.foregroundStyle(.blue)
						Text(app.name)
							.font(.title3.bold())
							.foregroundStyle(.white)
							.lineLimit(1)
					}
					Spacer()
				}

				Text(app.subtitle)
					.font(.caption)
					.foregroundStyle(.white.opacity(0.8))
					.lineLimit(1)
			}
			.padding(16)
		}
		.frame(width: 295, height: 185)
		.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}

// MARK: - 5. واجهة البحث (Search - تصميم App Store)
struct RoomSearchView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var searchText = ""
	@State private var selectedCategory: String? = nil
	@State private var selectedApp: RoomStoreApp? = nil
	@State private var showSettings = false

	private struct BrowseCat: Identifiable {
		let id = UUID()
		let title: String
		let key: String
		let icon: String
		let colors: [Color]
	}

	private let categories: [BrowseCat] = [
		BrowseCat(title: "إنستغرام\nوتواصل اجتماعي", key: "social", icon: "bubble.left.and.bubble.right.fill", colors: [Color(red: 0.35, green: 0.65, blue: 0.95), Color(red: 0.20, green: 0.45, blue: 0.85)]),
		BrowseCat(title: "الألعاب الأكثر\nتنزيلاً", key: "games", icon: "gamecontroller.fill", colors: [Color(red: 0.95, green: 0.62, blue: 0.35), Color(red: 0.85, green: 0.42, blue: 0.22)]),
		BrowseCat(title: "تصوير\nومونتاج فيديو", key: "media", icon: "play.tv.fill", colors: [Color(red: 0.25, green: 0.78, blue: 0.52), Color(red: 0.14, green: 0.58, blue: 0.38)]),
		BrowseCat(title: "تصميم\nوإنتاجية", key: "design", icon: "sparkles", colors: [Color(red: 0.62, green: 0.48, blue: 0.95), Color(red: 0.45, green: 0.30, blue: 0.80)]),
		BrowseCat(title: "أدوات\nوتخصيص", key: "tools", icon: "wrench.and.screwdriver.fill", colors: [Color(red: 0.95, green: 0.68, blue: 0.25), Color(red: 0.82, green: 0.50, blue: 0.15)]),
		BrowseCat(title: "التطبيقات الأكثر\nتنزيلاً", key: "apps", icon: "trophy.fill", colors: [Color(red: 0.30, green: 0.75, blue: 0.90), Color(red: 0.18, green: 0.55, blue: 0.78)])
	]

	private var filteredApps: [RoomStoreApp] {
		viewModel.allApps.filter { app in
			let matchesText = searchText.isEmpty ||
				app.name.localizedCaseInsensitiveContains(searchText) ||
				app.subtitle.localizedCaseInsensitiveContains(searchText)
			let matchesCat: Bool
			if let cat = selectedCategory {
				matchesCat = (cat == "apps") ? (app.category == "apps") : (app.subCategory == cat)
			} else {
				matchesCat = true
			}
			return matchesText && matchesCat
		}
	}

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 20) {
				HStack {
					Text("بحث")
						.font(.system(size: 34, weight: .bold))
						.foregroundStyle(.white)
					Spacer()
					Button {
						showSettings = true
					} label: {
						Circle()
							.fill(Color.white.opacity(0.15))
							.frame(width: 36, height: 36)
							.overlay(Image(systemName: "gearshape.fill").foregroundStyle(.white))
					}
				}
				.padding(.horizontal)

				HStack(spacing: 10) {
					Image(systemName: "magnifyingglass")
						.foregroundStyle(.gray)
					TextField("ألعاب وتطبيقات ومقالات والمزيد", text: $searchText)
						.foregroundStyle(.white)
					if !searchText.isEmpty {
						Button { searchText = "" } label: {
							Image(systemName: "xmark.circle.fill")
								.foregroundStyle(.gray)
						}
					} else {
						Image(systemName: "mic.fill")
							.foregroundStyle(.gray)
					}
				}
				.padding(.horizontal, 12)
				.padding(.vertical, 10)
				.background(Color(white: 0.12))
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
				.padding(.horizontal)

				VStack(alignment: .leading, spacing: 12) {
					HStack(spacing: 4) {
						Text(selectedCategory == nil ? "مقترحات" : "نتائج القسم")
							.font(.title2.bold())
							.foregroundStyle(.white)
						Image(systemName: "chevron.left")
							.font(.headline.bold())
							.foregroundStyle(.gray)
						Spacer()
						if selectedCategory != nil {
							Button("عرض الكل") {
								withAnimation { selectedCategory = nil }
							}
							.font(.subheadline)
							.foregroundStyle(.blue)
						}
					}
					.padding(.horizontal)

					VStack(spacing: 10) {
						ForEach(Array(filteredApps.prefix(5).enumerated()), id: \.element.id) { index, app in
							let isFirstFeatured = (index == 0 && searchText.isEmpty && selectedCategory == nil)
							Button {
								selectedApp = app
							} label: {
								HStack(spacing: 12) {
									RoomAppIconView(urlString: app.iconURL, size: 58, radius: 14)

									VStack(alignment: .leading, spacing: 3) {
										Text(app.name)
											.font(.headline)
											.foregroundStyle(.white)
											.lineLimit(1)
										Text(app.subtitle)
											.font(.caption)
											.foregroundStyle(.gray)
											.lineLimit(1)

										if isFirstFeatured {
											Text("مميز")
												.font(.system(size: 10, weight: .bold))
												.padding(.horizontal, 6)
												.padding(.vertical, 2)
												.background(Color.blue.opacity(0.25))
												.foregroundStyle(.blue)
												.clipShape(RoundedRectangle(cornerRadius: 4))
												.padding(.top, 2)
										}
									}

									Spacer()

									Text("حصول")
										.font(.subheadline.bold())
										.padding(.horizontal, 18)
										.padding(.vertical, 6)
										.background(Color.white.opacity(0.16))
										.foregroundStyle(.blue)
										.clipShape(Capsule())
								}
								.padding(isFirstFeatured ? 12 : 4)
								.background(
									RoundedRectangle(cornerRadius: 16, style: .continuous)
										.fill(isFirstFeatured ? Color(white: 0.13) : Color.clear)
								)
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.horizontal)
				}

				if searchText.isEmpty {
					VStack(alignment: .leading, spacing: 12) {
						HStack(spacing: 4) {
							Text("تصفح")
								.font(.title2.bold())
								.foregroundStyle(.white)
							Image(systemName: "chevron.left")
								.font(.headline.bold())
								.foregroundStyle(.gray)
						}
						.padding(.horizontal)

						LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
							ForEach(categories) { cat in
								Button {
									withAnimation(.easeInOut(duration: 0.2)) {
										selectedCategory = cat.key
									}
								} label: {
									ZStack {
										LinearGradient(colors: cat.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
										VStack {
											HStack {
												Spacer()
												Image(systemName: cat.icon)
													.font(.system(size: 28, weight: .semibold))
													.foregroundStyle(.white.opacity(0.85))
											}
											Spacer()
											HStack {
												Text(cat.title)
													.font(.system(size: 15, weight: .bold))
													.foregroundStyle(.white)
													.multilineTextAlignment(.leading)
													.lineLimit(2)
												Spacer()
											}
										}
										.padding(12)
									}
									.frame(height: 105)
									.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
								}
								.buttonStyle(.plain)
							}
						}
						.padding(.horizontal)
					}
				}
			}
			.padding(.top, 10)
			.padding(.bottom, 95)
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedApp) { app in
			RoomAppDetailView(app: app, viewModel: viewModel)
		}
		.sheet(isPresented: $showSettings) {
			TabEnum.view(for: .settings)
		}
	}
}

// MARK: - 6. صفحة تفاصيل التطبيق والتثبيت الكاملة
struct RoomAppDetailView: View {
	let app: RoomStoreApp
	@ObservedObject var viewModel: RoomStoreViewModel

	@Environment(\.dismiss) private var dismiss
	@State private var selectedTab = 0
	@State private var copiedBundle = false
	@State private var showReportAlert = false
	@State private var showStartedBanner = false
	@State private var selectedSimilarApp: RoomStoreApp? = nil

	private var similarApps: [RoomStoreApp] {
		Array(viewModel.allApps.filter { $0.id != app.id }.prefix(10))
	}

	private var isStartingInstall: Bool {
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

						if showStartedBanner {
							HStack(spacing: 8) {
								Image(systemName: "arrow.down.circle.fill")
								Text("بدأ التحميل! افتح تبويب المصادر > المكتبة (IPA) لتوقيع التطبيق وتثبيته.")
									.font(.caption.bold())
							}
							.foregroundStyle(.white)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(Color.blue.opacity(0.28))
							.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
						}

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
					if let shareURL = URL(string: app.downloadURL), !app.downloadURL.isEmpty {
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
					viewModel.startInstall(app)
					withAnimation { showStartedBanner = true }
				} label: {
					HStack(spacing: 8) {
						if isStartingInstall {
							ProgressView().tint(.white)
							Text("جاري إرسال الملف للمكتبة...")
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
					.background(app.downloadURL.isEmpty ? Color.gray : Color.blue)
					.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
				}
				.disabled(app.downloadURL.isEmpty || isStartingInstall)

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
			RoomAppDetailView(app: nextApp, viewModel: viewModel)
		}
		.alert("الإبلاغ عن مشكلة", isPresented: $showReportAlert) {
			Button("حسناً", role: .cancel) { }
		} message: {
			Text("تم إرسال بلاغك بخصوص \(app.name) وسيتم فحص الرابط قريباً.")
		}
	}
}

// MARK: - 7. المكونات المساعدة
struct RoomStoreAppRow: View {
	let app: RoomStoreApp

	var body: some View {
		HStack(spacing: 12) {
			RoomAppIconView(urlString: app.iconURL, size: 60, radius: 14)

			VStack(alignment: .leading, spacing: 4) {
				Text(app.name)
					.font(.headline)
					.foregroundStyle(.white)
					.lineLimit(1)
				Text(app.subtitle)
					.font(.caption)
					.foregroundStyle(.gray)
					.lineLimit(1)
			}

			Spacer()

			Text("حصول")
				.font(.subheadline.bold())
				.padding(.horizontal, 18)
				.padding(.vertical, 6)
				.background(Color.white.opacity(0.15))
				.foregroundStyle(.blue)
				.clipShape(Capsule())
		}
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
