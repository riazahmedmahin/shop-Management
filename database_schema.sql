-- Create cashbooks table
CREATE TABLE cashbooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create transactions table
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashbook_id UUID NOT NULL REFERENCES cashbooks(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  date TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS (Row Level Security)
ALTER TABLE cashbooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Policies for cashbooks
CREATE POLICY "Users can view their own cashbooks"
  ON cashbooks FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own cashbooks"
  ON cashbooks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cashbooks"
  ON cashbooks FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cashbooks"
  ON cashbooks FOR DELETE
  USING (auth.uid() = user_id);

-- Policies for transactions (via cashbook owner)
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
