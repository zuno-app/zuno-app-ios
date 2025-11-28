# Testing Steps - November 24, 2025

## Quick Test Procedure

### 1. Clean Build
```bash
# In Xcode:
# 1. Product → Clean Build Folder (Cmd+Shift+K)
# 2. Delete app from simulator
# 3. Reset simulator: Device → Erase All Content and Settings
# 4. Build and Run (Cmd+R)
```

### 2. Test Registration Flow

**Expected Behavior:**
1. App opens to Welcome screen
2. Tap "Get Started"
3. Enter @zuno tag (e.g., `winsorth06`)
4. Tap "Continue"
5. Passkey registration prompt appears
6. Complete Face ID/Touch ID
7. **App should automatically navigate to HomeView**
8. **Wallet should be created automatically**

**What to Check:**
- ✅ HomeView appears after registration
- ✅ Balance card shows "US$ 0.00" (or your preferred currency)
- ✅ "My Wallets" section shows one wallet
- ✅ Profile button (top left) works
- ✅ Settings button (top right) works

### 3. Test Profile View

**Steps:**
1. Tap profile icon (top left)
2. Profile sheet should appear

**What to Check:**
- ✅ User avatar with initial
- ✅ Display name or @zuno tag
- ✅ Stats cards (Wallets, Balance, Network)
- ✅ Account info section
- ✅ "Edit Profile" button works

### 4. Test Edit Profile

**Steps:**
1. In profile view, tap "Edit"
2. Edit profile sheet appears

**What to Check:**
- ✅ Can edit display name
- ✅ Can edit email
- ✅ Can change currency (USD, EUR, GBP, etc.)
- ✅ Can change preferred network
- ✅ "Save" button works
- ✅ Changes persist after closing

### 5. Test Settings

**Steps:**
1. Tap settings icon (top right)
2. Settings sheet appears

**What to Check:**
- ✅ Account section shows user info
- ✅ Security section present
- ✅ Preferences section present
- ✅ Support section with links
- ✅ "About" button works
- ✅ "Log Out" button works

### 6. Test Wallet Creation

**Steps:**
1. In HomeView, tap "+" button next to "My Wallets"
2. Wallet should be created

**What to Check:**
- ✅ Loading indicator appears
- ✅ New wallet appears in list
- ✅ Wallet shows blockchain name
- ✅ Wallet shows address
- ✅ Can tap wallet to see details

### 7. Test Currency Display

**Steps:**
1. Go to Profile → Edit
2. Change currency to EUR
3. Save and close
4. Return to HomeView

**What to Check:**
- ✅ Balance shows "€ 0,00" (or EUR format)
- ✅ Preferred stablecoin shows "EURC"

## Common Issues & Solutions

### Issue: App stuck on Welcome screen after registration

**Solution:**
1. Check console logs for: `✅ [AuthViewModel] State updated`
2. If missing, registration didn't complete
3. Try registering again with different @zuno tag

### Issue: No wallet created automatically

**Solution:**
1. Check console for: `🌐 [HomeView] No wallets found, creating default wallet...`
2. If missing, HomeView setupView didn't run
3. Try manually creating wallet with "+" button

### Issue: Profile view doesn't open

**Solution:**
1. Check if user is loaded: Look for `✅ [RootView] HomeView appeared for user:`
2. If user not loaded, authentication state is incorrect
3. Try logging out and back in

### Issue: Settings view doesn't open

**Solution:**
1. This should always work if HomeView is visible
2. If not, there's a navigation issue
3. Check console for errors

## Console Log Patterns

### Successful Registration:
```
✅ [AuthViewModel] Registration successful
✅ [AuthViewModel] User: winsorth06, ID: <uuid>
✅ [AuthViewModel] State updated - isAuthenticated: true, hasUser: true
✅ [RootView] HomeView appeared for user: winsorth06
🌐 [HomeView] No wallets found, creating default wallet...
✅ Wallet created successfully
```

### Successful Profile View:
```
✅ [RootView] HomeView appeared for user: winsorth06
[User taps profile button]
[Profile sheet appears]
```

### Successful Edit Profile:
```
[User edits profile]
✅ [EditProfile] Profile updated successfully
```

## What Was Fixed

1. **Authentication State Management**
   - Added explicit MainActor.run for state updates
   - Added view ID to force refresh on user change
   - Added better logging throughout

2. **Automatic Wallet Creation**
   - HomeView now creates wallet if none exists
   - Uses user's preferred network
   - Names wallet with preferred stablecoin

3. **Currency Display**
   - Balance uses user's preferred currency
   - Shows preferred stablecoin (USDC/EURC)
   - Updates when currency preference changes

4. **Profile & Settings**
   - Created EditProfileView for profile editing
   - Created SettingsView with all sections
   - Both accessible from HomeView toolbar

5. **Wallet Management**
   - Created WalletDetailView for wallet details
   - Manual wallet creation works
   - Wallet list displays correctly

## Known Limitations

1. **CoreData Warnings**: These are simulator-specific and harmless
2. **Haptic Feedback Errors**: Simulator-specific, work on real devices
3. **Backend Integration**: Some features need backend API endpoints
4. **Wallet Service**: Needs Circle API credentials to actually create wallets

## Next Steps After Testing

If everything works:
1. Configure Circle API credentials in backend
2. Test actual wallet creation with real blockchain
3. Test transaction flows
4. Deploy to TestFlight for real device testing

If issues persist:
1. Share console logs showing the error
2. Describe exact steps to reproduce
3. Include screenshot of what you see
