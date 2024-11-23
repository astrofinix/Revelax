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
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    last_update TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
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

-- Add cards for fil_chill (casual Filipino-themed questions)
INSERT INTO public.game_cards (game_mode, card_index, content) VALUES
    ('fil_chill', 3, 'What Filipino tradition do you wish more people knew about?'),
    ('fil_chill', 4, 'What''s your favorite Filipino street food?'),
    ('fil_chill', 5, 'Share your most memorable fiesta experience.'),
    ('fil_chill', 6, 'Which Filipino dessert brings back childhood memories?'),
    ('fil_chill', 7, 'What''s your go-to Filipino comfort food?'),
    ('fil_chill', 8, 'Share a funny moment with your Filipino family.'),
    ('fil_chill', 9, 'What''s your favorite Filipino holiday and why?'),
    ('fil_chill', 10, 'Which Filipino snack do you always bring abroad?'),
    ('fil_chill', 11, 'What''s your favorite Filipino childhood game?'),
    ('fil_chill', 12, 'Share your most memorable simbang gabi experience.'),
    ('fil_chill', 13, 'What''s your favorite Filipino saying or expression?'),
    ('fil_chill', 14, 'Which Filipino movie or TV show makes you nostalgic?'),
    ('fil_chill', 15, 'What''s your favorite Filipino breakfast combo?'),
    ('fil_chill', 16, 'Share a funny tita/tito story.'),
    ('fil_chill', 17, 'What''s your favorite Filipino festival?'),
    ('fil_chill', 18, 'Which Filipino song always gets you dancing?'),
    ('fil_chill', 19, 'What''s your favorite Filipino merienda?'),
    ('fil_chill', 20, 'Share your most memorable Filipino Christmas tradition.'),

-- Add cards for yap_sesh (fun, casual conversation starters)
    ('yap_sesh', 3, 'What''s the worst fashion choice you''ve ever made?'),
    ('yap_sesh', 4, 'What''s your go-to karaoke song?'),
    ('yap_sesh', 5, 'What''s the most ridiculous thing you''ve done for love?'),
    ('yap_sesh', 6, 'What''s your worst cooking disaster?'),
    ('yap_sesh', 7, 'What''s the strangest dream you''ve ever had?'),
    ('yap_sesh', 8, 'What''s your favorite guilty pleasure TV show?'),
    ('yap_sesh', 9, 'What''s the worst advice you''ve ever received?'),
    ('yap_sesh', 10, 'What''s your most unusual talent?'),
    ('yap_sesh', 11, 'What''s the most embarrassing song on your playlist?'),
    ('yap_sesh', 12, 'What''s your worst date story?'),
    ('yap_sesh', 13, 'What''s the weirdest food combination you enjoy?'),
    ('yap_sesh', 14, 'What''s your most irrational fear?'),
    ('yap_sesh', 15, 'What''s the most impulsive thing you''ve ever bought?'),
    ('yap_sesh', 16, 'What''s your favorite childhood memory?'),
    ('yap_sesh', 17, 'What''s the worst job you''ve ever had?'),
    ('yap_sesh', 18, 'What''s your most used emoji and why?'),
    ('yap_sesh', 19, 'What''s the most adventurous thing you''ve ever done?'),
    ('yap_sesh', 20, 'What''s your favorite way to waste time?'),

-- Add cards for night_talk (deeper, more reflective questions)
    ('night_talk', 3, 'What''s your definition of success?'),
    ('night_talk', 4, 'What do you think happens after we die?'),
    ('night_talk', 5, 'What''s the most valuable life lesson you''ve learned?'),
    ('night_talk', 6, 'What would you tell your younger self?'),
    ('night_talk', 7, 'What''s your biggest regret in life?'),
    ('night_talk', 8, 'What do you think is the meaning of life?'),
    ('night_talk', 9, 'What''s your biggest insecurity?'),
    ('night_talk', 10, 'What''s something you''ve never told anyone?'),
    ('night_talk', 11, 'What''s your biggest dream that you haven''t achieved yet?'),
    ('night_talk', 12, 'What''s the hardest truth you''ve had to accept?'),
    ('night_talk', 13, 'What''s your biggest sacrifice for someone else?'),
    ('night_talk', 14, 'What''s your definition of true love?'),
    ('night_talk', 15, 'What''s your biggest moral dilemma?'),
    ('night_talk', 16, 'What legacy do you want to leave behind?'),
    ('night_talk', 17, 'What''s your biggest personal challenge?'),
    ('night_talk', 18, 'What''s something you wish you could forgive?'),
    ('night_talk', 19, 'What''s your biggest fear about the future?'),
    ('night_talk', 20, 'What''s the most profound realization you''ve had?');

    -- Add cards for love_exp (based on the 36 questions that lead to love study)
