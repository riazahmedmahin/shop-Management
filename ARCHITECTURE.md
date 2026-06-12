# Cashbook App - Architecture Guide

## Project Structure

```
lib/
├── main_refactored.dart       # Refactored entry point (clean)
├── main.dart                   # Original file (keep for reference)
├── config/                     # App configuration
│   └── theme_config.dart      # Theme definitions
├── constants/                  # Constants and helpers
│   ├── app_constants.dart     # Colors, sizes, strings, Supabase config
│   ├── icon_helper.dart       # Icon selection helpers
│   ├── faq_data.dart          # FAQ content
│   └── index.dart             # Re-exports
├── models/                     # Data models
│   ├── transaction.dart       # Transaction model
│   ├── cashbook.dart          # Cashbook model
│   ├── faq_item.dart          # FAQ item model
│   ├── business_setup_data.dart
│   └── index.dart             # Re-exports
├── services/                   # Business logic & API
│   ├── auth_service.dart      # Authentication (Supabase)
│   ├── database_service.dart  # Database operations
│   └── index.dart             # Re-exports
├── screens/                    # UI Screens
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── password_reset_screen.dart
│   │   ├── splash_screen.dart
│   │   └── index.dart
│   ├── home/
│   │   ├── cashbook_home_screen.dart
│   │   ├── book_details_screen.dart
│   │   ├── search_books_screen.dart
│   │   └── index.dart
│   └── index.dart
├── widgets/                    # Reusable widgets
│   ├── bottom_progress_bar.dart
│   ├── transaction_list_item.dart
│   └── index.dart
├── utils/                      # Helper functions
│   ├── pdf_export_helper.dart
│   ├── csv_export_helper.dart
│   └── index.dart
└── pubspec.yaml
```

## Architecture Principles

### 1. **Separation of Concerns**
- **Models**: Pure data classes (no logic)
- **Services**: Business logic, API calls (Supabase)
- **Screens**: UI presentation
- **Widgets**: Reusable UI components
- **Utils**: Helper functions

### 2. **Services Layer**
```dart
// ✅ Good: Logic in service
final user = await AuthService().signIn(email, password);

// ❌ Bad: Logic in UI
final user = await Supabase.instance.client.auth.signIn(...);
```

### 3. **Model Classes**
```dart
// Models are lightweight, with computed properties for calculations
class Cashbook {
  double get totalCashIn => transactions
    .where((t) => t.type == TransactionType.income)
    .fold(0.0, (sum, t) => sum + t.amount);
}
```

### 4. **Constants Management**
```dart
// ✅ Good: All constants in one place
import 'constants/app_constants.dart';
AppConstants.appName
AppColors.primary

// ❌ Bad: Magic strings/colors scattered
'CASHBOOK'
Colors.blue[600]
```

### 5. **Imports Pattern**
```dart
// ✅ Good: Use index files for clean imports
import 'models/index.dart';       // Imports all models
import 'services/index.dart';     // Imports all services

// ❌ Bad: Individual imports
import 'models/transaction.dart';
import 'models/cashbook.dart';
```

## Migration Path

### Step 1: Update `pubspec.yaml`
Ensure you're using the refactored main.dart entry point

### Step 2: Run the App
```bash
flutter pub get
flutter run
```

### Step 3: Move Original Features
Copy remaining screens from `main.dart` to respective screen files:
- BookDetailsScreen → `screens/home/book_details_screen.dart`
- SearchBooksPage → `screens/home/search_books_screen.dart`
- Add other screens as needed

### Step 4: Delete Original main.dart
Once all features are migrated, delete the original `main.dart`

## File Naming Conventions
- Screens: `*_screen.dart` (e.g., `login_screen.dart`)
- Models: Singular nouns (e.g., `transaction.dart`)
- Services: `*_service.dart` (e.g., `auth_service.dart`)
- Widgets: `*_widget.dart` or descriptive names
- Utils: `*_helper.dart` or `*_util.dart`

## Code Examples

### Using Services
```dart
final authService = AuthService();
await authService.signIn(email: 'user@example.com', password: 'pass123');

final dbService = DatabaseService();
final cashbooks = await dbService.getCashbooks(businessId);
```

### Using Models
```dart
final cashbook = Cashbook(
  id: '123',
  name: 'Main Book',
  createdAt: DateTime.now(),
);

print('Balance: ${cashbook.netBalance}');
```

### Using Constants
```dart
import 'constants/app_constants.dart';

print(AppConstants.appName);
print(AppConstants.businessCategories);
print(AppColors.primary);
```

## Benefits of This Architecture

✅ **Maintainability**: Easy to find and modify code
✅ **Scalability**: Easy to add new features
✅ **Testability**: Services can be mocked for testing
✅ **Reusability**: Widgets and utils can be reused
✅ **Readability**: Clear structure and naming
✅ **Team Collaboration**: Clear patterns for new developers
