-- Create user profiles table with admin approval system
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT,
  is_approved BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create user roles enum and table
CREATE TYPE public.app_role AS ENUM ('admin', 'user');

CREATE TABLE public.user_roles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role app_role NOT NULL DEFAULT 'user',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);

-- Create contributions table (105,000 RWF requirement)
CREATE TABLE public.contributions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  payment_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  reference_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create loans table
CREATE TABLE public.loans (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  purpose TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied', 'disbursed', 'repaid')),
  applied_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  approved_at TIMESTAMP WITH TIME ZONE,
  admin_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;

-- Create security definer function to check user roles
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- Create security definer function to check if user is approved
CREATE OR REPLACE FUNCTION public.is_user_approved(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE((
    SELECT is_approved
    FROM public.profiles
    WHERE user_id = _user_id
  ), false)
$$;

-- RLS Policies for profiles
CREATE POLICY "Users can view their own profile"
ON public.profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all profiles"
ON public.profiles FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update all profiles"
ON public.profiles FOR UPDATE
USING (public.has_role(auth.uid(), 'admin'));

-- RLS Policies for user_roles
CREATE POLICY "Users can view their own roles"
ON public.user_roles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all roles"
ON public.user_roles FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can manage roles"
ON public.user_roles FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- RLS Policies for contributions
CREATE POLICY "Users can view their own contributions"
ON public.contributions FOR SELECT
USING (auth.uid() = user_id AND public.is_user_approved(auth.uid()));

CREATE POLICY "Users can insert their own contributions"
ON public.contributions FOR INSERT
WITH CHECK (auth.uid() = user_id AND public.is_user_approved(auth.uid()));

CREATE POLICY "Admins can view all contributions"
ON public.contributions FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can manage all contributions"
ON public.contributions FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- RLS Policies for loans
CREATE POLICY "Users can view their own loans"
ON public.loans FOR SELECT
USING (auth.uid() = user_id AND public.is_user_approved(auth.uid()));

CREATE POLICY "Users can create loan applications"
ON public.loans FOR INSERT
WITH CHECK (auth.uid() = user_id AND public.is_user_approved(auth.uid()));

CREATE POLICY "Admins can view all loans"
ON public.loans FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can manage all loans"
ON public.loans FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- Add new columns to loans table
ALTER TABLE loans
ADD COLUMN due_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN interest_rate DECIMAL(5,2),
ADD COLUMN total_with_interest DECIMAL(12,2),
ADD COLUMN amount_paid DECIMAL(12,2) DEFAULT 0,
ADD COLUMN last_payment_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN installments_count INTEGER DEFAULT 3;

-- Drop and recreate loan_payments table with proper schema
DROP TABLE IF EXISTS public.loan_payments;
CREATE TABLE public.loan_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    loan_id UUID NOT NULL REFERENCES public.loans(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL,
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    paid_amount DECIMAL(12,2) DEFAULT 0,
    paid_date TIMESTAMP WITH TIME ZONE,
    status TEXT CHECK (status IN ('pending', 'paid', 'overdue')) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create functions for transaction management
CREATE OR REPLACE FUNCTION public.begin_transaction()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Start transaction
    BEGIN;
END;
$$;

CREATE OR REPLACE FUNCTION public.commit_transaction()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Commit transaction
    COMMIT;
END;
$$;

CREATE OR REPLACE FUNCTION public.rollback_transaction()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Rollback transaction
    ROLLBACK;
END;
$$;

-- Create RLS policies for loan_payments
ALTER TABLE public.loan_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own loan payments"
ON public.loan_payments FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.loans
        WHERE loans.id = loan_payments.loan_id
        AND loans.user_id = auth.uid()
    )
);

CREATE POLICY "Admins can view all loan payments"
ON public.loan_payments FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update loan payments"
ON public.loan_payments FOR UPDATE
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can insert loan payments"
ON public.loan_payments FOR INSERT
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Create index for better query performance
CREATE INDEX idx_loan_payments_loan_id ON public.loan_payments(loan_id);

-- Add explicit relationship comments for Supabase
COMMENT ON TABLE public.loan_payments IS E'@graphql({"foreign_keys": [{"columns": ["loan_id"], "foreign_table": "loans", "foreign_columns": ["id"]}]})';
COMMENT ON TABLE public.loans IS E'@graphql({"foreign_keys": [], "relationships": [{"name": "loan_payments", "type": "has_many", "foreign_table": "loan_payments", "foreign_columns": ["loan_id"], "local_columns": ["id"]}]})';

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own loan payments" ON public.loan_payments;
DROP POLICY IF EXISTS "Admins can view all loan payments" ON public.loan_payments;
DROP POLICY IF EXISTS "Admins can update loan payments" ON public.loan_payments;
DROP POLICY IF EXISTS "Admins can insert loan payments" ON public.loan_payments;

-- Add trigger to update updated_at column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_loan_payments_updated_at
    BEFORE UPDATE ON public.loan_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_contributions_updated_at
  BEFORE UPDATE ON public.contributions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_loans_updated_at
  BEFORE UPDATE ON public.loans
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create function to auto-create profile and assign user role on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Insert profile
  INSERT INTO public.profiles (user_id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.email));
  
  -- Assign user role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'user');
  
  RETURN NEW;
END;
$$;

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

  -- Create fines table
CREATE TABLE IF NOT EXISTS fines (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    paid_at TIMESTAMP WITH TIME ZONE,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add RLS policies
ALTER TABLE fines ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own fines
CREATE POLICY "Users can view their own fines"
    ON fines FOR SELECT
    USING (auth.uid() = user_id);

-- Allow admins to manage all fines
CREATE POLICY "Admins can manage all fines"
    ON fines FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_roles.user_id = auth.uid()
            AND user_roles.role = 'admin'
        )
    ); 

-- Add explicit relationship between loans and loan_payments
COMMENT ON CONSTRAINT fk_loan ON public.loan_payments IS 'A loan payment belongs to a loan';
COMMENT ON TABLE public.loan_payments IS '@graphql/belongs-to-one:loan';
COMMENT ON TABLE public.loans IS '@graphql/has-many:loan_payments'; 

