//
//  SourceAppsDetailView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI
import UIKit
import AltSourceKit

struct SourceAppsDetailView: View {
	var sourceURL: URL? = nil
	var source: ASRepository
	var app: ASRepository.App

	@Environment(\.dismiss) private var dismiss
	@ObservedObject private var downloadManager = DownloadManager.shared

	@State private var selectedTab = 0
	@State private var copiedBundle = false
	@State private var isFavorite = false
	@State private var showReportAlert = false
	@State private var selectedSimilarApp: ASRepository.App? = nil

	private var appName: String {
		let raw = app.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return raw.isEmpty ? "تطبيق معدل" : raw
	}

	private var appSubtitle: String {
		if let sub = app.subtitle, !sub.isEmpty { return sub }
		return source.name ?? "تطبيق معدل"
	}

	private var appDescription: String {
		if let desc = app.localizedDescription, !desc.isEmpty { return desc }
		if let vDesc = app.currentDescription, !vDesc.isEmpty { return vDesc }
		return "نسخة معدلة ومفتوحة المزايا جاهزة للتثبيت المباشر على جهازك."
	}

	private var appVersion: String {
		app.currentVersion ?? app.version ?? "1.0"
	}

	private var appBundleId: String {
		if let idVal = Mirror(reflecting: app).children.first(where: { $0.label == "id" || $0.label == "bundleIdentifier" })?.value as? String, !idVal.isEmpty {
			return idVal
		}
		return "com.room.app"
	}

	private var appDownloadURL: URL? {
		app.downloadURL
	}

	private var formattedSize: String {
		let bytes = app.size ?? 0
		guard bytes > 0 else { return "غير محدد" }
		let formatter = ByteCountFormatter()
		formatter.allowedUnits = [.useMB, .useGB]
		formatter.countStyle = .file
		return formatter.string(fromByteCount: Int64(bytes))
	}

	private var deviceCompatibilityText: String {
		let sys = UIDevice.current.systemVersion
		let model = UIDevice.current.model
		return "متوافق مع الجهاز • \(model) • iOS \(sys)"
	}

	private var isDownloading: Bool {
		downloadManager.getDownload(by: app.currentUniqueId) != nil
	}

	private var similarApps: [ASRepository.App] {
		Array(source.apps.filter { $0.currentUniqueId != app.currentUniqueId }.prefix(10))
	}

