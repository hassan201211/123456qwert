//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case today
    case games
    case apps
    case sources
    case search
    
    // الأقسام القديمة نحتفظ بها كي لا تحدث أخطاء برمجية
    case library
    case settings
    case certificates
    
    var title: String {
        switch self {
        case .today:        return "اليوم"
        case .games:        return "الألعاب"
        case .apps:         return "التطبيقات"
        case .sources:      return "المصادر"
        case .search:       return "البحث"
            
        case .library:      return .localized("Library")
        case .settings:     return .localized("Settings")
        case .certificates: return .localized("Certificates")
        }
    }
    
    var icon: String {
        switch self {
        case .today:        return "doc.text.image"
        case .games:        return "gamecontroller.fill"
        case .apps:         return "square.stack.3d.up.fill"
        case .sources:      return "cart.fill" // أيقونة متجر مشابهة لمتجر آبل
        case .search:       return "magnifyingglass"
            
        case .library:      return "square.grid.2x2"
        case .settings:     return "gearshape.2"
        case .certificates: return "person.text.rectangle"
        }
    }
    
    @ViewBuilder
    static func view(for tab: TabEnum) -> some View {
        switch tab {
        case .today: 
            TodayWrapperView()
        case .games: 
            NBNavigationView("الألعاب") { Text("قسم الألعاب سيتم إضافته قريباً") }
        case .apps: 
            NBNavigationView("التطبيقات") { LibraryView() } // يفتح قائمة التطبيقات الأساسية
        case .sources: 
            SourcesView()
        case .search: 
            NBNavigationView("البحث") { Text("قسم البحث سيتم إضافته قريباً") }
            
        case .library: LibraryView()
        case .settings: SettingsView()
        case .certificates: NBNavigationView(.localized("Certificates")) { CertificatesView() }
        }
    }
    
    static var defaultTabs: [TabEnum] {
        // ترتيب التبويبات في الشريط السفلي
        return [
            .today,
            .games,
            .apps,
            .sources,
            .search
        ]
    }
    
    static var customizableTabs: [TabEnum] {
        return [
            .certificates,
            .settings
        ]
    }
}

// MARK: - تصميم صفحة "اليوم" مع زر النجمة
struct TodayWrapperView: View {
    @State private var showSettings = false
    
    var body: some View {
        NBNavigationView("اليوم") {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // تصميم بطاقة بارزة تشبه متجر آبل
                    ZStack(alignment: .bottom) {
                        // لون الخلفية أو صورة
                        Color.blue.opacity(0.3)
                            .frame(height: 350)
                            .cornerRadius(20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("اصدار جديد للنحلة")
                                .font(.title).bold()
                                .foregroundColor(.white)
                            
                            Text("انها دخلت في اعماق انستكرام وغيرت الكثير")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(20)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // يمكن إضافة المزيد من البطاقات هنا لاحقاً
                }
            }
            // زر النجمة في الأعلى (يفتح الإعدادات)
            .navigationBarItems(leading:
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.blue))
                }
            )
        }
        // عرض شاشة الإعدادات عند الضغط
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
