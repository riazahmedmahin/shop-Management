-- ==========================================
-- CASHBOOK APP - COMPLETE DATABASE SETUP
-- Multi-Business Support Edition
-- ==========================================

-- Step 1: Create existing tables (if not already exist)
-- =====================================================

-- Create cashbooks table
CREATE TABLE IF NOT EXISTS cashbooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashbook_id UUID NOT NULL REFERENCES cashbooks(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  date TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);


-- Step 2: Create businesses table (NEW - for multi-business support)
-- ==================================================================

CREATE TABLE IF NOT EXISTS businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add business_id column to cashbooks if it doesn't exist
ALTER TABLE cashbooks ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;


-- Step 3: Enable RLS (Row Level Security) on all tables
-- ======================================================

ALTER TABLE cashbooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;


-- Step 4: Drop existing policies (if any) to avoid conflicts
-- ===========================================================

-- Cashbooks policies
DROP POLICY IF EXISTS "Users can view their own cashbooks" ON cashbooks;
DROP POLICY IF EXISTS "Users can insert their own cashbooks" ON cashbooks;
DROP POLICY IF EXISTS "Users can update their own cashbooks" ON cashbooks;
DROP POLICY IF EXISTS "Users can delete their own cashbooks" ON cashbooks;

-- Transactions policies
DROP POLICY IF EXISTS "Users can view transactions of their cashbooks" ON transactions;
DROP POLICY IF EXISTS "Users can insert transactions in their cashbooks" ON transactions;
DROP POLICY IF EXISTS "Users can update transactions in their cashbooks" ON transactions;
DROP POLICY IF EXISTS "Users can delete transactions in their cashbooks" ON transactions;

-- Businesses policies
DROP POLICY IF EXISTS "Users can view their own businesses" ON businesses;
DROP POLICY IF EXISTS "Users can insert their own businesses" ON businesses;
DROP POLICY IF EXISTS "Users can update their own businesses" ON businesses;
DROP POLICY IF EXISTS "Users can delete their own businesses" ON businesses;


-- Step 5: Create NEW RLS Policies for Cashbooks (with multi-business support)
-- ============================================================================

CREATE POLICY "Users can view their own cashbooks"
  ON cashbooks FOR SELECT
  USING (
    auth.uid() = user_id
    AND (
      business_id IS NULL 
      OR EXISTS (
        SELECT 1 FROM businesses 
        WHERE businesses.id = cashbooks.business_id 
        AND businesses.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can insert their own cashbooks"
  ON cashbooks FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      business_id IS NULL 
      OR EXISTS (
        SELECT 1 FROM businesses 
        WHERE businesses.id = cashbooks.business_id 
        AND businesses.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can update their own cashbooks"
  ON cashbooks FOR UPDATE
  USING (
    auth.uid() = user_id
    AND (
      business_id IS NULL 
      OR EXISTS (
        SELECT 1 FROM businesses 
        WHERE businesses.id = cashbooks.business_id 
        AND businesses.user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    auth.uid() = user_id
    AND (
      business_id IS NULL 
      OR EXISTS (
        SELECT 1 FROM businesses 
        WHERE businesses.id = cashbooks.business_id 
        AND businesses.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can delete their own cashbooks"
  ON cashbooks FOR DELETE
  USING (
    auth.uid() = user_id
    AND (
      business_id IS NULL 
      OR EXISTS (
        SELECT 1 FROM businesses 
        WHERE businesses.id = cashbooks.business_id 
        AND businesses.user_id = auth.uid()
      )
    )
  );


-- Step 6: Create RLS Policies for Transactions (via cashbook owner)
-- ==================================================================

CREATE POLICY "Users can view transactions of their cashbooks"
  ON transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM cashbooks
      WHERE cashbooks.id = transactions.cashbook_id
      AND cashbooks.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert transactions in their cashbooks"
  ON transactions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM cashbooks
      WHERE cashbooks.id = transactions.cashbook_id
      AND cashbooks.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update transactions in their cashbooks"
  ON transactions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM cashbooks
      WHERE cashbooks.id = transactions.cashbook_id
      AND cashbooks.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM cashbooks
      WHERE cashbooks.id = transactions.cashbook_id
      AND cashbooks.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete transactions in their cashbooks"
  ON transactions FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM cashbooks
      WHERE cashbooks.id = transactions.cashbook_id
      AND cashbooks.user_id = auth.uid()
    )
  );


-- Step 7: Create RLS Policies for Businesses (NEW)
-- ================================================

CREATE POLICY "Users can view their own businesses"
  ON businesses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own businesses"
  ON businesses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own businesses"
  ON businesses FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own businesses"
  ON businesses FOR DELETE
  USING (auth.uid() = user_id);


-- Step 8: Create Indexes for Performance (Optional but recommended)
-- =================================================================

CREATE INDEX IF NOT EXISTS idx_cashbooks_user_id ON cashbooks(user_id);
CREATE INDEX IF NOT EXISTS idx_cashbooks_business_id ON cashbooks(business_id);
CREATE INDEX IF NOT EXISTS idx_transactions_cashbook_id ON transactions(cashbook_id);
CREATE INDEX IF NOT EXISTS idx_businesses_user_id ON businesses(user_id);

-- ==========================================
-- ALL DONE!
-- Database is now ready for multi-business support
-- ==========================================
