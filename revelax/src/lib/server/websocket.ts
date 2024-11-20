import { WebSocketServer } from 'ws';
import { supabase } from '$lib/supabaseClient';

export function setupWebSocket(server) {
  const wss = new WebSocketServer({ server });
  
  // Track connected clients by room
  const rooms = new Map();
  
  wss.on('connection', async (ws, req) => {
    const roomCode = req.url.split('/').pop();
    
    // Get room details
    const { data: room } = await supabase
      .from('rooms')
      .select('*')
      .eq('room_code', roomCode)
      .single();
      
    if (!room) {
      ws.close();
      return;
    }
    
    // Add client to room
    if (!rooms.has(roomCode)) {
      rooms.set(roomCode, new Set());
    }
    rooms.get(roomCode).add(ws);
    
    // Handle disconnection
    ws.on('close', async () => {
      rooms.get(roomCode).delete(ws);
      
      // If room is empty, delete it
      if (rooms.get(roomCode).size === 0) {
        await supabase
          .from('rooms')
          .delete()
          .eq('room_code', roomCode);
        rooms.delete(roomCode);
        return;
      }
      
      // Check if disconnected user was admin
      const { data: players } = await supabase
        .from('players')
        .select('*')
        .eq('room_id', room.id)
        .eq('is_connected', true);
      
      if (players.length > 0) {
        // Randomly select new admin
        const newAdmin = players[Math.floor(Math.random() * players.length)];
        
        // Update admin in database
        await supabase
          .from('rooms')
          .update({ admin_id: newAdmin.user_id })
          .eq('id', room.id);
          
        // Notify all clients in room
        const message = JSON.stringify({
          type: 'admin_changed',
          newAdminId: newAdmin.user_id
        });
        
        rooms.get(roomCode).forEach(client => {
          if (client.readyState === 1) {
            client.send(message);
          }
        });
      }
    });
  });
}