<script>
    import { onMount, onDestroy } from 'svelte';
    import { supabase } from '$lib/supabaseClient';
    import { browser } from '$app/environment';
    import { goto } from '$app/navigation';
  
    let gameSession = null;
    let players = [];
    let currentCard = null;
    let isLoading = false;
    let error = '';
    let userId = browser ? localStorage.getItem('userId') : null;
    let gameSessionId = browser ? localStorage.getItem('gameSessionId') : null;
    let roomId = browser ? localStorage.getItem('roomId') : null;
  
    // Subscribe to game session changes
    const gameSubscription = supabase
      .channel('game_room')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'game_sessions',
        filter: `id=eq.${gameSessionId}`
      }, handleGameChange)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'players',
        filter: `room_id=eq.${roomId}`
      }, handlePlayerChange)
      .subscribe();
  
    onMount(async () => {
      if (!gameSessionId || !userId) {
        goto('/');
        return;
      }
      await Promise.all([
        loadGameSession(),
        loadPlayers()
      ]);
    });
  
    async function handleGameChange() {
      await loadGameSession();
      // Update UI based on game state
      if (gameSession?.current_card) {
        currentCard = gameSession.current_card;
      }
    }
  
    async function handlePlayerChange() {
      await loadPlayers();
    }
  
    async function loadGameSession() {
      const { data, error: sessionError } = await supabase
        .from('game_sessions')
        .select('*')
        .eq('id', gameSessionId)
        .single();
  
      if (sessionError) {
        console.error('Error loading game session:', sessionError);
        return;
      }
  
      gameSession = data;
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
  
    async function drawCard() {
      if (!gameSession || isLoading) return;
  
      try {
        isLoading = true;
        error = '';
  
        // Check if it's the player's turn
        if (players[gameSession.current_player_index]?.user_id !== userId) {
          error = "It's not your turn!";
          return;
        }
  
        const nextCardIndex = gameSession.current_card_index + 1;
        const nextPlayerIndex = (gameSession.current_player_index + 1) % players.length;
        const currentCard = gameSession.card_sequence[gameSession.current_card_index];
  
        const { error: updateError } = await supabase
          .from('game_sessions')
          .update({
            current_card_index: nextCardIndex,
            current_player_index: nextPlayerIndex,
            current_card: currentCard
          })
          .eq('id', gameSessionId);
  
        if (updateError) throw updateError;
  
      } catch (err) {
        console.error('Error drawing card:', err);
        error = 'Failed to draw card. Please try again.';
      } finally {
        isLoading = false;
      }
    }
  
    onDestroy(() => {
      if (gameSubscription) {
        gameSubscription.unsubscribe();
      }
    });
  </script>
  
  <div class="relative min-h-screen w-full bg-background">
    <!-- Animated Background -->
    <div class="absolute inset-0 w-full h-full">
      <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
        <defs>
          <radialGradient id="Gradient2" cx="50%" cy="50%" fx="10%" fy="50%" r=".5">
            <animate attributeName="fx" dur="23.5s" values="0%;3%;0%" repeatCount="indefinite" />
            <stop offset="0%" stop-color="hsl(300 100% 50%)" />
            <stop offset="100%" stop-color="hsl(300 100% 50% / 0)" />
          </radialGradient>
          <radialGradient id="Gradient3" cx="50%" cy="50%" fx="50%" fy="50%" r=".5">
            <animate attributeName="fx" dur="21.5s" values="0%;3%;0%" repeatCount="indefinite" />
            <stop offset="0%" stop-color="hsl(180 100% 50%)" />
            <stop offset="100%" stop-color="hsl(180 100% 50% / 0)" />
          </radialGradient>
          <radialGradient id="Gradient1" cx="50%" cy="50%" fx="10%" fy="50%" r=".5">
            <animate attributeName="fx" dur="34s" values="0%;3%;0%" repeatCount="indefinite" />
            <stop offset="0%" stop-color="hsl(60 100% 50%)" />
            <stop offset="100%" stop-color="hsl(60 100% 50% / 0)" />
          </radialGradient>
        </defs>
        <rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient3)">
          <animate attributeName="x" dur="25s" values="0%;25%;0%" repeatCount="indefinite" />
          <animate attributeName="y" dur="26s" values="0%;25%;0%" repeatCount="indefinite" />
          <animateTransform attributeName="transform" type="rotate" from="360 50 50" to="0 50 50" dur="19s" repeatCount="indefinite" />
        </rect>
        <rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient1)">
          <animate attributeName="x" dur="20s" values="25%;0%;25%" repeatCount="indefinite" />
          <animate attributeName="y" dur="21s" values="0%;25%;0%" repeatCount="indefinite" />
          <animateTransform attributeName="transform" type="rotate" from="0 50 50" to="360 50 50" dur="17s" repeatCount="indefinite" />
        </rect>
        <rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient2)">
          <animate attributeName="x" dur="23s" values="-25%;0%;-25%" repeatCount="indefinite" />
          <animate attributeName="y" dur="24s" values="0%;50%;0%" repeatCount="indefinite" />
          <animateTransform attributeName="transform" type="rotate" from="0 50 50" to="360 50 50" dur="18s" repeatCount="indefinite" />
        </rect>
      </svg>
    </div>
  
    <!-- Content -->
    <div class="relative z-10 container mx-auto p-4">
      <div class="bg-card/95 backdrop-blur-lg rounded-lg p-6 shadow-xl">
        <h1 class="text-3xl font-bold mb-4 text-center">Game Room</h1>
        
        <!-- Show current player -->
        <div class="text-center mb-4">
          <p class="text-xl">
            Current Player: {players[gameSession?.current_player_index]?.username || 'Loading...'}
            {#if players[gameSession?.current_player_index]?.user_id === userId}
              (Your Turn!)
            {/if}
          </p>
        </div>
      
        <!-- Show error if any -->
        {#if error}
          <div class="text-red-500 text-center mb-4">{error}</div>
        {/if}
      
        <!-- Card display -->
        <div class="flex justify-center mb-4">
          {#if currentCard}
            <div class="text-center">
              <h2 class="text-2xl mb-4">Question:</h2>
              <p class="text-xl bg-card p-4 rounded-lg">{currentCard}</p>
            </div>
          {:else}
            <button 
              on:click={drawCard} 
              disabled={isLoading || players[gameSession?.current_player_index]?.user_id !== userId}
              class="relative w-64 h-96 bg-card rounded-lg shadow-md overflow-hidden 
                     focus:outline-none focus:ring-2 focus:ring-primary focus:ring-opacity-50 
                     transition-transform transform hover:scale-105
                     disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <div class="absolute inset-0 flex items-center justify-center">
                {#if isLoading}
                  <span class="animate-pulse">Drawing...</span>
                {:else if players[gameSession?.current_player_index]?.user_id !== userId}
                  <span>Waiting for {players[gameSession?.current_player_index]?.username}'s turn...</span>
                {:else}
                  <span>Click to Draw</span>
                {/if}
              </div>
            </button>
          {/if}
        </div>
      
        <!-- Player list -->
        <div class="max-w-md mx-auto">
          <h2 class="text-xl font-semibold mb-2">Players:</h2>
          <div class="space-y-2">
            {#each players as player}
              <div class="flex items-center justify-between p-2 bg-card/50 rounded-lg">
                <span>{player.username} {player.user_id === userId ? '(You)' : ''}</span>
                {#if player.user_id === players[gameSession?.current_player_index]?.user_id}
                  <span class="text-primary">Current Turn</span>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      </div>
    </div>
  </div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow-x: hidden;
    background-color: hsl(var(--background));
    color: hsl(var(--foreground));
  }

  svg {
    height: 100%;
    width: 100%;
    mix-blend-mode: screen;
    opacity: 0.7;
  }

  :global(.card) {
    background-color: hsl(var(--card));
    color: hsl(var(--card-foreground));
    border: 1px solid hsl(var(--border));
    animation: fadeIn 0.5s ease-out;
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