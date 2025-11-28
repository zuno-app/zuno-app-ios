# Troubleshooting: SwiftData & ViewModel Issues

## Issue: Button Actions Not Working / View State Not Persisting

**Date Encountered:** November 18, 2025
**Severity:** High
**Status:** Resolved

---

## Problem Description

### Symptoms
- Buttons in views (specifically passkey registration) appear to tap but don't proceed to next screen
- Authentication flows fail silently
- No errors shown in console
- View state changes don't persist
- User interactions seem to have no effect

### Affected Components
- `PasskeySetupView.swift`
- `ZunoTagInputView.swift`
- Any view using `@StateObject` with `AuthViewModel`

---

## Root Cause

### What Happened
Views were creating their own instances of `AuthViewModel` using `ModelContainer.preview` (a mock in-memory database meant only for SwiftUI previews) instead of using the real `AuthViewModel` instance that was properly initialized with the app's actual database.

### Code That Caused the Issue

```swift
// ❌ WRONG - Using preview container in production code
struct PasskeySetupView: View {
    @StateObject private var authViewModel: AuthViewModel

    init(zunoTag: String, displayName: String?, email: String?, isRegistration: Bool) {
        // This creates a NEW ViewModel with MOCK data every time!
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            modelContext: ModelContext(ModelContainer.preview)
        ))
    }
}
```

### Why This Was Wrong
1. **Preview Container**: `ModelContainer.preview` is configured with `isStoredInMemoryOnly: true`, meaning nothing persists
2. **Multiple Instances**: Each view was creating its own separate `AuthViewModel` instance
3. **No Shared State**: The app's properly initialized `AuthViewModel` (with real database) was being ignored
4. **Data Isolation**: Changes in one view's ViewModel wouldn't affect another view's ViewModel

---

## Solution

### The Fix
Use `@EnvironmentObject` instead of `@StateObject` to receive the already-initialized `AuthViewModel` from the app's environment.

### Correct Code

```swift
// ✅ CORRECT - Using environment object
struct PasskeySetupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    // No init needed - ViewModel comes from environment
    let zunoTag: String
    let displayName: String?
    let email: String?
    let isRegistration: Bool
}
```

### Updated Previews

```swift
// ✅ CORRECT - Properly inject environment object in previews
#Preview {
    let container = ModelContainer.preview
    let context = container.mainContext
    let authViewModel = AuthViewModel(modelContext: context)

    return NavigationStack {
        PasskeySetupView(
            zunoTag: "alice",
            displayName: "Alice",
            email: "alice@example.com",
            isRegistration: true
        )
        .environmentObject(authViewModel)  // Must inject for previews
        .modelContainer(container)
    }
}
```

---

## How to Identify Similar Issues

### Checklist
When views aren't responding or state isn't persisting, check:

1. **Environment Object Usage**
   - [ ] Is the view using `@EnvironmentObject` for shared ViewModels?
   - [ ] Is the ViewModel being injected at the app level?
   - [ ] Are child views properly receiving the environment object?

2. **Model Container**
   - [ ] Search for `ModelContainer.preview` in production code (should only be in previews)
   - [ ] Verify `ModelConfiguration` has `isStoredInMemoryOnly: false` for production
   - [ ] Check that the app creates a single shared container

3. **ViewModel Initialization**
   - [ ] ViewModels requiring database access should be initialized once at app level
   - [ ] Views should use `@EnvironmentObject` to access shared ViewModels
   - [ ] Don't create new ViewModel instances in view `init()` methods

### Quick Search Commands

```bash
# Find views using ModelContainer.preview in production code
grep -r "ModelContainer.preview" --include="*.swift" --exclude="*Preview*" .

# Find StateObject declarations that might need to be EnvironmentObject
grep -r "@StateObject.*ViewModel" --include="*.swift" .

# Find init methods that create ViewModels
grep -A5 "init(" --include="*.swift" . | grep "StateObject"
```

---

## General Architecture Rules

### ✅ DO

1. **Single Source of Truth**
   ```swift
   // App level - create once
   @main
   struct MyApp: App {
       @StateObject private var authViewModel: AuthViewModel

       init() {
           let context = sharedModelContainer.mainContext
           _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: context))
       }

       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(authViewModel)  // Inject here
                   .modelContainer(sharedModelContainer)
           }
       }
   }
   ```

