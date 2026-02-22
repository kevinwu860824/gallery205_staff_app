-- Create inventory_items table
create table if not exists public.inventory_items (
  id uuid default gen_random_uuid() primary key,
  shop_id text not null,
  name text not null,
  total_units numeric not null default 0, -- The "Max HP" (e.g. 700ml for a bottle)
  current_stock numeric not null default 0, -- The "Current HP"
  unit_label text not null default 'unit', -- e.g. 'ml', 'g', 'oz'
  low_stock_threshold numeric default 0, -- Safety stock level
  cost_per_unit numeric default 0, -- For cost calculation
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create inventory_transactions table
create table if not exists public.inventory_transactions (
  id uuid default gen_random_uuid() primary key,
  shop_id text not null,
  inventory_item_id uuid not null references public.inventory_items(id) on delete cascade,
  change_amount numeric not null, -- Positive for add, Negative for subtract
  transaction_type text not null, -- 'initial', 'restock', 'sale', 'waste', 'correction', 'void_return'
  related_order_id uuid, -- Optional link to orders table (if exists)
  note text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS Policies (Simple open access for authenticated shop users)
alter table public.inventory_items enable row level security;
alter table public.inventory_transactions enable row level security;

create policy "Enable all access for authenticated users" on public.inventory_items
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Enable all access for authenticated users" on public.inventory_transactions
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Indices for performance
create index if not exists inventory_items_shop_id_idx on public.inventory_items(shop_id);
create index if not exists inventory_transactions_item_id_idx on public.inventory_transactions(inventory_item_id);
create index if not exists inventory_transactions_shop_id_idx on public.inventory_transactions(shop_id);
