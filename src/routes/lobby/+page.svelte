<script>
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { goto } from '$app/navigation';
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';
  import { Separator } from '$lib/components/ui/separator';
  import { Copy } from 'lucide-svelte';
  import { browser } from '$app/environment';
  import * as Dialog from "$lib/components/ui/dialog";
  import { Badge } from "$lib/components/ui/badge";
  import { Users, Crown } from 'lucide-svelte';
  import { gameModes } from '$lib/config/gameModes.ts';

  let players = [];
  let roomData = null;
  let isReady = false;
  let error = '';
  let isLoading = false;
  let userId = browser ? localStorage.getItem('userId') : null;
  let roomId = browser ? localStorage.getItem('roomId') : null;
  let roomCode = browser ? localStorage.getItem('currentRoomCode') : null;
  let updateInterval;
  let showLeaveConfirm = false;

  // Enhanced subscription with multiple channels
  const playersSubscription = supabase
    .channel('lobby_channel')
    .on('postgres_changes', { 
      event: '*', 
      schema: 'public', 
      table: 'players',
      filter: `room_id=eq.${roomId}`
    }, handlePlayerChange)
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'rooms',
      filter: `id=eq.${roomId}`
    }, handleRoomChange)
    .subscribe();

  // Add reactive statement for player state
  $: {
    if (players.length > 0) {
      const currentPlayer = players.find(p => p.user_id === userId);
      if (currentPlayer) {
        isReady = currentPlayer.is_ready;
      }
    }
  }

  onMount(async () => {
    if (!userId || !roomId) {
      goto('/');
      return;
    }
    
    window.addEventListener('beforeunload', handlePlayerLeave);
    
    await Promise.all([
      loadRoom(),
      loadPlayers()
    ]);
    setupPresence();
    
    // Check initial ready state
    const currentPlayer = players.find(p => p.user_id === userId);
    if (currentPlayer) {
      isReady = currentPlayer.is_ready;
    }

    // More frequent updates for player states
    updateInterval = setInterval(async () => {
      await Promise.all([
        loadPlayers(),
        loadRoom(),
        checkAllPlayersReady()
      ]);
    }, 1500); // Update every 1.5 seconds for smoother experience

    // Always set dark mode
    document.documentElement.classList.add('dark');
    document.body.style.backgroundColor = '#020202';
  });

  async function handlePlayerChange() {
    await loadPlayers();
    await checkAllPlayersReady();
  }

  async function handleRoomChange() {
    await loadRoom();
    if (roomData?.status === 'in_game' && roomData?.game_session_id) {
      // Store game session ID before redirecting
      localStorage.setItem('gameSessionId', roomData.game_session_id);
      goto('/game-room');
    }
  }

  async function loadRoom() {
    const { data, error: roomError } = await supabase
      .from('rooms')
      .select('*')
      .eq('id', roomId)
      .single();

    if (roomError) {
      console.error('Error loading room:', roomError);
      return;
    }

    roomData = data;
    console.log('Loaded room data:', roomData);
    console.log('Game mode:', roomData?.game_mode);
    console.log('Available modes:', Object.keys(gameModes));
  }

  async function loadPlayers() {
    const { data, error: playersError } = await supabase
      .from('players')
      .select('*')
      .eq('room_id', roomId)
      .order('created_at');

    if (playersError) {
      console.error('Error loading players:', playersError);
      return;
    }

    players = data;
  }

  async function checkAllPlayersReady() {
    if (!players.length || players.length < 2) {
      return false;
    }
    
    const allReady = players.every(p => p.is_ready);
    const readyCount = players.filter(p => p.is_ready).length;
    
    // Update UI with ready count
    const totalPlayers = players.length;
    const readyStatus = `${readyCount}/${totalPlayers} players ready`;
    
    // If all players are ready, admin initiates game start
    if (allReady && roomData?.admin_id === userId) {
      await startGame();
    }
    
    return allReady;
  }

  async function toggleReady() {
    try {
      isLoading = true;
      isReady = !isReady;
      
      const { error: updateError } = await supabase
        .from('players')
        .update({ is_ready: isReady })
        .eq('user_id', userId)
        .eq('room_id', roomId);

      if (updateError) throw updateError;

    } catch (err) {
      console.error('Error toggling ready state:', err);
      error = 'Failed to update ready state';
      isReady = !isReady; // Revert the state
    } finally {
      isLoading = false;
    }
  }

  function generateCardSequence(gameMode) {
    const count = gameModes[gameMode]?.cardCount || 20;
    const sequence = Array.from({length: count}, (_, i) => i + 1);
    
    // Fisher-Yates shuffle
    for (let i = sequence.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [sequence[i], sequence[j]] = [sequence[j], sequence[i]];
    }
    
    return sequence;
  }

  async function startGame() {
    try {
      isLoading = true;
      error = '';

      // Generate card sequence
      const sequence = generateCardSequence(roomData.game_mode);
      
      // Create game session with initial state (removed timestamp fields)
      const { data: gameSession, error: sessionError } = await supabase
        .from('game_sessions')
        .insert({
          room_id: roomId,
          card_sequence: sequence,
          current_player_index: 0,
          current_card_index: 0,
          is_active: true,
          last_update: new Date().toISOString()
        })
        .select()
        .single();

      if (sessionError) throw sessionError;

      // Update room status
      const { error: roomError } = await supabase
        .from('rooms')
        .update({ 
          game_session_id: gameSession.id,
          status: 'in_game'
        })
        .eq('id', roomId);

      if (roomError) throw roomError;

      // Store game session ID
      localStorage.setItem('gameSessionId', gameSession.id);

    } catch (err) {
      console.error('Error starting game:', err);
      error = 'Failed to start game. Please try again.';
    } finally {
      isLoading = false;
    }
  }

  function setupPresence() {
    // Your existing presence code
  }

  async function handlePlayerLeave() {
    try {
      // If admin is leaving, transfer admin rights
      if (userId === roomData?.admin_id && players.length > 1) {
        const nextAdmin = players.find(p => p.user_id !== userId);
        if (nextAdmin) {
          const { error: adminError } = await supabase
            .from('rooms')
            .update({ admin_id: nextAdmin.user_id })
            .eq('id', roomId);
          
          if (adminError) throw adminError;
        }
      }

      // Remove player from room
      const { error: leaveError } = await supabase
        .from('players')
        .delete()
        .eq('user_id', userId)
        .eq('room_id', roomId);

      if (leaveError) throw leaveError;

      // Check remaining players
      const { data: remainingPlayers, error: countError } = await supabase
        .from('players')
        .select('user_id')
        .eq('room_id', roomId);

      if (countError) throw countError;

      // If no players left, delete the room
      if (!remainingPlayers || remainingPlayers.length === 0) {
        const { error: deleteError } = await supabase
          .from('rooms')
          .delete()
          .eq('id', roomId);

        if (deleteError) throw deleteError;
        console.log('Room deleted - no players remaining');
      }

      // Clear local storage
      localStorage.removeItem('roomId');
      localStorage.removeItem('currentRoomCode');
      localStorage.removeItem('gameSessionId');

    } catch (err) {
      console.error('Error handling player leave:', err);
    }
  }

  onDestroy(() => {
    handlePlayerLeave();
    window.removeEventListener('beforeunload', handlePlayerLeave);
    if (playersSubscription) {
      playersSubscription.unsubscribe();
    }
    if (updateInterval) {
      clearInterval(updateInterval);
    }
  });

  async function copyRoomCode() {
    try {
      await navigator.clipboard.writeText(roomCode);
      const originalError = error;
      error = '✨ Room code copied to clipboard!';
      setTimeout(() => {
        error = originalError;
      }, 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
      error = 'Failed to copy room code';
    }
  }

  async function handleLeaveRoom() {
    try {
      isLoading = true;
      
      // If admin is leaving, transfer admin rights
      if (userId === roomData?.admin_id && players.length > 1) {
        const nextAdmin = players.find(p => p.user_id !== userId);
        if (nextAdmin) {
          const { error: adminError } = await supabase
            .from('rooms')
            .update({ admin_id: nextAdmin.user_id })
            .eq('id', roomId);
          
          if (adminError) throw adminError;
        }
      }

      const { error: leaveError } = await supabase
        .from('players')
        .delete()
        .eq('user_id', userId)
        .eq('room_id', roomId);
      
      if (leaveError) throw leaveError;
      
      localStorage.removeItem('roomId');
      localStorage.removeItem('currentRoomCode');
      goto('/');
    } catch (err) {
      console.error('Error leaving room:', err);
      error = 'Failed to leave room. Please try again.';
    } finally {
      isLoading = false;
      showLeaveConfirm = false;
    }
  }
</script>

<div class="relative min-h-screen w-full bg-background flex items-center justify-center p-4">
  <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
    <Card.Header class="space-y-4">
      <Card.Title class="text-3xl font-bold text-center text-card-foreground">
        Lobby
      </Card.Title>
      
      <!-- Room Info -->
      <div class="flex flex-col items-center gap-2">
        <h2 class="text-xl font-semibold text-foreground">
          {roomData?.room_name || 'Loading...'}
        </h2>
        
        <Badge variant="outline" class="px-4 py-1.5 text-lg bg-background/50">
          Room Code: {roomCode}
          <Button
            variant="ghost"
            size="icon"
            class="h-6 w-6 ml-2 hover:text-primary"
            on:click={copyRoomCode}
          >
            <Copy class="h-4 w-4" />
            <span class="sr-only">Copy room code</span>
          </Button>
        </Badge>
      </div>
    </Card.Header>

    <Card.Content class="space-y-6">
      <!-- Enhanced Game Mode Badge and Description -->
      <div class="text-center space-y-3">
        {#if roomData?.game_mode && gameModes[roomData.game_mode]}
          <Badge 
            variant="secondary" 
            class="text-base px-4 py-1.5"
          >
            {gameModes[roomData.game_mode].name}
          </Badge>
          
          <!-- Game Mode Description -->
          <p class="text-sm text-muted-foreground">
            {gameModes[roomData.game_mode].description}
          </p>
          <p class="text-xs text-muted-foreground">
            {gameModes[roomData.game_mode].cardCount} cards in deck
          </p>
        {:else}
          <Badge variant="secondary" class="text-base px-4 py-1.5">
            Loading game mode...
          </Badge>
        {/if}
      </div>

      <Separator />

      <!-- Player List Header -->
      <div class="flex items-center gap-2 text-muted-foreground">
        <Users class="h-5 w-5" />
        <span>Players ({players.length})</span>
      </div>

      <!-- Enhanced Player List -->
      <div class="space-y-2 max-h-[200px] overflow-y-auto pr-2">
        {#each players as player}
          <div class="flex items-center justify-between p-3 rounded-lg transition-all duration-200 
                    {player.user_id === userId 
                      ? 'bg-primary/20 border border-primary/30' 
                      : 'bg-accent hover:bg-accent/80'}">
            <div class="flex items-center gap-3">
              {#if player.user_id === roomData?.admin_id}
                <Crown class="h-4 w-4 text-yellow-500" />
              {/if}
              <span class={player.user_id === userId ? 'font-semibold' : ''}>
                {player.username}
                {#if player.user_id === userId}
                  <span class="text-xs text-muted-foreground">(You)</span>
                {/if}
              </span>
            </div>
            <Badge 
              variant={player.is_ready ? "success" : "secondary"} 
              class="text-xs animate-in fade-in-50 duration-300"
            >
              {player.is_ready ? '✓ Ready' : '⋯ Waiting'}
            </Badge>
          </div>
        {/each}
      </div>

      <!-- Error Display -->
      {#if error}
        <div class="p-3 text-sm rounded-md animate-in fade-in-50 {error.includes('copied') 
          ? 'text-primary bg-primary/10' 
          : 'text-destructive bg-destructive/10'
        }">
          {error}
        </div>
      {/if}
    </Card.Content>

    <Card.Footer class="flex flex-col gap-2">
      <Button
        variant="default"
        size="lg"
        class="w-full {isReady ? 'bg-primary hover:bg-primary/90' : ''}"
        disabled={isLoading}
        on:click={toggleReady}
      >
        {#if isLoading}
          <span class="animate-pulse">Loading...</span>
        {:else if isReady && players.every(p => p.is_ready)}
          <span class="animate-pulse">Starting Game...</span>
        {:else if isReady}
          ✓ Ready - Waiting for others...
        {:else}
          Ready Up
        {/if}
      </Button>

      <Button
        variant="outline"
        size="lg"
        class="w-full hover:bg-destructive hover:text-destructive-foreground"
        disabled={isLoading}
        on:click={() => showLeaveConfirm = true}
      >
        Leave Room
      </Button>
    </Card.Footer>
  </Card.Root>
</div>

<!-- Leave Confirmation Dialog -->
<Dialog.Root bind:open={showLeaveConfirm}>
  <Dialog.Content class="bg-background border-border">
    <Dialog.Header>
      <Dialog.Title class="text-foreground">Leave Room</Dialog.Title>
      <Dialog.Description class="text-muted-foreground">
        Are you sure you want to leave this room? 
        {#if userId === roomData?.admin_id && players.length > 1}
          Admin rights will be transferred to another player.
        {/if}
      </Dialog.Description>
    </Dialog.Header>
    <Dialog.Footer class="flex gap-2">
      <Button variant="outline" on:click={() => showLeaveConfirm = false}>
        Cancel
      </Button>
      <Button variant="destructive" on:click={handleLeaveRoom} disabled={isLoading}>
        {isLoading ? 'Leaving...' : 'Leave Room'}
      </Button>
    </Dialog.Footer>
  </Dialog.Content>
</Dialog.Root>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow-x: hidden;
    background-color: hsl(var(--background));
    color: hsl(var(--foreground));
  }

  :global(.card) {
    background-color: hsl(var(--card));
    color: hsl(var(--card-foreground));
    border: 1px solid hsl(var(--border));
    animation: fadeIn 0.5s ease-out;
  }

  /* Scrollbar styles */
  div::-webkit-scrollbar {
    width: 6px;
  }

  div::-webkit-scrollbar-track {
    background: transparent;
  }

  div::-webkit-scrollbar-thumb {
    background-color: hsl(var(--primary) / 0.2);
    border-radius: 20px;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>
