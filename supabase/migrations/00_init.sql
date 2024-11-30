-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create deck_cards table FIRST
CREATE TABLE public.deck_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    game_mode TEXT NOT NULL,
    sequence_pattern INTEGER[] NOT NULL, -- Stores patterns like [5,3,2]
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- Add unique constraint for game_mode
ALTER TABLE public.deck_cards
ADD CONSTRAINT unique_game_mode UNIQUE (game_mode);

-- Insert deck patterns SECOND
INSERT INTO public.deck_cards (game_mode, sequence_pattern) VALUES
    ('fil_chill', ARRAY[3,2]), -- First 3 cards random, next 2 random
    ('yap_sesh', ARRAY[2,2,1]), -- First 2 random, next 2 random, last 1 random
    ('night_talk', ARRAY[2,3]), -- First 2 random, next 3 random
    ('love_exp', ARRAY[12,12,12,1]); -- First 36 cards in groups of 12, last 1 random

-- THEN create game_cards table with foreign key reference
CREATE TABLE public.game_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    game_mode TEXT NOT NULL,
    card_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    deck_id UUID REFERENCES public.deck_cards(id)
);

-- Add unique constraint for game mode and card index combination
ALTER TABLE public.game_cards
ADD CONSTRAINT unique_game_mode_card_index UNIQUE (game_mode, card_index);

-- THEN insert the card data
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
    ('love_exp', 1, 'What''s your biggest fear in life?'),
    ('love_exp', 2, 'If you could change one decision in your past, what would it be?'),
    ('love_exp', 3, 'What''s your definition of success?'),
    ('love_exp', 4, 'What do you think happens after we die?'),
    ('love_exp', 5, 'What''s the most valuable life lesson you''ve learned?'),
    ('love_exp', 6, 'If you were able to live to the age of 90 and retain either the mind or body of a 30-year-old for the last 60 years of your life, which would you want?'),
    ('love_exp', 7, 'Do you have a secret hunch about how you will die?'),
    ('love_exp', 8, 'Name three things you and your partner appear to have in common.'),
    ('love_exp', 9, 'For what in your life do you feel most grateful?'),
    ('love_exp', 10, 'If you could change anything about the way you were raised, what would it be?'),
    ('love_exp', 11, 'Take four minutes and tell your partner your life story in as much detail as possible.'),
    ('love_exp', 12, 'If you could wake up tomorrow having gained any one quality or ability, what would it be?'),
    ('love_exp', 13, 'If a crystal ball could tell you the truth about yourself, your life, the future or anything else, what would you want to know?'),
    ('love_exp', 14, 'Is there something that you''ve dreamed of doing for a long time? Why haven''t you done it?'),
    ('love_exp', 15, 'What is the greatest accomplishment of your life?'),
    ('love_exp', 16, 'What do you value most in a friendship?'),
    ('love_exp', 17, 'What is your most treasured memory?'),
    ('love_exp', 18, 'What is your most terrible memory?'),
    ('love_exp', 19, 'If you knew that in one year you would die suddenly, would you change anything about the way you are now living? Why?'),
    ('love_exp', 20, 'What does friendship mean to you?'),
    ('love_exp', 21, 'What roles do love and affection play in your life?'),
    ('love_exp', 22, 'Alternate sharing something you consider a positive characteristic of your partner. Share a total of five items.'),
    ('love_exp', 23, 'How close and warm is your family? Do you feel your childhood was happier than most other people''s?'),
    ('love_exp', 24, 'How do you feel about your relationship with your mother?'),
    ('love_exp', 25, 'Make three true "we" statements each. For instance, "We are both in this room feeling ..."'),
    ('love_exp', 26, 'Complete this sentence: "I wish I had someone with whom I could share ..."'),
    ('love_exp', 27, 'If you were going to become a close friend with your partner, please share what would be important for him or her to know.'),
    ('love_exp', 28, 'Tell your partner what you like about them; be very honest this time, saying things that you might not say to someone you''ve just met.'),
    ('love_exp', 29, 'Share with your partner an embarrassing moment in your life.'),
    ('love_exp', 30, 'When did you last cry in front of another person? By yourself?'),
    ('love_exp', 31, 'Tell your partner something that you like about them already.'),
    ('love_exp', 32, 'What, if anything, is too serious to be joked about?'),
    ('love_exp', 33, 'If you were to die this evening with no opportunity to communicate with anyone, what would you most regret not having told someone? Why haven''t you told them yet?'),
    ('love_exp', 34, 'Your house, containing everything you own, catches fire. After saving your loved ones and pets, you have time to safely make a final dash to save any one item. What would it be? Why?'),
    ('love_exp', 35, 'Of all the people in your family, whose death would you find most disturbing? Why?'),
    ('love_exp', 36, 'Share a personal problem and ask your partner''s advice on how he or she might handle it. Also, ask your partner to reflect back to you how you seem to be feeling about the problem you have chosen.'),
    ('love_exp', 37, 'Now, stare into each other''s eyes for four whole minutes, possibly without talking.');

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
    player_sequence UUID[] NOT NULL,
    current_card INTEGER NOT NULL,
    current_card_index INTEGER DEFAULT 0,
    current_player_index INTEGER DEFAULT 0,
    current_card_revealed BOOLEAN DEFAULT false,
    current_card_content TEXT,
    last_active_player_index INTEGER,
    next_player_index INTEGER,
    activity_status TEXT DEFAULT 'active',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_update TIMESTAMPTZ DEFAULT NOW()
);
-- Add partial index to ensure only one active session per room
CREATE UNIQUE INDEX idx_unique_active_session_per_room 
ON public.game_sessions (room_id) 
WHERE activity_status = 'active';