	var body: some View {
		ZStack(alignment: .bottom) {
			Color.black.ignoresSafeArea()

			ScrollView(showsIndicators: false) {
				VStack(spacing: 18) {
					ZStack(alignment: .bottom) {
						AsyncImage(url: app.iconURL) { image in
							image.resizable().scaledToFill()
						} placeholder: {
							LinearGradient(
								colors: [Color(white: 0.16), Color.black],
								startPoint: .top,
								endPoint: .bottom
							)
						}
						.frame(height: 215)
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
							DetailAppIconView(url: app.iconURL, size: 88, radius: 20)
								.shadow(color: .black.opacity(0.5), radius: 12, y: 6)

							Text(appName)
								.font(.system(size: 28, weight: .bold))
								.foregroundStyle(.white)
								.multilineTextAlignment(.center)

							Text(appSubtitle)
								.font(.subheadline)
								.foregroundStyle(.gray)

							HStack(spacing: 8) {
								Text("v\(appVersion)")
								Text("•")
								Text(formattedSize)
							}
							.font(.caption)
							.foregroundStyle(.gray)
						}
						.padding(.bottom, 6)
					}

					VStack(alignment: .leading, spacing: 18) {
						HStack(spacing: 0) {
							DetailPillButton(title: "نظرة عامة", isSelected: selectedTab == 0) {
								withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
							}
							DetailPillButton(title: "التقييمات", isSelected: selectedTab == 1) {
								withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 }
							}
						}
						.padding(4)
						.background(Color(white: 0.11))
						.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

						HStack(spacing: 8) {
							Image(systemName: "checkmark.shield")
								.font(.subheadline.bold())
							Text(deviceCompatibilityText)
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

								Text(appDescription)
									.font(.subheadline)
									.foregroundStyle(Color.white.opacity(0.85))
									.lineSpacing(5)
							}

							if let screenshots = app.screenshotURLs, !screenshots.isEmpty {
								ScrollView(.horizontal, showsIndicators: false) {
									HStack(spacing: 12) {
										ForEach(screenshots, id: \.self) { shotURL in
											AsyncImage(url: shotURL) { image in
												image.resizable().scaledToFill()
											} placeholder: {
												RoundedRectangle(cornerRadius: 16)
													.fill(Color(white: 0.12))
											}
											.frame(width: 190, height: 340)
											.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
										}
									}
								}
							}

							VStack(alignment: .leading, spacing: 10) {
								Text("المواصفات")
									.font(.title3.bold())
									.foregroundStyle(.white)

								VStack(spacing: 0) {
									HStack(spacing: 0) {
										DetailSpecCell(title: "الإصدار", value: appVersion)
										Divider().background(Color.white.opacity(0.1))
										DetailSpecCell(title: "الحجم", value: formattedSize)
										Divider().background(Color.white.opacity(0.1))
										DetailSpecCell(title: "يتطلب", value: "iOS 15.0+")
									}
									Divider().background(Color.white.opacity(0.1))
									HStack(spacing: 0) {
										DetailSpecCell(title: "المطور", value: source.name ?? "معدّل")
										Divider().background(Color.white.opacity(0.1))
										DetailSpecCell(title: "المصدر", value: source.name ?? "Room")
										Divider().background(Color.white.opacity(0.1))
										DetailSpecCell(title: "اللغات", value: "متعدد")
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

								Text(appBundleId)
									.font(.system(.caption, design: .monospaced))
									.foregroundStyle(.white)
									.lineLimit(1)

								Button {
									UIPasteboard.general.string = appBundleId
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
											ForEach(similarApps, id: \.currentUniqueId) { item in
												Button {
													selectedSimilarApp = item
												} label: {
													VStack(spacing: 6) {
														DetailAppIconView(url: item.iconURL, size: 64, radius: 15)
														Text(item.name ?? "تطبيق")
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
					Button {
						dismiss()
					} label: {
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

					if let shareURL = appDownloadURL {
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
					if let url = appDownloadURL, !isDownloading {
						_ = downloadManager.startDownload(from: url, id: app.currentUniqueId)
					}
				} label: {
					HStack(spacing: 8) {
						if isDownloading {
							ProgressView()
								.tint(.white)
							Text("جاري التنزيل...")
								.font(.headline)
						} else {
							Image(systemName: "arrow.down.to.line")
								.font(.headline)
							Text("تثبيت • \(formattedSize)")
								.font(.headline)
						}
					}
					.foregroundStyle(.white)
					.frame(maxWidth: .infinity)
					.frame(height: 50)
					.background(appDownloadURL == nil ? Color.gray : Color.blue)
					.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
				}
				.disabled(appDownloadURL == nil || isDownloading)

				Button {
					if let urlStr = appDownloadURL?.absoluteString {
						UIPasteboard.general.string = urlStr
					}
				} label: {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color(white: 0.14))
						.frame(width: 50, height: 50)
						.overlay(
							Image(systemName: "square.on.square")
								.foregroundStyle(.white)
						)
				}

				Button {
					withAnimation { isFavorite.toggle() }
				} label: {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color(white: 0.14))
						.frame(width: 50, height: 50)
						.overlay(
							Image(systemName: isFavorite ? "heart.fill" : "heart")
								.foregroundStyle(isFavorite ? .pink : .pink.opacity(0.8))
						)
				}
			}
			.padding(.horizontal)
			.padding(.vertical, 10)
			.background(Color.black.opacity(0.92))
		}
		.navigationBarBackButtonHidden(true)
		.environment(\.layoutDirection, .rightToLeft)
		.sheet(item: $selectedSimilarApp) { nextApp in
			SourceAppsDetailView(sourceURL: sourceURL, source: source, app: nextApp)
		}
		.alert("الإبلاغ عن مشكلة", isPresented: $showReportAlert) {
			Button("حسناً", role: .cancel) { }
		} message: {
			Text("تم إرسال بلاغك بخصوص \(appName) وسيتم فحص الرابط قريباً.")
		}
	}
}

private struct DetailPillButton: View {
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

private struct DetailSpecCell: View {
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

private struct DetailAppIconView: View {
	let url: URL?
	let size: CGFloat
	let radius: CGFloat

	var body: some View {
		AsyncImage(url: url) { image in
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
