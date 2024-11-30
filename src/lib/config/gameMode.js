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
    description: 'Casual bardagulan questions, dares to get everyone talking and laughing. Perfect for a chaos-and-fun-filled gathering.',
    cardCount: 20
  },
  yap_sesh: {
    id: 'yap_sesh',
    name: '💬 Yap Session',
    description: 'A lively mix of quirky and easygoing questions to spark fun conversations and endless laughs. Perfect for warming up the group and setting the vibe.',
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
    description: 'Inspired by the 36 questions that lead to love. Delve into questions designed to create meaningful connections.',
    cardCount: 36
  }
};