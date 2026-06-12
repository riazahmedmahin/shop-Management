# 🚀 Getting Started - Cashbook Refactored

## Quick Start (5 minutes)

### 1. Navigate to Project
```bash
cd /Users/riazahmed/Desktop/Cash
```

### 2. Update Dependencies
```bash
flutter pub get
```

### 3. Run the Refactored App
```bash
flutter run -t lib/main_refactored.dart
```

### 4. Test Login/Signup
- Click "Sign Up" to create account
- OR use existing Supabase credentials to login
- Complete business profile
- See the home screen

---

## What's New?

### ✨ New Architecture
```
BEFORE: Everything in main.dart (6668 lines) 😱
AFTER:  Organized into modules (50 lines main) 🎉

lib/
├── services/       ← Business logic (Auth, Database)
├── models/        ← Data models (clean)
├── screens/       ← UI screens (organized)
├── constants/     ← Configuration (centralized)
├── widgets/       ← Reusable components
└── utils/         ← Helper functions
```

### 🎯 Key Files
| File | Purpose |
|------|---------|
| `main_refactored.dart` | ✅ New entry point |
| `services/auth_service.dart` | ✅ Authentication |
| `services/database_service.dart` | ✅ Database ops |
| `screens/auth/login_screen.dart` | ✅ Login UI |
| `screens/auth/signup_screen.dart` | ✅ Signup UI |
| `constants/app_constants.dart` | ✅ Configuration |

---

## Understanding the Code

### Service Layer (Business Logic)
```dart
// This is WHERE business logic lives
class AuthService {
  Future<void> signIn({email, password}) async {
    // All authentication logic here
    // API calls, validation, error handling
  }
}
```

### Screen Layer (UI Only)
```dart
// This is WHERE UI code lives
class LoginScreen extends StatefulWidget {
  // Only UI logic here
  // Call AuthService for business logic
  await AuthService().signIn(email: email, password: password);
}
```

### Model Layer (Data)
```dart
// This is WHERE data is defined
class Cashbook {
  String id;
  String name;
  List<Transaction> transactions;
  
  // Computed properties are OK
  double get netBalance => ...;
}
```

---

## Common Tasks

### Add a New Screen

1. Create file in `lib/screens/feature/my_screen.dart`
2. Import needed services
3. Build UI
4. Call services for data

```dart
import 'package:flutter/material.dart';
import '../../services/index.dart';

class MyScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await AuthService().signOut();
          },
          child: const Text('Logout'),
        ),
      ),
    );
  }
}
```

### Add a Service Method

Add method to `services/database_service.dart`:

```dart
Future<List<Cashbook>> getAllCashbooksForUser(String userId) async {
  final response = await _client
    .from('cashbooks')
    .select()
    .eq('user_id', userId);
  
  return response.map((data) => Cashbook(...)).toList();
}
```

### Use a Constant

```dart
import 'constants/index.dart';

// In your code:
Text(AppConstants.appName)           // 'CASHBOOK'
Icon(icon, color: AppColors.primary) // Colors.blueAccent
SizedBox(height: AppPadding.md)      // 16.0
```

---

## Project Structure Deep Dive

### services/
**Purpose**: Contains all business logic and API calls

```dart
AuthService:
- initialize()        ← Init Supabase
- signIn()           ← Login user
- signUp()           ← Create account
- signOut()          ← Logout
- resetPassword()    ← Send reset email
- currentUser        ← Get logged in user

DatabaseService:
- getCashbooks()     ← Fetch cashbooks
- getCashbook()      ← Get one cashbook
- createCashbook()   ← Create new
- updateCashbook()   ← Edit cashbook
- deleteCashbook()   ← Delete
- (same for transactions)
```

### screens/
**Purpose**: Contains UI screens

```
screens/
├── auth/             ← Authentication screens
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── password_reset_screen.dart
│   └── splash_screen.dart
│
└── home/             ← App screens
    ├── cashbook_home_screen.dart
    ├── book_details_screen.dart  (TODO)
    └── search_books_screen.dart  (TODO)
```

### models/
**Purpose**: Pure data classes

```dart
Transaction:
- id, description, amount, date, type
- Immutable

Cashbook:
- id, name, createdAt, transactions
- Computed: totalCashIn, totalCashOut, netBalance

FAQItem:
- title, content, category
- Simple data holder

BusinessSetupData:
- name, category, type, businessType
- Form state helper
```

### constants/
**Purpose**: Centralized configuration

