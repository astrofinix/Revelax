interface GameMode {
  id: string;
  name: string;
  description: string;
  cardCount: number;
}

export const gameModes: Record<string, GameMode> = {
  fil_chill: {
    id: 'fil_chill',
    name: '🍻 The Filipino Chillnuman',
    description: 'Casual questions about Filipino culture, food, and traditions. Perfect for a laid-back gathering with friends.',
    cardCount: 20
  },
  yap_sesh: {
    id: 'yap_sesh',
    name: '💭 Yap Session',
    description: 'Fun and light-hearted questions to get everyone talking and laughing. Great for breaking the ice!',
    cardCount: 25
  },
  night_talk: {
    id: 'night_talk',
    name: '🌙 Deep Night Talks',
    description: 'Thought-provoking questions for meaningful conversations. Best played during those late-night heart-to-heart moments.',
    cardCount: 30
  },
  love_exp: {
    id: 'love_exp',
    name: '❤️ The Love (?) Experiment',
    description: 'Inspired by the 36 questions that lead to love. Intimate questions designed to create meaningful connections between players.',
    cardCount: 36
  }
};