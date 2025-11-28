# Quick Reference: ViewModel & SwiftData Patterns

## Common Issue: Button/Actions Not Working

**Symptom:** Buttons tap but nothing happens, no navigation, no state changes

**Quick Check:**
```bash
grep -r "ModelContainer.preview" --include="*.swift" --exclude="*Preview*" zuno-app-ios/
```

**If found:** Change to `@EnvironmentObject` pattern (see below)

---

## Pattern: Shared ViewModel (Database Access)

### ✅ CORRECT Pattern

```swift
// 1. App Level (zuno_app_iosApp.swift)
@main
struct MyApp: App {
    @StateObject private var authViewModel: AuthViewModel
    var sharedModelContainer: ModelContainer = { /* setup */ }()

    init() {
        let context = sharedModelContainer.mainContext
        _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)  // ← Inject once
                .modelContainer(sharedModelContainer)
        }
    }
}

// 2. Child Views
struct MyView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel  // ← Receive

    var body: some View {
        Button("Do Something") {
            Task {
                await authViewModel.doSomething()  // ← Use
            }
        }
    }
}

// 3. Previews
#Preview {
    let container = ModelContainer.preview
    let authViewModel = AuthViewModel(modelContext: container.mainContext)

    return MyView()
        .environmentObject(authViewModel)  // ← Must inject
        .modelContainer(container)
}
```

### ❌ WRONG Pattern (Causes Issues)

```swift
// DON'T DO THIS
struct MyView: View {
    @StateObject private var authViewModel: AuthViewModel

    init() {
        // ❌ Creates new instance with mock data!
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            modelContext: ModelContext(ModelContainer.preview)
        ))
    }
}
```

---

## Pattern: View-Owned ViewModel (No Database)

### ✅ CORRECT - Simple View State

```swift
struct MyView: View {
    @StateObject private var viewModel = MySimpleViewModel()  // OK if no DB access

    var body: some View {
        // Use viewModel
    }
}
```

**Use this when:**
- ViewModel doesn't need database access
- State is local to this view only
- No need to share with other views

---

## Quick Decision Tree

```
Does the ViewModel need database/shared state?
│
├─ YES → Use @EnvironmentObject
│         - Initialize once at app level with @StateObject
│         - Inject via .environmentObject()
│         - Receive in views with @EnvironmentObject
│
└─ NO  → Use @StateObject
          - Create in view with @StateObject
          - Each view can have its own instance
```

---

## Common Mistakes & Fixes

| ❌ Mistake | ✅ Fix |
|-----------|-------|
| `ModelContainer.preview` in production code | Only use in `#Preview` blocks |
| Multiple `@StateObject` for same ViewModel | Use `@EnvironmentObject` instead |
| Creating ViewModel in view `init()` | Remove init, use `@EnvironmentObject` |
| Not injecting in previews | Add `.environmentObject()` to preview |
| Using `@State` for complex objects | Use `@StateObject` or `@EnvironmentObject` |

---

## Search Commands

```bash
# Find potential issues
grep -r "ModelContainer.preview" --include="*.swift" --exclude="*Preview*" .
grep -r "@StateObject.*AuthViewModel" --include="*.swift" .

# Find all environment object injections
grep -r "environmentObject" --include="*.swift" .
```

---

## Property Wrapper Cheat Sheet

| Wrapper | Ownership | Lifecycle | Use For |
|---------|-----------|-----------|---------|
| `@StateObject` | View owns | Survives view updates | First creation, owned objects |
| `@EnvironmentObject` | Parent owns | Injected from parent | Shared ViewModels, app state |
| `@ObservedObject` | External | Passed as parameter | Object owned elsewhere |
| `@State` | View owns | Survives view updates | Simple values (Bool, String, Int) |

---

## Emergency Fix Template

```swift
// BEFORE
struct BrokenView: View {
    @StateObject private var authViewModel: AuthViewModel
    init() {
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            modelContext: ModelContext(ModelContainer.preview)
        ))
    }
}

// AFTER
struct FixedView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    // Remove init
}

// Update Preview
#Preview {
    let container = ModelContainer.preview
    FixedView()
        .environmentObject(AuthViewModel(modelContext: container.mainContext))
        .modelContainer(container)
}
```

---

**See:** `TROUBLESHOOTING-SWIFTDATA-VIEWMODELS.md` for detailed explanation
