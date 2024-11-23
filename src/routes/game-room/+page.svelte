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
    let isSubscribed = false;
  
    // Enhanced subscription with real-time updates
    const gameSubscription = supabase
      .channel(`game_room_${gameSessionId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'game_sessions',
        filter: `id=eq.${gameSessionId}`
      }, async (payload) => {
        if (payload.new && payload.new.id === gameSessionId) {
          console.log('Game session updated:', payload);
          await handleGameChange(payload);
        }
      })
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'players',
        filter: `room_id=eq.${roomId}`
      }, async (payload) => {
        console.log('Players updated:', payload);
        await handlePlayerChange(payload);
      })
      .subscribe();
  
    onMount(async () => {
      if (!gameSessionId || !userId) {
        goto('/');
        return;
      }
  
      if (!isSubscribed) {
        await gameSubscription.subscribe();
        isSubscribed = true;
      }
  
      await Promise.all([
        loadGameSession(),
        loadPlayers()
      ]);
  
      window.addEventListener('beforeunload', handlePlayerLeave);
    });
  
    async function handleGameChange(payload) {
      if (gameSession?.current_card_index === payload.new.current_card_index &&
          gameSession?.current_player_index === payload.new.current_player_index) {
        return;
      }
  
      gameSession = payload.new;
      
      if (payload.new.current_card) {
        currentCard = payload.new.current_card;
      }
      
      // Update turn information
      const currentPlayer = players[payload.new.current_player_index];
      if (currentPlayer) {
        error = currentPlayer.user_id === userId 
          ? "It's your turn!" 
          : `Waiting for ${currentPlayer.username}'s turn...`;
      }
    }
  
    async function handlePlayerChange() {
      const { data, error: playersError } = await supabase
        .from('players')
        .select('*')
        .eq('room_id', roomId)
        .order('created_at');
  
      if (!playersError && data) {
        players = data;
      }
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
  
        // Verify it's the player's turn
        if (players[gameSession.current_player_index]?.user_id !== userId) {
          error = "It's not your turn!";
          return;
        }
  
        const nextCardIndex = gameSession.current_card_index + 1;
        const nextPlayerIndex = (gameSession.current_player_index + 1) % players.length;
        const drawnCard = gameSession.card_sequence[gameSession.current_card_index];
  
        // Update game session with new state
        const { error: updateError } = await supabase
          .from('game_sessions')
          .update({
            current_card_index: nextCardIndex,
            current_player_index: nextPlayerIndex,
            current_card: drawnCard
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
  
    async function handlePlayerLeave() {
      try {
        // If game is active, update player sequence
        if (gameSession?.is_active) {
          const currentPlayerIndex = gameSession.current_player_index;
          const leavingPlayerIndex = players.findIndex(p => p.user_id === userId);
          
          // Calculate new player index if the leaving player was in the sequence
          let newPlayerIndex = currentPlayerIndex;
          if (leavingPlayerIndex <= currentPlayerIndex) {
            newPlayerIndex = Math.max(0, (currentPlayerIndex - 1) % (players.length - 1));
          }

          // Update game session
          const { error: sessionError } = await supabase
            .from('game_sessions')
            .update({
              current_player_index: newPlayerIndex
            })
            .eq('id', gameSessionId);

          if (sessionError) throw sessionError;
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

        // If no players left, delete the room and associated game session
        if (!remainingPlayers || remainingPlayers.length === 0) {
          // Delete game session first (due to foreign key constraint)
          if (gameSessionId) {
            const { error: sessionDeleteError } = await supabase
              .from('game_sessions')
              .delete()
              .eq('id', gameSessionId);

            if (sessionDeleteError) throw sessionDeleteError;
          }

          // Then delete the room
          const { error: deleteError } = await supabase
            .from('rooms')
            .delete()
            .eq('id', roomId);

          if (deleteError) throw deleteError;
          console.log('Room and game session deleted - no players remaining');
        }

        // Clear local storage
        localStorage.removeItem('roomId');
        localStorage.removeItem('currentRoomCode');
        localStorage.removeItem('gameSessionId');

      } catch (err) {
        console.error('Error handling player leave:', err);
      }
    }
  
    // Handle tab close or navigation
    onMount(() => {
      window.addEventListener('beforeunload', handlePlayerLeave);
    });
  
    onDestroy(() => {
      if (isSubscribed) {
        gameSubscription.unsubscribe();
        isSubscribed = false;
      }
      handlePlayerLeave();
      window.removeEventListener('beforeunload', handlePlayerLeave);
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
        <div class="flex justify-center mb-8">
          {#if currentCard}
            <div class="text-center w-full max-w-2xl mx-auto">
              <div class="bg-card/95 backdrop-blur-lg p-6 rounded-lg shadow-xl animate-in fade-in slide-in-from-bottom duration-300">
                <h2 class="text-2xl mb-4 font-bold">Question:</h2>
                <p class="text-xl p-4 rounded-lg bg-background/50">{currentCard}</p>
              </div>
            </div>
          {:else}
            <button 
              on:click={drawCard} 
              disabled={isLoading || players[gameSession?.current_player_index]?.user_id !== userId}
              class="relative w-64 h-96 bg-card rounded-lg shadow-md overflow-hidden 
                     focus:outline-none focus:ring-2 focus:ring-primary focus:ring-opacity-50 
                     transition-all transform hover:scale-105
                     disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <div class="absolute inset-0 flex items-center justify-center p-4 text-center">
                {#if isLoading}
                  <span class="animate-pulse">Drawing card...</span>
                {:else if players[gameSession?.current_player_index]?.user_id !== userId}
                  <span>Waiting for {players[gameSession?.current_player_index]?.username}'s turn...</span>
                {:else}
                  <span class="text-lg font-medium">Your Turn!<br>Click to Draw</span>
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