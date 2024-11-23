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
  
  <div class="container mx-auto p-4">
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

<style>
img {
    max-width: 100%;
    height: auto;
}
    
.text-white {
    --tw-text-opacity: 1;
    color: rgb(255 255 255 / var(--tw-text-opacity, 1));
}

.py-2 {
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
}

.px-4 {
    padding-left: 1rem;
    padding-right: 1rem;
}

.bg-blue-500 {
    --tw-bg-opacity: 1;
    background-color: rgb(59 130 246 / var(--tw-bg-opacity, 1));
}

.rounded {
    border-radius: var(--radius - 4px);
}

.mt-4 {
    margin-top: 1rem;
}
</style>