-- Add foreign key reference back to game_sessions
ALTER TABLE public.rooms 
    ADD CONSTRAINT fk_game_session 
    FOREIGN KEY (game_session_id) 
    REFERENCES public.game_sessions(id) 
    ON DELETE SET NULL;

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
  SET activity_status = 'inactive',
      last_update = p_timestamp
  WHERE room_id = p_room_id
    AND activity_status = 'active';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function for safe game session creation
CREATE OR REPLACE FUNCTION create_game_session_safe(
  p_room_id uuid,
  p_player_sequence uuid[],
  p_started_at timestamptz
)
RETURNS json AS $$
DECLARE
  v_session_id uuid;
  v_result json;
  v_existing_session game_sessions%ROWTYPE;
  v_game_mode TEXT;
  v_card_sequence INTEGER[];
BEGIN
  -- Check for existing active session
  SELECT * INTO v_existing_session
  FROM game_sessions
  WHERE room_id = p_room_id
    AND activity_status = 'active';

  -- If active session exists, return it
  IF FOUND THEN
    SELECT row_to_json(v_existing_session.*) INTO v_result;
    RETURN v_result;
  END IF;

  -- Get game mode from room
  SELECT game_mode INTO v_game_mode
  FROM rooms
  WHERE id = p_room_id;

  -- Set any existing sessions for this room to inactive
  UPDATE game_sessions
  SET activity_status = 'inactive',
      last_update = p_started_at
  WHERE room_id = p_room_id;

  -- Create new session
  INSERT INTO game_sessions (
    room_id,
    card_sequence,
    current_card,
    current_card_index,
    player_sequence,
    current_player_index,
    activity_status,
    started_at,
    last_update,
    current_card_revealed,
    current_card_content
  )
  VALUES (
    p_room_id,
    v_card_sequence,
    v_card_sequence[1],
    0,
    p_player_sequence,
    0,
    'active',
    p_started_at,
    p_started_at,
    false,
    NULL
  )
  RETURNING id INTO v_session_id;

  -- Update room status
  UPDATE rooms
  SET status = 'playing',
      game_session_id = v_session_id
  WHERE id = p_room_id;

  -- Return the created session
  SELECT row_to_json(gs.*)
  INTO v_result
  FROM game_sessions gs
  WHERE gs.id = v_session_id;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- All indexes should be created at the end of the migration, and only once
DROP INDEX IF EXISTS idx_game_cards_mode;
CREATE INDEX idx_game_cards_mode ON public.game_cards(game_mode);