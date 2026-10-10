//
//  SourceAppsDetailView.swift
//  Feather
//
//  Created by samsam on 7/25/25.
//  Redesigned to Apple App Store Style
//

import SwiftUI
import Combine
import AltSourceKit
import NimbleViews
import NukeUI

// MARK: - SourceAppsDetailView
struct SourceAppsDetailView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var _downloadProgress: Double = 0
    @State var cancellable: AnyCancellable?
    @State private var _isScreenshotPreviewPresented: Bool = false
    @State private var _selectedScreenshotIndex: Int = 0
    
    var currentDownload: Download? {
        downloadManager.getDownload(by: app.currentUniqueId)
    }
    
    let sourceURL: URL?
    let source: ASRepository
    let app: ASRepository.App
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // 1. الهيدر (الأيقونة، الاسم، المطور، زر التثبيت)
                HStack(alignment: .top, spacing: 16) {
                    if let iconURL = app.iconURL {
                        LazyImage(url: iconURL) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 118, height: 118)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                            } else {
                                standardIcon
                            }
                        }
                    } else {
                        standardIcon
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.currentName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(app.developer ?? source.name ?? "المطور")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // زر التحميل الأزرق
                        DownloadButtonView(sourceURL: sourceURL, source: source, app: app)
                            .font(.system(size: 15, weight: .bold))
                            .frame(height: 30)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 2. شريط الإحصائيات (التقييم، العمر، الحجم)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 30) {
                        _statItem(top: "4.8", middle: "★★★★★", bottom: "11 ألف تقييم")
                        Divider().frame(height: 40)
                        _statItem(top: "التصنيف العمري", middle: "12+", bottom: "سنة")
                        Divider().frame(height: 40)
                        _statItem(top: "الفئة", middle: app.category ?? "أدوات", bottom: "تطبيقات")
                        Divider().frame(height: 40)
                        _statItem(top: "الحجم", middle: app.size?.formattedByteCount ?? "N/A", bottom: "ميجابايت")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                Divider().padding(.leading, 20)
                
                // 3. قسم الصور (Screenshots)
                if let screenshotURLs = app.screenshotURLs {
                    VStack(alignment: .leading) {
                        _screenshots(screenshotURLs: screenshotURLs)
                    }
                    .padding(.vertical, 16)
                    
                    Divider().padding(.leading, 20)
                }
                
                // 4. قسم "ما الجديد"
                if let currentVer = app.currentVersion,
                   let whatsNewDesc = app.currentAppVersion?.localizedDescription {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("ما الجديد")
                                .font(.title3.bold())
                            Spacer()
                            NavigationLink(destination: VersionHistoryView(sourceURL: sourceURL, source: source, app: app, versions: app.versions ?? [])) {
                                Text("سجل الإصدارات")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack {
                            Text("الإصدار \(currentVer)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let date = app.currentDate?.date {
                                Text(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(whatsNewDesc)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(4)
                    }
                    .padding(20)
                    
                    Divider().padding(.leading, 20)
                }
                
                // 5. قسم الوصف
                if let appDesc = app.localizedDescription {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("الوصف")
                            .font(.title3.bold())
                        ExpandableText(text: appDesc, lineLimit: 4)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(20)
                    
                    Divider().padding(.leading, 20)
                }
                
                // 6. قسم المعلومات
                VStack(alignment: .leading, spacing: 16) {
                    Text("المعلومات")
                        .font(.title3.bold())
                    
                    VStack(spacing: 12) {
                        if let developer = app.developer { _infoRow(title: "المطور", value: developer) }
                        if let size = app.size { _infoRow(title: "الحجم", value: size.formattedByteCount) }
                        if let category = app.category { _infoRow(title: "الفئة", value: category.capitalized) }
                        if let version = app.currentVersion { _infoRow(title: "الإصدار", value: version) }
                        if let bundleId = app.id { _infoRow(title: "المُعرِّف", value: bundleId) }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NBToolbarButton(systemImage: "square.and.arrow.up", placement: .topBarTrailing) {
                let sharedString = "\(app.currentName)\n\(app.currentDescription ?? "")\n\(source.website?.absoluteString ?? "")"
                UIActivityViewController.show(activityItems: [sharedString])
            }
        }
        .fullScreenCover(isPresented: $_isScreenshotPreviewPresented) {
            if let screenshotURLs = app.screenshotURLs {
                ScreenshotPreviewView(screenshotURLs: screenshotURLs, initialIndex: _selectedScreenshotIndex)
            }
        }
    }
    
    var standardIcon: some View {
        Image("App_Unknown")
            .resizable()
            .frame(width: 118, height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - App Store Style Components
extension SourceAppsDetailView {
    
    @ViewBuilder
    private func _statItem(top: String, middle: String, bottom: String) -> some View {
        VStack(spacing: 4) {
            Text(top)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            Text(middle)
                .font(.headline)
                .foregroundColor(.gray)
                .fontWeight(.bold)
            Text(bottom)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
    }
    
    @ViewBuilder
    private func _infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        Divider()
    }
    
    @ViewBuilder
    private func _screenshots(screenshotURLs: [URL]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(screenshotURLs.indices, id: \.self) { index in
                    let url = screenshotURLs[index]
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                                }
                                .onTapGesture {
                                    _selectedScreenshotIndex = index
                                    _isScreenshotPreviewPresented = true
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 146, height: 260)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
