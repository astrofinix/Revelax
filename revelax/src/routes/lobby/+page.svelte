<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';

  let roomName = '';
  let gameMode = '';
  let roomCode = '';
  let players = [];
  let error = '';
  let isLoading = true;
  let copySuccess = false;

  function log(message, type = 'info') {
    const styles = {
      info: '📘 [lobby]',
      error: '🔴 [lobby]',
      success: '✅ [lobby]'
    };
    console.log(`${styles[type]} ${message}`);
  }

  async function fetchRoomDetails() {
    try {
      isLoading = true;
      const roomId = localStorage.getItem('roomId');
      
      if (!roomId) {
        log('No room ID found', 'error');
        goto('/');
        return;
      }

      // Fetch room details
      const { data: room, error: roomError } = await supabase
        .from('rooms')
        .select('room_name, room_code, game_mode')
        .eq('id', roomId)
        .single();

      if (roomError) throw roomError;

      roomName = room.room_name;
      gameMode = room.game_mode;
      roomCode = room.room_code;

      // Fetch players
      const { data: playerList, error: playerError } = await supabase
        .from('players')
        .select('username, is_admin')
        .eq('room_id', roomId)
        .order('created_at', { ascending: true });

      if (playerError) throw playerError;
      players = playerList;

      log('Room details fetched successfully', 'success');
    } catch (err) {
      log(`Error fetching room details: ${err.message}`, 'error');
      error = 'Failed to load room details';
    } finally {
      isLoading = false;
    }
  }

  async function copyRoomCode() {
    try {
      await navigator.clipboard.writeText(roomCode);
      copySuccess = true;
      setTimeout(() => copySuccess = false, 2000);
      log('Room code copied to clipboard', 'success');
    } catch (err) {
      log(`Error copying room code: ${err.message}`, 'error');
    }
  }

  async function leaveRoom() {
    try {
      log('Attempting to leave room...', 'info');
      const userId = localStorage.getItem('userId');
      const roomId = localStorage.getItem('roomId');

      if (!userId || !roomId) {
        log('No user ID or room ID found', 'error');
        goto('/');
        return;
      }

      // Check if current user is admin
      const { data: currentPlayer } = await supabase
        .from('players')
        .select('is_admin')
        .match({ user_id: userId, room_id: roomId })
        .single();

      const isAdmin = currentPlayer?.is_admin;

      // Get remaining active players if current user is admin
      if (isAdmin) {
        const { data: remainingPlayers } = await supabase
          .from('players')
          .select('user_id')
          .match({ room_id: roomId, is_connected: true })
          .neq('user_id', userId);

        if (remainingPlayers && remainingPlayers.length > 0) {
          // Randomly select new admin
          const newAdmin = remainingPlayers[Math.floor(Math.random() * remainingPlayers.length)];
          
          // Update new admin
          const { error: updateError } = await supabase
            .from('players')
            .update({ is_admin: true })
            .match({ user_id: newAdmin.user_id, room_id: roomId });

          if (updateError) throw updateError;
          log('New admin assigned', 'success');
        } else {
          // No players left, delete the room
          const { error: deleteRoomError } = await supabase
            .from('rooms')
            .delete()
            .match({ id: roomId });

          if (deleteRoomError) throw deleteRoomError;
          log('Room deleted - no players remaining', 'info');
        }
      }

      // Delete current player
      const { error: deletePlayerError } = await supabase
        .from('players')
        .delete()
        .match({ user_id: userId, room_id: roomId });

      if (deletePlayerError) throw deletePlayerError;
      log('Player deleted from room', 'success');

      // Clear local storage
      localStorage.removeItem('userId');
      localStorage.removeItem('roomId');
      localStorage.removeItem('currentRoomCode');
      log('Local storage cleared', 'info');

      // Redirect to home
      goto('/');

    } catch (err) {
      log(`Error leaving room: ${err.message}`, 'error');
      error = 'Failed to leave room. Please try again.';
    }
  }

  // Set up real-time subscription for players
  onMount(() => {
    fetchRoomDetails();

    const roomId = localStorage.getItem('roomId');
    if (!roomId) return;

    const subscription = supabase
      .channel(`room:${roomId}`)
      .on('postgres_changes', { 
        event: '*', 
        schema: 'public', 
        table: 'players',
        filter: `room_id=eq.${roomId}`
      }, () => {
        fetchRoomDetails();
      })
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  });
</script>

<div class="min-h-screen bg-gray-800 text-white p-4">
  <div class="max-w-2xl mx-auto space-y-8">
    {#if isLoading}
      <div class="text-center py-8">Loading...</div>
    {:else}
      <!-- Room Details -->
      <div class="bg-gray-700 rounded-lg p-6 space-y-4">
        <h1 class="text-2xl font-bold">{roomName}</h1>
        <div class="text-gray-300">Category: {gameMode}</div>
        
        <!-- Room Code with Copy Button -->
        <div class="flex items-center space-x-4 bg-gray-600 p-3 rounded">
          <div class="text-xl font-mono">Room Code: {roomCode}</div>
          <button
            on:click={copyRoomCode}
            class="px-3 py-1 bg-blue-500 hover:bg-blue-600 rounded transition-colors"
          >
            {copySuccess ? '✓ Copied!' : 'Copy'}
          </button>
        </div>
      </div>

      <!-- Players List -->
      <div class="bg-gray-700 rounded-lg p-6">
        <h2 class="text-xl font-semibold mb-4">Players ({players.length})</h2>
        <div class="space-y-2">
          {#each players as player}
            <div class="flex items-center justify-between p-3 bg-gray-600 rounded">
              <span>{player.username}</span>
              {#if player.is_admin}
                <span class="text-xs bg-blue-500 px-2 py-1 rounded">Admin</span>
              {/if}
            </div>
          {/each}
        </div>
      </div>

      <!-- Error Message -->
      {#if error}
        <div class="text-red-500 text-sm p-2 bg-red-500/10 rounded">
          {error}
        </div>
      {/if}

      <!-- Leave Room Button -->
      <button
        on:click={leaveRoom}
        class="w-full bg-red-500 hover:bg-red-600 text-white px-6 py-3 rounded-lg transition-colors"
      >
        Leave Room
      </button>
    {/if}
  </div>
</div>
