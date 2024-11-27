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
CREATE TABLE IF NOT EXISTS game_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    card_sequence INTEGER[] NOT NULL,
    player_sequence UUID[] NOT NULL,
    current_card INTEGER NOT NULL,
    current_card_index INTEGER DEFAULT 0,
    current_player_index INTEGER DEFAULT 0,
    current_card_revealed BOOLEAN DEFAULT false,
    game_started BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_update TIMESTAMPTZ DEFAULT NOW()
);

-- Add partial index to ensure only one active session per room
CREATE UNIQUE INDEX idx_unique_active_session_per_room 
ON public.game_sessions (room_id) 
WHERE is_active = true;

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

-- Players table (updated with last_updated column)
CREATE TABLE public.players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    username TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT false,
    is_connected BOOLEAN DEFAULT true,
    is_ready BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Add trigger function for last_updated
CREATE OR REPLACE FUNCTION update_last_updated_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for players table
CREATE TRIGGER update_players_last_updated
    BEFORE UPDATE ON players
    FOR EACH ROW
    EXECUTE FUNCTION update_last_updated_column();

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

-- Create function for atomic session deactivation
CREATE OR REPLACE FUNCTION deactivate_game_sessions(p_room_id uuid, p_timestamp timestamptz)
RETURNS void AS $$
BEGIN
  UPDATE game_sessions
  SET is_active = false,
      last_update = p_timestamp
  WHERE room_id = p_room_id
    AND is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function for safe game session creation
CREATE OR REPLACE FUNCTION create_game_session_safe(
  p_room_id uuid,
  p_card_sequence integer[],
  p_player_sequence uuid[],
  p_started_at timestamptz
)
RETURNS json AS $$
DECLARE
  v_session_id uuid;
  v_result json;
  v_room_status text;
BEGIN
  -- Check room status first
  SELECT status INTO v_room_status
  FROM rooms
  WHERE id = p_room_id
  FOR UPDATE;  -- Lock the row

  IF v_room_status != 'starting' THEN
    RAISE EXCEPTION 'Room not in starting state';
  END IF;

  -- Deactivate existing sessions and create new one
  UPDATE game_sessions
  SET is_active = false,
      last_update = p_started_at
  WHERE room_id = p_room_id
    AND is_active = true;

  -- Create new session
  INSERT INTO game_sessions (
    room_id,
    card_sequence,
    current_card,
    current_card_index,
    player_sequence,
    current_player_index,
    is_active,
    game_started,
    started_at,
    last_update,
    current_card_revealed
  )
  VALUES (
    p_room_id,
    p_card_sequence,
    p_card_sequence[1],
    0,
    p_player_sequence,
    0,
    true,
    true,
    p_started_at,
    p_started_at,
    false
  )
  RETURNING id INTO v_session_id;

  -- Update room status to playing
  UPDATE rooms
  SET status = 'playing',
      game_session_id = v_session_id
  WHERE id = p_room_id
  AND status = 'starting';  -- Double check status

  -- Return the created session
  SELECT row_to_json(gs.*)
  INTO v_result
  FROM game_sessions gs
  WHERE gs.id = v_session_id;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert the card data
INSERT INTO public.game_cards (game_mode, card_index, content) VALUES
    -- fil_chill cards
    ('fil_chill', 1, 'Share your favorite Filipino food and why.'),
    ('fil_chill', 2, 'What''s your go-to pulutan?'),
    ('fil_chill', 3, 'What Filipino tradition do you wish more people knew about?'),
    ('fil_chill', 4, 'What''s your favorite Filipino street food?'),
    ('fil_chill', 5, 'Share your most memorable fiesta experience.'),
    
    -- yap_sesh cards
    ('yap_sesh', 1, 'Tell us about your most embarrassing moment.'),
    ('yap_sesh', 2, 'What''s your biggest pet peeve?'),
    ('yap_sesh', 3, 'What''s the worst fashion choice you''ve ever made?'),
    ('yap_sesh', 4, 'What''s your go-to karaoke song?'),
    ('yap_sesh', 5, 'What''s the most ridiculous thing you''ve done for love?'),
    
    -- night_talk cards
    ('night_talk', 1, 'What''s your biggest fear in life?'),
    ('night_talk', 2, 'If you could change one decision in your past, what would it be?'),
    ('night_talk', 3, 'What''s your definition of success?'),
    ('night_talk', 4, 'What do you think happens after we die?'),
    ('night_talk', 5, 'What''s the most valuable life lesson you''ve learned?'),
    
    -- love_exp cards
    ('love_exp', 1, 'Given the choice of anyone in the world, whom would you want as a dinner guest?'),
    ('love_exp', 2, 'Would you like to be famous? In what way?'),
    ('love_exp', 3, 'Before making a telephone call, do you ever rehearse what you are going to say? Why?'),
    ('love_exp', 4, 'What would constitute a "perfect" day for you?'),
    ('love_exp', 5, 'When did you last sing to yourself? To someone else?');

-- Add unique constraint for game mode and card index combination
ALTER TABLE public.game_cards
ADD CONSTRAINT unique_game_mode_card_index UNIQUE (game_mode, card_index);