2. **Use Environment Objects in Views**
   ```swift
   // View level - receive from environment
   struct MyView: View {
       @EnvironmentObject private var authViewModel: AuthViewModel

       var body: some View {
           // Use authViewModel
       }
   }
   ```

3. **Preview Container Only in Previews**
   ```swift
   // Only in #Preview blocks
   #Preview {
       let container = ModelContainer.preview
       MyView()
           .environmentObject(AuthViewModel(modelContext: container.mainContext))
           .modelContainer(container)
   }
   ```

### ❌ DON'T

1. **Don't Create Multiple ViewModel Instances**
   ```swift
   // ❌ BAD - Each view creates its own instance
   struct MyView: View {
       @StateObject private var viewModel = MyViewModel()
   }
   ```

2. **Don't Use Preview Container Outside Previews**
   ```swift
   // ❌ BAD - Using mock data in production
   init() {
       _viewModel = StateObject(wrappedValue: ViewModel(
           modelContext: ModelContext(ModelContainer.preview)
       ))
   }
   ```

3. **Don't Initialize ViewModels in View Init**
   ```swift
   // ❌ BAD - Creating new instance each time
   struct MyView: View {
       @StateObject private var viewModel: MyViewModel

       init() {
           _viewModel = StateObject(wrappedValue: MyViewModel())
       }
   }
   ```

---

## When to Use What

| Property Wrapper | Use Case | Example |
|-----------------|----------|---------|
| `@StateObject` | First time creating an object that the view owns | App-level initialization |
| `@EnvironmentObject` | Accessing a shared object passed down from a parent | Child views accessing shared ViewModels |
| `@ObservedObject` | Referencing an object created elsewhere (not owned by view) | Passing ViewModels as parameters |
| `@State` | Simple value types owned by the view | Local UI state (toggles, text fields) |

---

## Testing the Fix

### Steps to Verify
1. Clean build folder (Cmd + Shift + K in Xcode)
2. Build and run the app
3. Test the previously broken flow:
   - Tap through the registration flow
   - Verify button actions work
   - Confirm data persists across views
   - Check that authentication completes successfully

### Expected Behavior After Fix
- Button taps trigger actions immediately
- Navigation flows work correctly
- Data persists across view transitions
- Authentication state is shared across all views
- No silent failures or unexpected behavior

---

## Related Documentation

- [Apple: Managing Model Data in Your App](https://developer.apple.com/documentation/swiftdata/managing-model-data-in-your-app)
- [Apple: Environment Objects](https://developer.apple.com/documentation/swiftui/environmentobject)
- [Apple: State Object](https://developer.apple.com/documentation/swiftui/stateobject)
- [SwiftData Architecture Guide](../../../.kiro/steering/ios-specific.md)

---

## Prevention

### Code Review Checklist
- [ ] No `ModelContainer.preview` in production code (only in `#Preview` blocks)
- [ ] Shared ViewModels use `@EnvironmentObject` in child views
- [ ] App-level ViewModels initialized once with proper `ModelContext`
- [ ] Preview code properly injects environment objects

### Linting Rules (Future)
Consider adding SwiftLint rules to catch these issues:
- Detect `ModelContainer.preview` outside preview blocks
- Warn on `@StateObject` for ViewModels with database dependencies
- Enforce environment object injection patterns

---

## Quick Reference: Fix Pattern

```swift
// BEFORE (Broken)
struct MyView: View {
    @StateObject private var viewModel: MyViewModel

    init() {
        _viewModel = StateObject(wrappedValue: MyViewModel(
            modelContext: ModelContext(ModelContainer.preview)
        ))
    }
}

// AFTER (Fixed)
struct MyView: View {
    @EnvironmentObject private var viewModel: MyViewModel

    // No init needed
}

// Preview must inject environment object
#Preview {
    let container = ModelContainer.preview
    MyView()
        .environmentObject(MyViewModel(modelContext: container.mainContext))
        .modelContainer(container)
}
```

---

## Additional Notes

- This pattern applies to **all** ViewModels that need database access
- The same issue can occur with other shared resources (network clients, authentication services, etc.)
- Always follow the "single source of truth" principle for shared state
- Use SwiftUI's environment system for dependency injection

---

**Last Updated:** November 18, 2025
**Updated By:** Claude Code
**Issue Reference:** Passkey registration button not continuing
