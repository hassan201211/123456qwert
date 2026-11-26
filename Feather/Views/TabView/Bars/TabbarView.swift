//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

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
		switch tab.title {
		case "اليوم":
			RoomTodayView(viewModel: roomStoreVM)
		case "الألعاب":
			RoomGamesView(viewModel: roomStoreVM)
		case "البحث":
			RoomSearchView(viewModel: roomStoreVM)
		default:
			TabEnum.view(for: tab)
		}
	}
}

// MARK: - 1. واجهة اليوم (Today)
struct RoomTodayView: View {
	@ObservedObject var viewModel: RoomStoreViewModel
	@State private var selectedApp: RoomStoreApp? = nil

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 22) {
				// الترويسة
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

				// البطاقات المميزة الكبيرة
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

				// قائمة أبرز التطبيقات أسفل البطاقة
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

// MARK: - 2. واجهة الألعاب (Games)
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
					// بطاقات أفقية مميزة للألعاب
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

					// القائمة العمودية للألعاب
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

// MARK: - 3. واجهة البحث (Search - تصميم App Store)
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
				// الترويسة
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

				// شريط البحث الداكن
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

				// قسم مقترحات
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

				// قسم تصفح (شبكة البطاقات الملونة)
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

// MARK: - صف التطبيق الموحد
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
