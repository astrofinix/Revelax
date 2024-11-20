import { json } from '@sveltejs/kit';
import { supabase } from '$lib/supabaseClient';

function generateRoomCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

export async function POST({ request }) {
  try {
    const { roomName, adminId, username } = await request.json();
    
    // Generate a unique room code
    let roomCode;
    let isUnique = false;
    
    while (!isUnique) {
      roomCode = generateRoomCode();
      
      // Check if code exists
      const { data: existingRoom } = await supabase
        .from('rooms')
        .select('room_code')
        .eq('room_code', roomCode)
        .single();
      
      if (!existingRoom) {
        isUnique = true;
      }
    }
    
    // Create room
    const { data: room, error: roomError } = await supabase
      .from('rooms')
      .insert({
        room_code: roomCode,
        room_name: roomName,
        admin_id: adminId,
      })
      .select()
      .single();
    
    if (roomError) throw roomError;
    
    // Add admin as first player
    const { error: playerError } = await supabase
      .from('players')
      .insert({
        room_id: room.id,
        user_id: adminId,
        username: username,
      });
    
    if (playerError) throw playerError;
    
    return json({ success: true, room });
    
  } catch (error) {
    console.error('Error creating room:', error);
    return json({ success: false, error: 'Failed to create room' });
  }
}