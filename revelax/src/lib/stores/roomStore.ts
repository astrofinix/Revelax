// src/lib/stores/roomStore.ts
import { writable } from 'svelte/store';
import type { Room, Player } from '$lib/types';

function createRoomStore() {
  const { subscribe, set, update } = writable<Room | null>(null);

  return {
    subscribe,
    createRoom: (player: Player) => {
      const newRoom: Room = {
        id: crypto.randomUUID(),
        inviteCode: generateInviteCode(),
        players: [player],
        maxPlayers: 8,
        gameState: 'waiting',
        createdAt: new Date()
      };
      set(newRoom);
      return newRoom;
    },
    joinRoom: (room: Room, player: Player) => {
      if (room.players.length < 8) {
        update(r => r ? { ...r, players: [...r.players, player] } : null);
      }
    }
  };
}

export const roomStore = createRoomStore();