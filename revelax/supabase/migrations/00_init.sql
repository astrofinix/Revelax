-- rooms table
create table rooms (
  id uuid default uuid_generate_v4() primary key,
  room_code text unique not null,
  room_name text not null,
  created_at timestamp with time zone default now(),
  admin_id text not null,
  is_active boolean default true
);

-- players table
create table players (
  id uuid default uuid_generate_v4() primary key,
  room_id uuid references rooms(id) on delete cascade,
  user_id text not null,
  username text not null,
  is_connected boolean default true,
  joined_at timestamp with time zone default now()
);