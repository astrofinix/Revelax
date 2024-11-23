-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Rooms table
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_code TEXT UNIQUE NOT NULL,
    room_name TEXT NOT NULL,
    admin_id UUID NOT NULL,
    game_mode TEXT NOT NULL DEFAULT 'classic',
    is_active BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'waiting',
    game_session_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Game Sessions table
CREATE TABLE public.game_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    card_sequence INTEGER[] NOT NULL,
    current_player_index INTEGER DEFAULT 0,
    current_card_index INTEGER DEFAULT 0,
    current_card INTEGER,
    is_active BOOLEAN DEFAULT true,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- Add foreign key reference back to game_sessions
ALTER TABLE public.rooms 
    ADD CONSTRAINT fk_game_session 
    FOREIGN KEY (game_session_id) 
    REFERENCES public.game_sessions(id) 
    ON DELETE SET NULL;

-- Game Cards table
CREATE TABLE public.game_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    game_mode TEXT NOT NULL,
    card_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- Players table
CREATE TABLE public.players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    username TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT false,
    is_connected BOOLEAN DEFAULT true,
    is_ready BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for better query performance
CREATE INDEX idx_rooms_game_session ON public.rooms(game_session_id);
CREATE INDEX idx_players_room ON public.players(room_id);
CREATE INDEX idx_game_sessions_room ON public.game_sessions(room_id);
CREATE INDEX idx_game_cards_mode ON public.game_cards(game_mode);

-- Policies
CREATE POLICY "Allow players to delete themselves"
ON public.players
FOR DELETE
USING (auth.uid() IS NOT NULL);

-- Add some basic game modes
INSERT INTO public.game_cards (game_mode, card_index, content) VALUES
    ('fil_chill', 1, 'Share your favorite Filipino food and why.'),
    ('fil_chill', 2, 'What''s your go-to pulutan?'),
    ('yap_sesh', 1, 'Tell us about your most embarrassing moment.'),
    ('yap_sesh', 2, 'What''s your biggest pet peeve?'),
    ('night_talk', 1, 'What''s your biggest fear in life?'),
    ('night_talk', 2, 'If you could change one decision in your past, what would it be?');