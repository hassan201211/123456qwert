//
//  LibraryCellView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
struct LibraryCellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.editMode) private var editMode
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var _signedUpdateConfirmation: AppUpdate?
    @State private var _isSignedUpdateConfirmationPresented = false

    var certInfo: Date.ExpirationInfo? {
        Storage.shared.getCertificate(from: app)?.expiration?.expirationInfo()
    }
    
    var certRevoked: Bool {
        Storage.shared.getCertificate(from: app)?.revoked == true
    }
    
    var app: AppInfoPresentable
    @Binding var selectedInfoAppPresenting: AnyApp?
    @Binding var selectedSigningAppPresenting: AnyApp?
    @Binding var selectedInstallAppPresenting: AnyApp?
    @Binding var selectedAppUUIDs: Set<String>
    
    // MARK: Selections
    private var _isSelected: Bool {
        guard let uuid = app.uuid else { return false }
        return selectedAppUUIDs.contains(uuid)
    }
    
    private func _toggleSelection() {
        guard let uuid = app.uuid else { return }
        if selectedAppUUIDs.contains(uuid) {
            selectedAppUUIDs.remove(uuid)
        } else {
            selectedAppUUIDs.insert(uuid)
        }
    }
    
    // MARK: Body
    var body: some View {
        let isRegular = horizontalSizeClass != .compact
        let isEditing = editMode?.wrappedValue == .active
        
        HStack(spacing: 12) {
            // Checkmark for editing mode
            if isEditing {
                Button {
                    _toggleSelection()
                } label: {
                    Image(systemName: _isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(_isSelected ? .blue : .secondary)
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
            
            // 1. App Icon
            _appIcon(for: app)
            
            // 2. App Name and Subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name ?? .localized("Unknown"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(_desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 3. Action Buttons (Install/Update)
            if !isEditing {
                _buttonActions(for: app)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isRegular ? 12 : 0)
        .background(
            isRegular
                ? RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(_isSelected && isEditing ? Color.blue.opacity(0.1) : Color(.clear))
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                _toggleSelection()
            }
        }
        .swipeActions {
            if !isEditing {
                _actions(for: app)
            }
        }
        .contextMenu {
            if !isEditing {
                _contextActions(for: app)
                Divider()
                _contextActionsExtra(for: app)
                Divider()
                _actions(for: app)
            }
        }
        .confirmationDialog(
            .localized("Update Available"),
            isPresented: $_isSignedUpdateConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(.localized("Install Current Version"), systemImage: "square.and.arrow.down") {
                selectedInstallAppPresenting = AnyApp(base: app)
            }
            if let update = _signedUpdateConfirmation {
                Button(.localized("Download Update"), systemImage: "arrow.down.circle") {
                    _startUpdateDownload(update)
                }
            }
            Button(.localized("Cancel"), role: .cancel) {}
        } message: {
            if let update = _signedUpdateConfirmation {
                Text(verbatim: "\(update.appName) \(update.remoteVersion)")
            }
        }
    }
    
    private var _desc: String {
        if let version = app.version {
            return version
        } else {
            return .localized("Unknown")
        }
    }
}


// MARK: - Extension: View
extension LibraryCellView {
    
    // MARK: App Icon Style (App Store Look)
    private func _appIcon(for app: AppInfoPresentable) -> some View {
        FRAppIconView(app: app, size: 60)
            .cornerRadius(12) // استدارة زوايا الأيقونة
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1) // ظل خفيف للأيقونة
            // إزالة أيقونة التحديث الدائرية الصغيرة التي كانت تظهر فوق التطبيق
    }
    
    @ViewBuilder
    private func _actions(for app: AppInfoPresentable) -> some View {
        Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
            Storage.shared.deleteApp(for: app)
        }
    }
    
    @ViewBuilder
    private func _contextActions(for app: AppInfoPresentable) -> some View {
        Button(.localized("Get Info"), systemImage: "info.circle") {
            selectedInfoAppPresenting = AnyApp(base: app)
        }
    }
    
    @ViewBuilder
    private func _contextActionsExtra(for app: AppInfoPresentable) -> some View {
        if let update = updateManager.update(for: app) {
            Button(.localized("Update"), systemImage: "arrow.down.circle") {
                if app.isSigned {
                    _signedUpdateConfirmation = update
                    _isSignedUpdateConfirmationPresented = true
                } else {
                    _startUpdateDownload(update)
                }
            }
        }
        
        if app.isSigned {
            if let id = app.identifier {
                Button(.localized("Open"), systemImage: "app.badge.checkmark") {
                    UIApplication.openApp(with: id)
                }
            }
            Button(.localized("Install"), systemImage: "square.and.arrow.down") {
                selectedInstallAppPresenting = AnyApp(base: app)
            }
            Button(.localized("Re-sign"), systemImage: "signature") {
                selectedSigningAppPresenting = AnyApp(base: app)
            }
            Button(.localized("Export"), systemImage: "square.and.arrow.up") {
                selectedInstallAppPresenting = AnyApp(base: app, archive: true)
            }
        } else {
            Button(.localized("Install"), systemImage: "square.and.arrow.down") {
                selectedInstallAppPresenting = AnyApp(base: app)
            }
            Button(.localized("Sign"), systemImage: "signature") {
                selectedSigningAppPresenting = AnyApp(base: app)
            }
        }
    }
    
    // MARK: Install Button Style (App Store Look)
    @ViewBuilder
    private func _buttonActions(for app: AppInfoPresentable) -> some View {
        Group {
            if let update = updateManager.update(for: app) {
                // شكل زر التحديث السحابي
                Button {
                    if app.isSigned {
                        _signedUpdateConfirmation = update
                        _isSignedUpdateConfirmationPresented = true
                    } else {
                        _startUpdateDownload(update)
                    }
                } label: {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            } else if app.isSigned {
                // شكل زر تثبيت التطبيقات الموقعة
                Button {
                    selectedInstallAppPresenting = AnyApp(base: app)
                } label: {
                    Text("تثبيت")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                // شكل زر توقيع التطبيقات غير الموقعة
                Button {
                    selectedSigningAppPresenting = AnyApp(base: app)
                } label: {
                    Text("توقيع")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.borderless)
    }
    
    private func _startUpdateDownload(_ update: AppUpdate) {
        _ = DownloadManager.shared.startDownload(
            from: update.downloadURL,
            id: "FeatherManualDownload_Update_\(update.localUUID)",
            sourceProvenance: update.sourceProvenance
        )
    }
}
