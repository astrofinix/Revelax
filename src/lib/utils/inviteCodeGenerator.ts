// src/lib/utils/inviteCodeGenerator.ts
export function generateInviteCode(): string {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return Array.from(
      { length: 6 }, 
      () => characters[Math.floor(Math.random() * characters.length)]
    ).join('');
  }