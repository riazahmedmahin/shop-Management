-- Create businesses table for multi-business support
CREATE TABLE businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add business_id column to cashbooks table
ALTER TABLE cashbooks ADD COLUMN business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;

-- Enable RLS for businesses table
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;

-- RLS Policies for businesses
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

-- Update cashbooks RLS to include business filtering
DROP POLICY IF EXISTS "Users can view their own cashbooks" ON cashbooks;
DROP POLICY IF EXISTS "Users can insert their own cashbooks" ON cashbooks;
DROP POLICY IF EXISTS "Users can update their own cashbooks" ON cashbooks;
DROP POLICY IF EXISTS "Users can delete their own cashbooks" ON cashbooks;

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
