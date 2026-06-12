# Quick Reference - Cashbook App Architecture

## 📁 File Organization

```
YOUR APP
├── ARCHITECTURE.md          ← Architecture overview
├── MIGRATION_GUIDE.md       ← Step-by-step migration
├── pubspec.yaml
├── lib/
│   ├── main.dart                    ← ORIGINAL (keep as reference)
│   ├── main_refactored.dart         ← NEW ENTRY POINT (use this)
│   ├── config/
│   │   └── theme_config.dart       ← App theme
│   ├── constants/
│   │   ├── app_constants.dart      ← Colors, sizes, strings
│   │   ├── icon_helper.dart        ← Icon helpers
│   │   ├── faq_data.dart           ← FAQ content
│   │   └── index.dart              ← Re-exports
│   ├── models/
│   │   ├── transaction.dart        ← Transaction model
│   │   ├── cashbook.dart           ← Cashbook model
│   │   ├── faq_item.dart           ← FAQ model
│   │   ├── business_setup_data.dart
│   │   └── index.dart              ← Re-exports
│   ├── services/
│   │   ├── auth_service.dart       ← Auth (Supabase)
│   │   ├── database_service.dart   ← DB operations
│   │   └── index.dart              ← Re-exports
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   ├── password_reset_screen.dart
│   │   │   ├── splash_screen.dart
│   │   │   └── index.dart
│   │   ├── home/
│   │   │   ├── cashbook_home_screen.dart
│   │   │   └── index.dart
│   │   └── index.dart
│   ├── widgets/
│   │   └── index.dart
│   └── utils/
│       ├── pdf_export_helper.dart
│       ├── csv_export_helper.dart
│       └── index.dart
```

## 🔧 How to Use Each Service

### Authentication Service
```dart
import 'services/auth_service.dart';

// Initialize
await AuthService().initialize();

// Sign up
await AuthService().signUp(
  email: 'user@example.com',
  password: 'password123',
  metadata: {'name': 'John'},
);

// Sign in
await AuthService().signIn(
  email: 'user@example.com',
  password: 'password123',
);

// Get current user
final user = AuthService().currentUser;

// Sign out
await AuthService().signOut();

// Reset password
await AuthService().resetPassword('user@example.com');

// Watch auth state
AuthService().authStateStream.listen((state) {
  // Handle auth changes
});
```

### Database Service
```dart
import 'services/database_service.dart';

final dbService = DatabaseService();

// Cashbooks
await dbService.getCashbooks(businessId);
await dbService.createCashbook(businessId: id, name: 'Sales');
await dbService.updateCashbook(cashbookId: id, name: 'New Name');
await dbService.deleteCashbook(cashbookId);

// Transactions
await dbService.getTransactions(cashbookId);
await dbService.addTransaction(
  cashbookId: id,
  description: 'Sale',
  amount: 500,
  date: DateTime.now(),
  type: 'income',
);
await dbService.updateTransaction(
  transactionId: id,
  description: 'Sale',
  amount: 600,
  date: DateTime.now(),
  type: 'income',
);
await dbService.deleteTransaction(transactionId);
```

## 🎨 Using Constants

```dart
import 'constants/app_constants.dart';

// App strings
print(AppConstants.appName);        // 'CASHBOOK'
print(AppConstants.appTagline);     // 'Smart accounting...'

// Business data
print(AppConstants.businessCategories);
print(AppConstants.businessTypes);

// Colors
print(AppColors.primary);
print(AppColors.success);
print(AppColors.error);

// Sizing
print(AppPadding.md);  // 16.0
print(AppRadius.md);   // 12.0

// Font sizes
print(AppFontSize.lg); // 16.0

// Durations
print(AppDuration.short); // 300ms
```

## 📦 Import Patterns

### Clean imports using index files
```dart
// ✅ GOOD
import 'models/index.dart';
import 'services/index.dart';
import 'screens/index.dart';

// ❌ AVOID
import 'models/transaction.dart';
import 'models/cashbook.dart';
import 'models/faq_item.dart';
```

## 🚀 Getting Started

### 1. Install dependencies
```bash
cd /Users/riazahmed/Desktop/Cash
flutter pub get
```

### 2. Run refactored version
```bash
flutter run -t lib/main_refactored.dart
```

### 3. Test login/signup
- Try creating account with test email
- Verify Supabase connection works
- Check business profile setup

### 4. Next: Migrate remaining screens
See `MIGRATION_GUIDE.md` for step-by-step instructions

## 🔑 Key Architecture Principles

| Principle | What | Where |
|-----------|------|-------|
| **Separation of Concerns** | Code is organized by responsibility | Different folders for models, services, screens |
| **Single Responsibility** | Each file has one job | `login_screen.dart` = Login UI only |
| **Dependency Injection** | Services are injected, not created | Use `AuthService()` instead of `Supabase.instance.client` |
| **Reusability** | Components are reusable | Common widgets in `widgets/` folder |
| **Maintainability** | Easy to find and modify | Clear naming and structure |
| **Testability** | Services can be mocked | Services are isolated from UI |

## 📋 Common Tasks

### Add a new screen
1. Create file in `screens/feature/`
2. Import needed services and models
3. Use existing services for data
4. Return clean UI

### Add a new database operation
1. Add method to `DatabaseService`
2. Use existing patterns (auth first, then Supabase call)
3. Return typed data
4. Call from screen

### Add new constants
1. Add to `constants/app_constants.dart`
2. Group related constants (colors, sizes, text)
3. Import in screen
4. Use throughout

### Create reusable widget
1. Create file in `widgets/`
2. Make it accept parameters
3. Make it stateless if possible
4. Use in multiple screens

## 🐛 Debugging Tips

### Check imports
```bash
# Verify all imports are correct
grep -r "import.*main.dart" lib/
```

### Test services in isolation
```dart
// In a test file
final auth = AuthService();
final user = await auth.signIn(email: 'test@example.com', password: 'test');
print(user);
```

### Check Supabase connection
```dart
print(AuthService().client.auth.currentUser);
```

## 📞 Need Help?

1. **Architecture questions** → Read `ARCHITECTURE.md`
2. **Migration steps** → Read `MIGRATION_GUIDE.md`
3. **Code examples** → Check service files
4. **Constants** → See `constants/app_constants.dart`

## ✨ Benefits Achieved

✅ Clean project structure  
✅ Easier to maintain and extend  
✅ Better code organization  
✅ Reusable components  
✅ Professional architecture  
✅ Scalable for future growth  
✅ Easier testing and debugging  