INSERT INTO public.game_cards (game_mode, card_index, content) VALUES
    ('love_exp', 1, 'Given the choice of anyone in the world, whom would you want as a dinner guest?'),
    ('love_exp', 2, 'Would you like to be famous? In what way?'),
    ('love_exp', 3, 'Before making a telephone call, do you ever rehearse what you are going to say? Why?'),
    ('love_exp', 4, 'What would constitute a "perfect" day for you?'),
    ('love_exp', 5, 'When did you last sing to yourself? To someone else?'),
    ('love_exp', 6, 'If you were able to live to the age of 90 and retain either the mind or body of a 30-year-old for the last 60 years of your life, which would you want?'),
    ('love_exp', 7, 'Do you have a secret hunch about how you will die?'),
    ('love_exp', 8, 'Name three things you and the other players appear to have in common.'),
    ('love_exp', 9, 'For what in your life do you feel most grateful?'),
    ('love_exp', 10, 'If you could change anything about how you were raised, what would it be?'),
    ('love_exp', 11, 'Take four minutes and tell the other players your life story in as much detail as possible.'),
    ('love_exp', 12, 'If you could wake up tomorrow having gained any one quality or ability, what would it be?'),
    ('love_exp', 13, 'If a crystal ball could tell you the truth about yourself, your life, the future, or anything else, what would you want to know?'),
    ('love_exp', 14, 'Is there something that you''ve dreamed of doing for a long time? Why haven''t you done it?'),
    ('love_exp', 15, 'What is the greatest accomplishment of your life?'),
    ('love_exp', 16, 'What do you value most in a friendship?'),
    ('love_exp', 17, 'What is your most treasured memory?'),
    ('love_exp', 18, 'What is your most terrible memory?'),
    ('love_exp', 19, 'If you knew that in one year you would die suddenly, would you change anything about the way you are now living? Why?'),
    ('love_exp', 20, 'What does friendship mean to you?'),
    ('love_exp', 21, 'What roles do love and affection play in your life?'),
    ('love_exp', 22, 'Share something you consider a positive characteristic of the person next to you. Share a total of 5 items.'),
    ('love_exp', 23, 'How close and warm is your family? Do you feel your childhood was happier than most other people''s?'),
    ('love_exp', 24, 'How do you feel about your relationship with your mother?'),
    ('love_exp', 25, 'Make three true "we" statements. For instance, "We are all in this room feeling..."'),
    ('love_exp', 26, 'Complete this sentence: "I wish I had someone with whom I could share..."'),
    ('love_exp', 27, 'If you were going to become close friends with someone here, please share what would be important for them to know.'),
    ('love_exp', 28, 'Tell the other players what you like about them; be very honest this time, saying things that you might not say to someone you''ve just met.'),
    ('love_exp', 29, 'Share with the others an embarrassing moment in your life.'),
    ('love_exp', 30, 'When did you last cry in front of another person? By yourself?'),
    ('love_exp', 31, 'Tell the other players something that you like about them already.'),
    ('love_exp', 32, 'What, if anything, is too serious to be joked about?'),
    ('love_exp', 33, 'If you were to die this evening with no opportunity to communicate with anyone, what would you most regret not having told someone? Why haven''t you told them yet?'),
    ('love_exp', 34, 'Your house, containing everything you own, catches fire. After saving your loved ones and pets, you have time to safely make a final dash to save any one item. What would it be? Why?'),
    ('love_exp', 35, 'Of all the people in your family, whose death would you find most disturbing? Why?'),
    ('love_exp', 36, 'Share a personal problem and ask the other players'' advice on how they might handle it. Ask them to reflect back to you how you seem to be feeling about the problem you have chosen.');