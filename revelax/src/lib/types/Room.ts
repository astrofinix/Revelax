// src/lib/types/Room.ts
export interface Room {
    id: string;
    inviteCode: string;
    players: Player[];
    maxPlayers: number;
    gameState: 'waiting' | 'active' | 'completed';
    createdAt: Date;
  }
  
  // src/lib/types/Player.ts
  export interface Player {
    id: string;
    username: string;
    joinedAt: Date;
  }