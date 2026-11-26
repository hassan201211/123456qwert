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
		} else if key.contains("البحث") || key.contains("بحث") || key.contains("search") {
			RoomSearchView(viewModel: roomStoreVM)
		} else {
			TabEnum.view(for: tab)
		}
	}
}

// MARK: - 1. نماذج البيانات وجلب الملف من GitHub
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
		let lowerName = resolvedName.lowercased()
		let isGame = (appType == 2) || lowerName.contains("game") || lowerName.contains("piano") || lowerName.contains("gta") || lowerName.contains("minecraft")
		self.category = isGame ? "games" : "apps"

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
	@Published var downloadProgress: Double = 0.0
	@Published var isLoading = false

	private let defaultRepoURL = "https://raw.githubusercontent.com/hassan201211/123456qwert/refs/heads/main/apps.json"

	var todayFeatured: [RoomStoreApp] {
		let list = allApps.filter { $0.featured == true }
		return list.isEmpty ? Array(allApps.prefix(5)) : list
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
			var seenBundles = Set<String>()
			var uniqueApps: [RoomStoreApp] = []
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

	func downloadAndImport(_ app: RoomStoreApp, onComplete: ((URL) -> Void)? = nil) {
		guard let url = URL(string: app.downloadURL), downloadingAppID == nil else { return }
		downloadingAppID = app.id
		downloadProgress = 0.2

		Task {
			do {
				let (tempURL, _) = try await URLSession.shared.download(from: url)
				self.downloadProgress = 0.85
				let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
				let destURL = docs.appendingPathComponent("\(app.name)_\(app.version).ipa")
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

// MARK: - 2. واجهة اليوم (Today)
struct RoomTodayView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var selectedApp: RoomStoreApp? = nil

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 22) {
				HStack {
					Text("اليوم")
						.font(.system(size: 34, weight: .bold))
						.foregroundStyle(.white)
					Spacer()
					Circle()
						.fill(Color.blue)
						.frame(width: 34, height: 34)
						.overlay(
							Image(systemName: "star.fill")
								.font(.subheadline)
								.foregroundStyle(.white)
						)
				}
				.padding(.horizontal)

				ForEach(viewModel.todayFeatured) { app in
					Button {
						selectedApp = app
					} label: {
						ZStack(alignment: .bottomLeading) {
							if let banner = app.bannerURL, let url = URL(string: banner), !banner.isEmpty {
								AsyncImage(url: url) { image in
									image.resizable().scaledToFill()
								} placeholder: {
									todayGradient
								}
							} else {
								todayGradient
							}

							LinearGradient(
								colors: [.clear, .black.opacity(0.85)],
								startPoint: .center,
								endPoint: .bottom
							)

							VStack(alignment: .leading, spacing: 6) {
								Text(app.featuredTitle ?? app.name)
									.font(.title.bold())
									.foregroundStyle(.white)
								Text(app.featuredSubtitle ?? app.subtitle)
									.font(.subheadline)
									.foregroundStyle(.white.opacity(0.8))
							}
							.padding(20)
						}
						.frame(height: 320)
						.frame(maxWidth: .infinity)
						.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
						.padding(.horizontal)
					}
					.buttonStyle(.plain)
				}

				if !viewModel.allApps.isEmpty {
					VStack(alignment: .leading, spacing: 14) {
						Text("أبرز التطبيقات المعدلة")
							.font(.title2.bold())
							.foregroundStyle(.white)
							.padding(.horizontal)

						ForEach(viewModel.allApps) { app in
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
			.padding(.top, 10)
			.padding(.bottom, 90)
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedApp) { app in
			RoomAppDetailView(app: app, viewModel: viewModel)
		}
	}

	private var todayGradient: some View {
		LinearGradient(
			colors: [Color(red: 0.04, green: 0.22, blue: 0.35), Color(red: 0.02, green: 0.08, blue: 0.14)],
			startPoint: .top,
			endPoint: .bottom
		)
	}
}

// MARK: - 3. واجهة الألعاب (Games)
struct RoomGamesView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var selectedApp: RoomStoreApp? = nil

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 22) {
				Text("الألعاب")
					.font(.system(size: 34, weight: .bold))
					.foregroundStyle(.white)
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
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 14) {
							ForEach(viewModel.gamesList.prefix(3)) { game in
								Button {
									selectedApp = game
								} label: {
									ZStack(alignment: .bottomLeading) {
										LinearGradient(
											colors: [Color(red: 0.18, green: 0.12, blue: 0.35), Color.black],
											startPoint: .topLeading,
											endPoint: .bottomTrailing
										)

										VStack(alignment: .leading, spacing: 4) {
											Text("لعبة مميزة")
												.font(.caption.bold())
												.foregroundStyle(.blue)
											Text(game.name)
												.font(.title2.bold())
												.foregroundStyle(.white)
											Text(game.subtitle)
												.font(.caption)
												.foregroundStyle(.white.opacity(0.75))
										}
										.padding(16)
									}
									.frame(width: 290, height: 180)
									.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
			.padding(.bottom, 90)
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedApp) { app in
			RoomAppDetailView(app: app, viewModel: viewModel)
		}
	}
}

// MARK: - 4. واجهة البحث (Search - تصميم App Store)
struct RoomSearchView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var searchText = ""
	@State private var selectedCategory: String? = nil
	@State private var selectedApp: RoomStoreApp? = nil

	private struct BrowseCat: Identifiable {
		let id = UUID()
		let title: String
		let key: String
		let icon: String
		let colors: [Color]
	}

	private let categories: [BrowseCat] = [
		BrowseCat(title: "التطبيقات الأكثر\nتنزيلاً", key: "apps", icon: "trophy.fill", colors: [Color(red: 0.35, green: 0.65, blue: 0.95), Color(red: 0.20, green: 0.45, blue: 0.85)]),
		BrowseCat(title: "الألعاب الأكثر\nتنزيلاً", key: "games", icon: "gamecontroller.fill", colors: [Color(red: 0.95, green: 0.62, blue: 0.35), Color(red: 0.85, green: 0.42, blue: 0.22)]),
		BrowseCat(title: "تطبيقات\nالبث والمشاهدة", key: "apps", icon: "play.tv.fill", colors: [Color(red: 0.25, green: 0.78, blue: 0.52), Color(red: 0.14, green: 0.58, blue: 0.38)]),
		BrowseCat(title: "ألعاب\nمعدلة ومفتوحة", key: "games", icon: "sparkles", colors: [Color(red: 0.62, green: 0.48, blue: 0.95), Color(red: 0.45, green: 0.30, blue: 0.80)]),
		BrowseCat(title: "أدوات\nوتخصيص", key: "apps", icon: "wrench.and.screwdriver.fill", colors: [Color(red: 0.95, green: 0.68, blue: 0.25), Color(red: 0.82, green: 0.50, blue: 0.15)]),
		BrowseCat(title: "تواصل\nاجتماعي", key: "apps", icon: "bubble.left.and.bubble.right.fill", colors: [Color(red: 0.30, green: 0.75, blue: 0.90), Color(red: 0.18, green: 0.55, blue: 0.78)])
	]

	private var filteredApps: [RoomStoreApp] {
		viewModel.allApps.filter { app in
			let matchesText = searchText.isEmpty ||
				app.name.localizedCaseInsensitiveContains(searchText) ||
				app.subtitle.localizedCaseInsensitiveContains(searchText)
			let matchesCat = selectedCategory == nil || app.category == selectedCategory
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
					Circle()
						.fill(Color.white.opacity(0.15))
						.frame(width: 36, height: 36)
						.overlay(Image(systemName: "person.fill").foregroundStyle(.white))
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
						ForEach(Array(filteredApps.prefix(4).enumerated()), id: \.element.id) { index, app in
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
			.padding(.bottom, 90)
		}
		.background(Color.black.ignoresSafeArea())
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedApp) { app in
			RoomAppDetailView(app: app, viewModel: viewModel)
		}
	}
}

// MARK: - 5. صفحة تفاصيل التطبيق والتثبيت الكاملة
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
		Array(viewModel.allApps.filter { $0.id != app.id }.prefix(10))
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

// MARK: - 6. المكونات المساعدة
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
