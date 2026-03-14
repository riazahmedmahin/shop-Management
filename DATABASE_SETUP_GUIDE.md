# Database Setup - Complete Guide

## What Changed?

### Original Schema (Your Previous Database)
```sql
cashbooks (id, user_id, name, created_at, updated_at)
transactions (id, cashbook_id, description, amount, type, date, created_at, updated_at)
```

### New Schema (Multi-Business Support)
```sql
businesses (id, user_id, name, type, category, created_at)  ← NEW TABLE

cashbooks (id, user_id, name, created_at, updated_at)
          ↓ NEW COLUMN ↓
          (business_id)  ← Links to businesses table

transactions (id, cashbook_id, description, amount, type, date, created_at, updated_at)
          ↓ No change needed ↓
          (linked via cashbook → business)
```

---

## Why These Changes?

### 1. **`businesses` Table** (NEW)
**Purpose**: Store each user's businesses separately
```
Users can have MULTIPLE businesses:
- My Store (Retail)
- My Factory (Manufacturing)  
- My Service (Service)
```

Each business is tracked separately with:
- `id`: Unique business identifier
- `user_id`: Links to auth.users (who owns it)
- `name`, `type`, `category`: Business details
- `created_at`: When business was created

### 2. **`business_id` Column in `cashbooks`** (NEW)
**Purpose**: Link each cashbook to a specific business
```
User with 2 businesses:
- Business 1: My Store
  ├── Cashbook: Sales 2025 (business_id = UUID-123)
  └── Cashbook: Expenses (business_id = UUID-123)
  
- Business 2: My Factory  
  └── Cashbook: Factory Sales (business_id = UUID-456)

When user switches business → Only show cashbooks with matching business_id
```

### 3. **RLS Policies Updated** (ENHANCED)
**What was**: "Show cashbooks where user_id matches"
```sql
USING (auth.uid() = user_id)
```

**What is now**: "Show cashbooks where user_id matches AND business_id is allowed"
```sql
USING (
  auth.uid() = user_id
  AND (
    business_id IS NULL 
    OR EXISTS (SELECT 1 FROM businesses WHERE id = business_id AND user_id = auth.uid())
  )
)
```

**Why**: 
- ✅ Backward compatible (old cashbooks with `business_id = NULL` still work)
- ✅ Multi-business filtering (only show active business cashbooks)
- ✅ Security (can't see other users' businesses)

---

## How to Apply This to Your Database

### Step 1: Backup Your Data (IMPORTANT!)
Before running SQL, backup your current data. In Supabase:
1. Go to Project Settings → Backups
2. Click "Create a backup"

### Step 2: Run the SQL

**Option A: Using File**
1. Open Supabase Dashboard → SQL Editor → New Query
2. Open `/Users/riazahmed/Downloads/CashBook-App/database_setup_complete.sql`
3. Copy all content
4. Paste into SQL Editor
5. Click "Run"

**Option B: Step by Step (if something fails)**
```
1. Run each section separately (look for "Step 1", "Step 2", etc.)
2. Check if section succeeds before moving to next
3. This helps identify exactly where issues are
```

### Step 3: Verify Changes

In Supabase Dashboard:
1. **Tables**: Should see `cashbooks`, `transactions`, `businesses`
2. **Cashbooks columns**: Should include `business_id` (can be NULL for old records)
3. **Policies**: All tables should have RLS enabled with policies visible

---

## Data Compatibility

### Old Data (Existing Cashbooks)
```
When you run this SQL:
- Cashbooks get new business_id column
- business_id starts as NULL for all existing cashbooks
- Existing RLS policies are replaced with new ones
- Old cashbooks still work (RLS allows business_id = NULL)
```

### New Data (After this SQL)
```
- New cashbooks will have business_id set
- New businesses will be created for users
- Business switching will work
```

### Migration Path
```
1. User signs up → Creates new business in businesses table
2. First cashbook created → Gets business_id = that user's business
3. Existing users:
   - Can still see old cashbooks (business_id = NULL)
   - When they edit/update business → business_id gets set
   - Or they can manually create new business to organize
```