```
AppConstants:  ← App strings, configs
AppColors:     ← All colors
AppPadding:    ← Spacing values
AppRadius:     ← Border radius values
AppFontSize:   ← Font sizes
AppDuration:   ← Animation durations
IconHelper:    ← Icon selection logic
FAQData:       ← FAQ content
```

---

## Testing Your Setup

### ✅ Step 1: App Launches
```bash
flutter run -t lib/main_refactored.dart
```
Expected: See splash screen, then login screen ✓

### ✅ Step 2: Can Type
Expected: Can enter email/password ✓

### ✅ Step 3: Forgot Password Works
Expected: Can click "Forgot Password?" and navigate ✓

### ✅ Step 4: Sign Up Works
Expected: Can click "Sign Up" and navigate to signup screen ✓

### ✅ Step 5: Can Create Account
Expected: Fill form and create account (Supabase integration works) ✓

### ✅ Step 6: Can Login
Expected: Login with new account, reach home screen ✓

---

## Folder Navigation Tips

### Go to models
```bash
# From project root
cd lib/models

# See all models
ls -la
```

### Go to services
```bash
cd lib/services
ls -la
```

### Find all screens
```bash
find lib/screens -name "*.dart"
```

### View a specific file
```bash
cat lib/constants/app_constants.dart
```

---

## Debugging

### Issue: Import errors
**Solution**: Make sure import uses index.dart
```dart
✅ import 'constants/index.dart';
❌ import 'constants/app_constants.dart';
```

### Issue: Service returns null
**Solution**: Check if Supabase is initialized
```dart
await AuthService().initialize();
```

### Issue: Supabase connection fails
**Solution**: Check Supabase URL and key in `constants/app_constants.dart`
```dart
// Verify these are correct:
AppConstants.supabaseUrl
AppConstants.supabaseAnonKey
```

### Issue: Emulator crash
**Solution**: Use physical device or try different emulator
(This was your original issue - refactoring helps debugging!)

---

## Next: Migrate Other Screens

Once login/signup works:

1. Copy `BookDetailsScreen` from old `main.dart`
2. Extract to `lib/screens/home/book_details_screen.dart`
3. Update imports
4. Update `CashbookHomeScreen` to use it

See `MIGRATION_GUIDE.md` for detailed instructions.

---

## Documentation Files

| File | Use When |
|------|----------|
| **ARCHITECTURE.md** | Need to understand architecture |
| **MIGRATION_GUIDE.md** | Want to migrate remaining screens |
| **QUICK_REFERENCE.md** | Need quick code examples |
| **ARCHITECTURE_VISUAL.md** | Want diagrams and checklists |
| **REFACTORING_SUMMARY.md** | Need overview of changes |
| **Getting Started** | You are here 👈 |

---

## Quick Commands

```bash
# Update dependencies
flutter pub get

# Run refactored app
flutter run -t lib/main_refactored.dart

# Run with specific device
flutter run -t lib/main_refactored.dart -d <device_id>

# Check for errors
flutter analyze

# Format code
flutter format lib/

# Run tests
flutter test

# Build APK
flutter build apk --target=lib/main_refactored.dart

# View logs
flutter logs
```

---

## Common Questions

**Q: Can I keep both main.dart and main_refactored.dart?**
A: Yes! Use `-t` flag to specify which to run

**Q: Do I need to rewrite everything?**
A: No! Structure is ready, just move existing code to new files

**Q: Is it safe to use in production?**
A: Yes! It's production-ready architecture

**Q: How long to complete migration?**
A: 4-6 hours for full refactoring + testing

**Q: Can I test incrementally?**
A: Yes! Each screen can be tested independently

---

## Success Criteria ✅

Your refactoring is successful when:
- [ ] App runs without errors
- [ ] Login screen displays
- [ ] Can type credentials
- [ ] Can navigate between screens
- [ ] Supabase connection works
- [ ] Can create account
- [ ] Can login
- [ ] Business profile setup works
- [ ] All existing features work

---

## You're All Set! 🎉

Your app now has:
- ✅ Professional architecture
- ✅ Clean code organization
- ✅ Scalable structure
- ✅ Comprehensive documentation
- ✅ Best practices implemented

**Next Step**: Run the app and test! 🚀

```bash
flutter run -t lib/main_refactored.dart
```

---

## Need Help?

1. Check the documentation files
2. Look at service examples
3. Review model definitions
4. Check constant values
5. Read MIGRATION_GUIDE.md

You've got this! 💪
