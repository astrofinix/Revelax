<script>
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';

  let roomName = '';
  let gameMode = '';
  let roomCode = '';
  let players = [];
  let error = '';
  let isLoading = true;
  let copySuccess = false;
  let isAdmin = false;
  let refreshInterval;
  let subscription;
  let isLeavingVoluntarily = false;

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
      const roomId = localStorage.getItem('roomId');
      const userId = localStorage.getItem('userId');
      
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

      // Fetch players with user_id
      const { data: playerList, error: playerError } = await supabase
        .from('players')
        .select('username, is_admin, user_id')
        .eq('room_id', roomId)
        .order('created_at', { ascending: true });

      if (playerError) throw playerError;
      
      players = playerList;
      isAdmin = players.some(player => player.user_id === userId && player.is_admin);

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
      isLeavingVoluntarily = true;
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

      if (currentPlayer?.is_admin) {
        // Get remaining players
        const { data: remainingPlayers } = await supabase
          .from('players')
          .select('user_id')
          .eq('room_id', roomId)
          .neq('user_id', userId);

        if (remainingPlayers && remainingPlayers.length > 0) {
          // Assign new admin
          const newAdmin = remainingPlayers[Math.floor(Math.random() * remainingPlayers.length)];
          
          await supabase
            .from('players')
            .update({ is_admin: true })
            .match({ user_id: newAdmin.user_id, room_id: roomId });
          
          log('New admin assigned', 'success');
        } else {
          // Only delete room if no players are left
          await supabase
            .from('rooms')
            .delete()
            .match({ id: roomId });
            
          log('Room deleted - no players remaining', 'info');
        }
      }

      // Delete only the current player
      await supabase
        .from('players')
        .delete()
        .match({ user_id: userId, room_id: roomId });

      log('Player removed from room', 'success');

      // Clear only the current user's local storage
      localStorage.removeItem('userId');
      localStorage.removeItem('roomId');
      localStorage.removeItem('currentRoomCode');

      // Navigate to home
      goto('/');

    } catch (err) {
      log(`Error leaving room: ${err.message}`, 'error');
      error = 'Failed to leave room. Please try again.';
      isLeavingVoluntarily = false;
    }
  }

  async function startGame() {
    try {
      const roomId = localStorage.getItem('roomId');
      // Add your game start logic here
      log('Starting game...', 'info');
      goto(`/game/${roomId}`); // Adjust the route as needed
    } catch (err) {
      log(`Error starting game: ${err.message}`, 'error');
      error = 'Failed to start game. Please try again.';
    }
  }

  function setupRealtimeSubscription() {
    const roomId = localStorage.getItem('roomId');
    const userId = localStorage.getItem('userId');
    
    if (!roomId || !userId) return;

    subscription = supabase
      .channel(`room:${roomId}`)
      .on('postgres_changes', { 
        event: '*', 
        schema: 'public', 
        table: 'players',
        filter: `room_id=eq.${roomId}`
      }, async (payload) => {
        log(`Player change detected: ${payload.eventType}`, 'info');
        
        // Only check for room existence and update player list
        const { data: room } = await supabase
          .from('rooms')
          .select('id')
          .eq('id', roomId)
          .single();

        if (!room) {
          // Only redirect if the room is actually gone
          if (isLeavingVoluntarily) {
            goto('/');
          }
          return;
        }

        // Update player list without redirecting
        fetchRoomDetails();
      })
      .subscribe();
  }

  // Set up real-time subscription for players
  onMount(async () => {
    const roomId = localStorage.getItem('roomId');
    const userId = localStorage.getItem('userId');

    if (!roomId || !userId) {
      goto('/');
      return;
    }

    // Initial room check
    const { data: room } = await supabase
      .from('rooms')
      .select('id')
      .eq('id', roomId)
      .single();

    if (!room) {
      goto('/');
      return;
    }

    // Initial player check
    const { data: player } = await supabase
      .from('players')
      .select('id')
      .match({ user_id: userId, room_id: roomId })
      .single();

    if (!player) {
      goto('/');
      return;
    }

    await fetchRoomDetails();
    setupRealtimeSubscription();

    // Set up periodic refresh
    refreshInterval = setInterval(() => {
      fetchRoomDetails();
    }, 5000);
  });

  onDestroy(() => {
    // Clean up
    if (refreshInterval) clearInterval(refreshInterval);
    if (subscription) subscription.unsubscribe();
    isLeavingVoluntarily = false;
  });
</script>

<div class="min-h-screen bg-background p-4">
  <div class="max-w-2xl mx-auto space-y-8">
    {#if isLoading}
      <Card.Root>
        <Card.Header>
          <div class="h-8 bg-muted animate-pulse rounded" />
        </Card.Header>
        <Card.Content>
          <div class="space-y-4">
            <div class="h-4 bg-muted animate-pulse rounded" />
            <div class="h-12 bg-muted animate-pulse rounded" />
          </div>
        </Card.Content>
      </Card.Root>
    {:else}
      <!-- Room Details -->
      <Card.Root>
        <Card.Header>
          <Card.Title>{roomName}</Card.Title>
          <Card.Description>Category: {gameMode}</Card.Description>
        </Card.Header>
        <Card.Content>
          <div class="flex items-center justify-between p-3 bg-muted rounded-md">
            <code class="text-sm font-mono">Room Code: {roomCode}</code>
            <Button 
              variant="secondary" 
              size="sm"
              on:click={copyRoomCode}
            >
              {copySuccess ? '✓ Copied!' : 'Copy'}
            </Button>
          </div>
        </Card.Content>
      </Card.Root>

      <!-- Players List -->
      <Card.Root>
        <Card.Header>
          <Card.Title>Players ({players.length})</Card.Title>
        </Card.Header>
        <Card.Content class="space-y-2">
          {#each players as player}
            <div class="flex items-center justify-between p-3 bg-muted rounded-md">
              <span>{player.username}</span>
              {#if player.is_admin}
                <span class="text-xs bg-primary text-primary-foreground px-2 py-1 rounded">
                  Admin
                </span>
              {/if}
            </div>
          {/each}
        </Card.Content>
      </Card.Root>

      <!-- Start Game Button (Admin only) -->
      {#if isAdmin}
        <Button
          variant="default"
          size="lg"
          class="w-full"
          on:click={startGame}
        >
          Start Game
        </Button>
      {/if}

      <!-- Error Message -->
      {#if error}
        <div class="p-3 text-sm text-destructive bg-destructive/10 rounded-md">
          {error}
        </div>
      {/if}

      <!-- Leave Room Button -->
      <Button
        variant="destructive"
        size="lg"
        class="w-full"
        on:click={leaveRoom}
      >
        Leave Room
      </Button>
    {/if}
  </div>
</div>
