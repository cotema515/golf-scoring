import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppLogoMark: View {
    let size: CGFloat

    var body: some View {
        logoImage
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .accessibilityLabel("Golf Scoring logo")
    }

    private var logoImage: Image {
        #if canImport(UIKit)
        if let path = Bundle.main.path(forResource: "AppLogo", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            return Image(uiImage: image)
        }
        #endif

        return Image("AppIcon")
    }
}

struct ProfileAvatar: View {
    let imageData: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.green)
                    .background(.thinMaterial)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.green.opacity(0.25), lineWidth: 2))
        .accessibilityLabel("Profile picture")
    }
}

struct ProfileMenuButton: View {
    @ObservedObject var account: AccountStore

    var body: some View {
        Menu {
            Text(account.profile.fullName.isEmpty ? "Selected player" : account.profile.fullName)
            if let handicapIndex = account.profile.handicapIndex {
                Text("Index \(handicapIndex, format: .number.precision(.fractionLength(1)))")
            }
            if account.profile.isCoteCupProfile {
                Button {
                    account.returnToGameModeChoice()
                } label: {
                    Label("Switch Game", systemImage: "square.grid.2x2")
                }
            }
            Button("Sign Out", action: account.signOut)
        } label: {
            ProfileAvatar(imageData: account.profile.profileImageData, size: 30)
        }
        .accessibilityLabel("Profile menu")
    }
}

struct DateSelectionButton: View {
    let title: String
    @Binding var date: Date
    @State private var isShowingPicker = false
    @State private var pendingDate = Date()

    var body: some View {
        Button {
            pendingDate = date
            isShowingPicker = true
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(date.formatted(.dateTime.month().day().year()))
                    .foregroundStyle(.secondary)
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isShowingPicker) {
            NavigationStack {
                DatePicker(title, selection: $pendingDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                pendingDate = date
                                isShowingPicker = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                date = Calendar.current.startOfDay(for: pendingDate)
                                isShowingPicker = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}
