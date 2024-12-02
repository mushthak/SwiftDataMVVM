//
//  ContentView.swift
//  SwiftDataMVVM
//
//  Created by Mushthak Ebrahim on 02/12/24.
//

import SwiftUI
import SwiftData

//====================DOMAIN====================//

// Model
struct User: Identifiable {
    let id: UUID
    let name: String
}

//Cache Module
protocol UserStore {
    func cache(_ user: User) async throws
    func retrieve() async throws -> [User]
    func deleteUser(_ user: User) async throws
}

//====================INFRASTRUCTURE====================//

@ModelActor
actor SwiftDataStore: UserStore {
    func cache(_ user: User) async throws {
        let managedUser = ManagedUserItem.managedUser(from: user)
        modelContext.insert(managedUser)
        try modelContext.save()
    }
    
    func retrieve() throws -> [User] {
        let cache = try findUserCache()
        return cache.compactMap{ $0.local }
    }
    
    func deleteUser(_ user: User) async throws {
        guard let managedUser = try findManagedUser(for: user.id) else { return }
        modelContext.delete(managedUser)
        try modelContext.save()
    }
    
    //MARK: Helpers
    private func findUserCache() throws -> [ManagedUserItem] {
        let descriptor = FetchDescriptor<ManagedUserItem>()
        return try modelContext.fetch(descriptor)
    }
    
    private func findManagedUser(for id: UUID) throws -> ManagedUserItem? {
        let descriptor = FetchDescriptor<ManagedUserItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}

@Model
final class ManagedUserItem {
    var id: UUID
    var name: String
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
    
    var local: User {
        return User(id: id, name: name)
    }
    
    static func managedUser(from user: User) -> ManagedUserItem {
        return ManagedUserItem(id: user.id, name: user.name)
    }
}

//====================PRESENTATION====================//

//ViewModel
@Observable
class UserViewModel {
    var users: [User] = []
    //Inject dependency with store or adapter etc depending upon architecture
    let userStore: UserStore
    
    init(userStore: UserStore) {
        self.userStore = userStore
    }
    
    // Custom fetching logic, alternatove of direct use of @Query in the View
    func loadUsers() async {
        // Your data fetching logic
        // For example, querying from SwiftData or fetching from Network
        // Assume retrieve() is a function that fetches users from the database
        // Using force unwrap for demo purpose
        self.users = try! await userStore.retrieve()
    }
    
    func addUser(name: String) async {
        let newUser = User(id: UUID(), name: name)
        //Using force unwrap for demo purpose
        try! await userStore.cache(newUser)
        //Reload the list from store
        await self.loadUsers()
    }
    
    func deleteUser(at: IndexSet) async {
        try! await userStore.deleteUser(self.users[at.first!])
        //Reload the list from store
        await self.loadUsers()
    }
}

//View
struct ContentView: View {
    
    public init(viewModel: UserViewModel) {
        self.viewModel = viewModel
    }
    
    // View with dependencies with viewModel
    @State var viewModel: UserViewModel
    
    // Tracks edit mode
    @State private var isEditing = false
    //Tracks dialog state
    @State private var isShowingDialog = false
    //Tracks new name
    @State private var newName = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.users) { user in
                    Text(user.name)
                }
                .onDelete { indexSet in
                    Task {
                        await viewModel.deleteUser(at: indexSet)
                    }
                }
            }
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }) {
                        Text(isEditing ? "Done" : "Edit")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingDialog.toggle()
                    }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
            .task {
                //Fetching users
                await viewModel.loadUsers()
            }
            .overlay(
                CustomDialog(
                    isVisible: $isShowingDialog,
                    newName: $newName,
                    onSave: {
                        Task {
                            await viewModel.addUser(name: newName)
                            isShowingDialog = false
                            newName = ""
                        }
                    },
                    onCancel: {
                        isShowingDialog = false
                        newName = ""
                    }
                )
            )
        }
    }
}

struct CustomDialog: View {
    @Binding var isVisible: Bool
    @Binding var newName: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Add User")
                        .font(.headline)
                        .padding()
                    
                    TextField("Enter name", text: $newName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        
                        Button("Save") {
                            onSave()
                        }
                        .padding()
                        .background(newName.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .disabled(newName.isEmpty)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 10)
                .frame(maxWidth: 300)
            }
        }
    }
}

#Preview {
    return ContentView(viewModel: PreviewHelper.userListViewModelPreview)
}

#if DEBUG
struct PreviewHelper {
    static let userListViewModelPreview: UserViewModel = {
        struct UserStoreSpy: UserStore {
            func cache(_ user: User) async throws {}
            
            func retrieve() async throws -> [User] {
                return [User(id: UUID(),
                             name: "a name"),
                        User(id: UUID(),
                             name: "another name")]
            }
            
            func deleteUser(_ user: User) async throws {}
        }
        let viewModel = UserViewModel(userStore: UserStoreSpy())
        return viewModel
    }()
}
#endif