---

## What Each Section Does

### Section 1: Create Tables
- ✅ Creates `businesses` table (new)
- ✅ Creates/keeps `cashbooks` table
- ✅ Creates/keeps `transactions` table
- ✅ Uses `IF NOT EXISTS` to avoid errors if tables already exist

### Section 2: Add business_id Column
- ✅ Adds `business_id` to cashbooks if missing
- ✅ Sets up foreign key relationship
- ✅ Cascades on delete (if business deleted, its cashbooks deleted)

### Section 3: Enable RLS
- ✅ Turns on Row Level Security for all tables
- ✅ Without RLS, anyone can see everyone's data (SECURITY RISK)

### Section 4: Drop Old Policies
- ✅ Removes existing policies to avoid conflicts
- ✅ Safe because we're replacing them immediately

### Section 5: Create New Cashbook Policies
- ✅ Users can only see/edit/delete their own cashbooks
- ✅ Respects business_id filtering
- ✅ Allows legacy records with business_id = NULL

### Section 6: Create Transaction Policies
- ✅ Users can only access transactions in their cashbooks
- ✅ Enforced through cashbook.user_id check
- ✅ No changes from before (still works fine)

### Section 7: Create Business Policies
- ✅ Users can only see/edit their own businesses
- ✅ Prevents cross-user business access

### Section 8: Create Indexes
- ✅ Speed up queries (not required but recommended)
- ✅ Database will search faster for:
  - Cashbooks by user
  - Cashbooks by business
  - Transactions by cashbook
  - Businesses by user

---

## Safety Checks

### Is This Safe?
✅ YES - Here's why:
- Uses `IF NOT EXISTS` so won't error if objects exist
- Uses `DROP IF EXISTS` so won't error if policies missing
- RLS prevents unauthorized access
- Indexes only speed up queries, don't change logic

### Will This Break Existing Data?
❌ NO - Here's why:
- Existing cashbooks still work (business_id = NULL allowed)
- Existing transactions still work (linked via cashbook_id)
- Existing RLS policies replaced with backward-compatible ones
- New column (business_id) is optional

### What If I Make a Mistake?
1. **Revert from backup** (created in Step 1)
2. **Or** - Most changes are reversible:
   - Can drop policies and re-create old ones
   - Can drop business_id column
   - Can delete businesses table
   - Data in cashbooks/transactions unaffected

---

## Troubleshooting

### Error: "relation 'businesses' does not exist"
**Cause**: Running Step 2 before Step 1 (dependencies)
**Fix**: Run entire file from the top

### Error: "policy already exists"
**Cause**: Running SQL twice
**Fix**: This is handled by `DROP IF EXISTS` - just run again

### Error: "column 'business_id' already exists"
**Cause**: business_id column already added
**Fix**: This is handled by `ADD COLUMN IF NOT EXISTS` - no problem

### Cashbooks still visible after switching business?
**Cause**: business_id is NULL (old cashbooks)
**Fix**: This is expected! RLS allows `business_id IS NULL` for backward compatibility

---

## After SQL is Applied

Your app will now:
1. ✅ Create businesses table when users sign up
2. ✅ Link cashbooks to businesses via business_id
3. ✅ Filter cashbooks by active business when loading
4. ✅ Show "Switch Business" button in Settings
5. ✅ Change active_business_id when user switches

---

## Questions?

**Q: Do I need to delete my existing data?**
A: No! Existing cashbooks will continue to work. New cashbooks will have business_id set.

**Q: What happens to old users?**
A: When they login, app creates their first business (from user metadata). Old cashbooks still visible (business_id = NULL is allowed).

**Q: Can I go back to single business?**
A: Yes! Just don't create multiple businesses. Set business_id = NULL and remove the filter from _loadBooksFromDatabase().

**Q: Is multi-business encryption secure?**
A: Yes! RLS policies ensure users can only access their own businesses and cashbooks. Database-level security.
