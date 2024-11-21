-- Create rooms table
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_code TEXT UNIQUE NOT NULL,
    room_name TEXT NOT NULL,
    admin_id UUID NOT NULL,
    game_mode TEXT NOT NULL DEFAULT 'yap_sesh',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create players table
CREATE TABLE public.players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    username TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT false,
    is_connected BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create necessary indexes
CREATE INDEX idx_rooms_room_code ON public.rooms(room_code);
CREATE INDEX idx_players_room_id ON public.players(room_id);
CREATE INDEX idx_players_user_id ON public.players(user_id);

-- Set up Row Level Security (RLS)
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for all users" ON public.rooms
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users only" ON public.rooms
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable read access for all users" ON public.players
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users only" ON public.players
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable delete for users" ON public.players
    FOR DELETE USING (true);