<script>
// @ts-nocheck

  import '../../styles/lobby.css';
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
  import { Label } from "$lib/components/ui/label";
  import { slide } from 'svelte/transition';
  import { writable, derived } from 'svelte/store';



  let hasCurrentCard = null;
  let players = [];
  let totalCards = 5;
  let roomData = null;
  let isReady = false;
  let error = '';
  let isLoading = false;
  let readyStatus = '';
  let isTurnActive = false;
  let currentQuestion = '';
  let userId = browser ? localStorage.getItem('userId') : null;
  let roomId = browser ? localStorage.getItem('roomId') : null;
  let roomCode = browser ? localStorage.getItem('currentRoomCode') : null;
  let updateInterval;
  let showLeaveConfirm = false;
  let showPlayerWarningDialog = false;
  let gameStarted = false;
  let currentCard = null;
  let isMyTurn = false;
  let currentPlayerIndex = 0;
  let gameSession = null;
  let isCardRevealed = false;
  let selectedGameMode = '';
  let currentCardCount = 0;
  let currentGameMode = writable(null);
  let currentGameModeData = derived(currentGameMode, $mode => gameModes[$mode] || null);
  let currentGameState = writable({
    deckName: '',
    currentCardIndex: 0,
    totalCards: 0,
    isDrawPhase: false
  });

  onMount(async () => {
    console.log('Component mounted');
    if (!browser) return;
    
    // Check for required data
    if (!userId || !roomId) {
      console.error('Missing required data:', { userId, roomId });
      error = 'Session expired. Please rejoin the room.';
      goto('/');
      return;
    }

    try {
      console.log('Loading initial data...');
      window.addEventListener('beforeunload', handlePlayerLeave);
      
      // Load room first to get game mode
      await loadRoom();
      
      if (!roomData) {
        throw new Error('Room not found');
      }

      // Then load players and game session
      await Promise.all([
        loadPlayers(),
        loadGameSession()
      ]);

      // Check if there's an active game session
      if (roomData.status === 'playing') {
        await startGameForAllUsers();
      }

      // Initialize subscriptions after data is loaded
      setupSubscriptions();
      setupPresence();
      
      // Start periodic updates
      updateInterval = setInterval(async () => {
        await updatePlayerStatus();
        await updateGameModeStatus();
      }, 3000);

      console.log('Initial data loaded successfully');
    } catch (err) {
      console.error('Error initializing lobby:', err);
      error = 'Failed to initialize lobby';
      goto('/');
    }
  });

  async function handlePlayerChange() {
    await loadPlayers();
    await checkAllPlayersReady();
  }


  async function loadRoom() {
    try {
      const { data, error: roomError } = await supabase
        .from('rooms')
        .select('*')
        .eq('id', roomId)
        .single();

      if (roomError) {
        console.error('Error loading room:', roomError);
        throw roomError;
      }

      roomData = data;
      if (roomData) {
        selectedGameMode = roomData.game_mode;
        currentGameMode.set(roomData.game_mode);
        console.log('Loaded room data:', roomData);
        console.log('Game mode:', roomData.game_mode);

        await updateCardCount(roomData.game_mode);
      } else {
        console.error('Room data is null');
      }

      return data;
    } catch (err) {
      console.error('Failed to load room:', err);
      return null;
    }
  }

  async function handleDrawCard() {
    // Check if it's the current player's turn
    if (players[currentPlayerIndex].user_id !== userId) {
        console.log("It's not your turn!");
        return;
    }

    // Simulate drawing a card (fetching a question)
    const { data: questionData, error } = await supabase
        .from('questions')
        .select('*')
        .order('random()') // Randomly select a question
        .limit(1)
        .single();

    if (error) {
        console.error('Error fetching question:', error);
        return;
    }

    currentQuestion = questionData.question; // Assuming questionData has a 'question' field
    drawnCardsCount++; // Increment the drawn cards count

    // Sync the drawn question to all players
    await syncQuestionToPlayers(currentQuestion);

    // Check if it's the last card
    if (drawnCardsCount >= totalCards) {
        await endGameSession();
    }
  }

  async function syncQuestionToPlayers(question) {
    try {
        // Notify all players about the drawn question
        supabase
            .channel(`question_${roomId}`)
            .send('question_drawn', { question });

        console.log(`Question synced to all players: ${question}`);
    } catch (err) {
        console.error('Error syncing question:', err);
    }
  }

  // Function to end the game session and return players to the lobby
  async function endGameSession() {
      try {
          // Notify players that the game is ending and they will return to the lobby
          supabase
              .channel(`game_${roomId}`)
              .send('game_ended', { message: "The game has ended. Returning to lobby." });

          // Optionally, you can implement logic to handle player state change to lobby
          // Reset player states or update the database accordingly

          // Delete the game session from the database
          const { error: deleteError } = await supabase
              .from('games')
              .delete()
              .eq('id', roomId);

          if (deleteError) {
              console.error('Error deleting game session:', deleteError);
              return;
          }

          console.log('Game session deleted successfully. Players returned to lobby.');
      } catch (err) {
          console.error('Error ending game session:', err);
      }
  }

  function endTurn() {
      if (!isTurnActive) {
          console.log("No active turn to end.");
          return;
      }

      // Pass the turn to the next player
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      isTurnActive = false; // Reset the turn active flag

      console.log(`Turn passed to player: ${players[currentPlayerIndex].user_id}`);

      // Optionally, you can notify all players about the turn change
      syncTurnChange(players[currentPlayerIndex].user_id);
  }

  // Function to sync the turn change to all players
  async function syncTurnChange(nextPlayerId) {
      try {
          // Notify all players about the turn change
          supabase
              .channel(`turn_${roomId}`)
              .send('turn_changed', { nextPlayerId });

          console.log(`Turn change synced to all players: Next player is ${nextPlayerId}`);
      } catch (err) {
          console.error('Error syncing turn change:', err);
      }
  }

  async function updateCardCount(gameMode) {
    try {
      const { count, error } = await supabase
        .from('game_cards')
        .select('*', { count: 'exact', head: true })
        .eq('game_mode', gameMode);

      if (error) throw error;
      currentCardCount = count;
    } catch (err) {
      console.error('Error fetching card count:', err);
    }
  }

  async function loadPlayers() {
    try {
      const { data, error: playersError } = await supabase
        .from('players')
        .select('*')
        .eq('room_id', roomId)
        .order('created_at');

      if (playersError) throw playersError;

      players = data;
      await updatePlayerStatus(); // Update status after loading players
    } catch (err) {
      console.error('Error loading players:', err);
    }
  }

  async function checkAndDeleteLobby() {
    try {
        // Load the current players in the room
        const { data: currentPlayers, error } = await supabase
            .from('players')
            .select('*')
            .eq('room_id', roomId);

        if (error) throw error;

        // Check if there are no players left
        if (currentPlayers.length === 0) {
            // Delete the lobby from the rooms table
            const { error: deleteError } = await supabase
                .from('rooms')
                .delete()
                .eq('id', roomId);

            if (deleteError) {
                console.error('Error deleting lobby:', deleteError);
                return;
            }

            console.log('Lobby deleted successfully');
            // Optionally navigate to another page or show a message
            goto('/');
        }
    } catch (err) {
        console.error('Error checking and deleting lobby:', err);
    }
  }

  async function handlePlayerLeaveDuringGame() {
    try {
        if (!userId || !roomId) return;

        // Remove player from the game session
        const { error: leaveError } = await supabase
            .from('players')
            .delete()
            .eq('user_id', userId)
            .eq('room_id', roomId);

        if (leaveError) throw leaveError;

        console.log(`Player ${userId} has left the game session`);

        // Notify other players about the player leaving
        await syncPlayerLeave(userId);

        // Optionally, you can call a function to check if the lobby should be deleted
        await checkAndDeleteLobby(); // Check if the lobby should be deleted

    } catch (err) {
        console.error('Error handling player leave during game:', err);
    }
}

  // Function to sync player leave to all players
  async function syncPlayerLeave(playerId) {
      try {
          // Load the current players in the room after a player leaves
          const { data: updatedPlayers, error } = await supabase
              .from('players')
              .select('*')
              .eq('room_id', roomId);

          if (error) throw error;

          // Update the local state with the updated players list
          players = updatedPlayers;

          // Notify all players about the player leaving
          // This can be done using your existing real-time subscription setup
          // For example, you can use a channel to broadcast the player leaving
          supabase
              .channel(`player_${roomId}`)
              .send('player_left', { playerId });

          console.log(`Player ${playerId} has been synced to all players`);

      } catch (err) {
          console.error('Error syncing player leave:', err);
      }
  }

  async function checkAllPlayersReady() {
    console.log('🔍 Checking all players ready status...');
    try {
      // Get fresh room data
      const { data: currentRoom } = await supabase
        .from('rooms')
        .select('status, game_session_id')
        .eq('id', roomId)
        .single();

      // Don't proceed if game is already in progress or starting
      if (currentRoom?.status === 'playing' || currentRoom?.status === 'starting' || gameStarted) {
        console.log('⚠️ Game already in progress or starting, status:', currentRoom?.status);
        handleGameStart();
        // return false;
      }

      // Get fresh player data
      const { data: readyPlayers, error: playersError } = await supabase
        .from('players')
        .select('*')
        .eq('room_id', roomId)
        .eq('is_ready', true);

      if (playersError) throw playersError;

      // Ensure minimum player count
      if (!readyPlayers?.length || readyPlayers.length < 2) {
        console.log('❌ Not enough ready players:', readyPlayers?.length);
        return false;
      }

      // Only admin can start the game when all conditions are met
      if (currentRoom?.status === 'waiting') {
        console.log('✨ All conditions met for game start!');
        
        // Set room status to 'starting'
        const { error: startingError } = await supabase
          .from('rooms')
          .update({ status: 'starting' })
          .eq('id', roomId);

        if (startingError) throw startingError;

        return await handleGameStart();
      }

      return false;
    } catch (err) {
      console.error('💥 Error in checkAllPlayersReady:', err);
      return false;
    }
  }

  async function toggleReady() {
    try {
      if (players.length < 2) {
        showPlayerWarningDialog = true;
        return;
      }

      // If admin and game mode not finalized, show warning
      if (userId === roomData?.admin_id && selectedGameMode !== roomData?.game_mode) {
        error = 'Please finalize the game mode before marking ready.';
        return;
      }

      isLoading = true;
      const newReadyState = !isReady;
      
      // First update local state
      isReady = newReadyState;
      
      // Then update database
      const { error: updateError } = await supabase
        .from('players')
        .update({ is_ready: newReadyState })
        .eq('user_id', userId)
        .eq('room_id', roomId);

      if (updateError) {
        // Revert local state if update fails
        isReady = !newReadyState;
        throw updateError;
      }
      
      // Update status after successful toggle
      await updatePlayerStatus();

    } catch (err) {
      console.error('Error toggling ready state:', err);
      error = 'Failed to update ready state';
    } finally {
      isLoading = false;
    }
  }
  function setupPresence() {
    const presenceChannel = supabase.channel(`presence_${roomId}`, {
      config: {
        presence: {
          key: userId,
        },
      },
    });

    presenceChannel
      .on('presence', { event: 'sync' }, () => {
        const state = presenceChannel.presenceState();
        console.log('Presence state:', state);
      })
      .on('presence', { event: 'join' }, ({ key }) => {
        console.log('Player joined:', key);
      })
      .on('presence', { event: 'leave' }, async ({ key }) => {
        console.log('Player left:', key);
        await loadPlayers(); // Refresh player list
      })
      .subscribe();
  }

  async function handlePresenceSync(state) {
    const activeUserIds = Object.keys(state);
    
    // Check for inactive players
    for (const player of players) {
      if (!activeUserIds.includes(player.user_id)) {
        await handlePlayerInactive(player.user_id);
      }
    }
  }


  async function handlePlayerLeave() {
    try {
      if (!userId || !roomId) return;
      
      // If admin is leaving, transfer admin rights
      if (userId === roomData?.admin_id && players.length > 1) {
        const nextAdmin = players.find(p => p.user_id !== userId);
        if (nextAdmin) {
          await supabase
            .from('rooms')
            .update({ admin_id: nextAdmin.user_id })
            .eq('id', roomId);
        }
      }

      // Remove player from room
      await supabase
        .from('players')
        .delete()
        .eq('user_id', userId)
        .eq('room_id', roomId);

      if (browser) {
        localStorage.removeItem('roomId');
        localStorage.removeItem('currentRoomCode');
      }

      // Check if the lobby should be deleted
      await checkAndDeleteLobby(); // Call the new function here

    } catch (err) {
      console.error('Error handling player leave:', err);
    }
  }

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

  // 2. Add new function to update player status
  async function updatePlayerStatus() {
    console.log(`🔄 Updating player status for room: ${roomId}...`);
    try {
      // Don't update if game is already started
      if (gameStarted) {
        console.log(`⏩ Game already started for room: ${roomId}, skipping player status update`);
        return;
      }

      // Get fresh player data
      const { data: currentPlayers, error: fetchError } = await supabase
        .from('players')
        .select('*')
        .eq('room_id', roomId)
        .order('created_at');

      if (fetchError) {
        console.error(`Failed to fetch players for room: ${roomId}`, fetchError);
        throw fetchError;
      }

      if (!currentPlayers) {
        console.log(`No players found for room: ${roomId}`);
        return;
      }

      players = currentPlayers;
      
      // Update ready status for current user
      const currentPlayer = players.find(p => p.user_id === userId);
      if (currentPlayer) {
        isReady = currentPlayer.is_ready;
      }

      // Update ready count
      const readyCount = players.filter(p => p.is_ready).length;
      readyStatus = `${readyCount}/${players.length} players ready`;
      console.log(`📊 Ready status for room: ${roomId}:`, readyStatus);

      // Only check all players ready if everyone is ready, game hasn't started, and current user is admin
      if (readyCount === players.length && readyCount >= 2 && !gameStarted) {
        console.log(`✨ All players ready in room: ${roomId}, checking conditions...`);
        await checkAllPlayersReady();
      }

    } catch (err) {
      console.error(`💥 Error updating player status for room: ${roomId}:`, err);
    }
  }

async function updateGameModeStatus() {
  console.log('🎮 Updating game mode status...');
  try {
    // Don't update if game is already started
    if (gameStarted) {
      console.log('⏩ Game already started, skipping game mode status update');
      return;
    }

    // Get fresh room data
    const { data: freshRoomData, error: roomError } = await supabase
      .from('rooms')
      .select('*')
      .eq('id', roomId)
      .single();

    if (roomError) {
      console.error('Failed to fetch room data:', roomError);
      throw roomError;
    }

    if (!freshRoomData) {
      console.log('No room data found');
      return;
    }

    // Update local state
    roomData = freshRoomData;
    selectedGameMode = freshRoomData.game_mode;
    currentGameMode.set(freshRoomData.game_mode);

    console.log('📊 Game mode status:', freshRoomData.game_mode);

    // Update card count for the current game mode
    await updateCardCount(freshRoomData.game_mode);

    // If game mode has changed, reset ready states
    if (roomData.game_mode !== selectedGameMode) {
      console.log('🔄 Game mode changed, resetting ready states...');
      isReady = false;
      await loadPlayers(); // This will refresh player list and ready states
    }

    // Force reactive update
    roomData = { ...roomData };

  } catch (err) {
    console.error('💥 Error updating game mode status:', err);
  }
}
  // Update setupSubscriptions function for better real-time updates
  function setupSubscriptions() {
    try {
      console.log('🔌 Setting up subscriptions...');
      
      const roomChannel = supabase.channel(`room_${roomId}`)
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'rooms',
          filter: `id=eq.${roomId}`
        }, async (payload) => {
          console.log('🏠 Room update received:', payload);
          if (payload.new) {
            roomData = { ...payload.new };
            
            // Handle game start for all users
            if (payload.new.status === 'playing' && !gameStarted && payload.new.game_session_id) {
              console.log('🎮 Game is now in playing state with session:', payload.new.game_session_id);
              gameStarted = true;
              await startGameForAllUsers();
            }
          }
        })
        .subscribe((status) => {
          console.log(`Room subscription status for ${roomId}:`, status);
          if (status === 'SUBSCRIBED') {
            console.log('✅ Successfully subscribed to room changes');
          } else if (status === 'CHANNEL_ERROR') {
            console.error('❌ Channel error, attempting to reconnect...');
            setTimeout(() => setupSubscriptions(), 5000);
          }
        });

      const playerChannel = supabase.channel(`player_${roomId}`)
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'players',
          filter: `room_id=eq.${roomId}`
        }, async (payload) => {
          console.log('👥 Player update received:', payload);
          await handlePlayerStateChange(payload);
        })
        .subscribe((status) => {
          console.log(`Player subscription status for ${roomId}:`, status);
          if (status === 'SUBSCRIBED') {
            console.log('✅ Successfully subscribed to player changes');
          } else if (status === 'CHANNEL_ERROR') {
            console.error('❌ Channel error, attempting to reconnect...');
            setTimeout(() => setupSubscriptions(), 5000);
          }
        });

      return () => {
        roomChannel.unsubscribe();
        playerChannel.unsubscribe();
      };

    } catch (err) {
      console.error('💥 Error in setupSubscriptions:', err);
      // Attempt to reconnect after a delay
      setTimeout(() => {
        console.log('Attempting to reconnect after error...');
        setupSubscriptions();
      }, 5000);
    }
  }


  // Add new handler for player state changes
  async function handlePlayerStateChange(payload) {
    try {
      // Refresh player list
      const { data: updatedPlayers, error } = await supabase
        .from('players')
        .select('*')
        .eq('room_id', roomId)
        .order('created_at');

      if (error) throw error;

      players = updatedPlayers;

      // Update ready status for current user
      const currentPlayer = players.find(p => p.user_id === userId);
      if (currentPlayer) {
        isReady = currentPlayer.is_ready;
      }

      // Update ready count
      const readyCount = players.filter(p => p.is_ready).length;
      readyStatus = `${readyCount}/${players.length} players ready`;

    } catch (err) {
      console.error('💥 Error in handlePlayerStateChange:', err);
    }
  }
  async function handleGameModeChange(newGameMode) {
    try {
      if (userId !== roomData?.admin_id || players.length < 2) {
        return;
      }

      selectedGameMode = newGameMode;

      // Reset admin's ready state when changing game mode
      if (isReady) {
        const { error: readyError } = await supabase
          .from('players')
          .update({ is_ready: false })
          .eq('user_id', userId)
          .eq('room_id', roomId);

        if (readyError) throw readyError;
        
        isReady = false;
      }

    } catch (err) {
      console.error('Error handling game mode change:', err);
      error = 'Failed to update game mode selection';
    }
  }

  async function saveGameMode() {
    try {
      isLoading = true;
      error = null;
      
      if (selectedGameMode === roomData.game_mode) {
        return;
      }

      // First, reset all players' ready status
      const { error: playersError } = await supabase
        .from('players')
        .update({ is_ready: false })
        .eq('room_id', roomId);

      if (playersError) throw playersError;

      // Then update room's game mode
      const { data, error: updateError } = await supabase
        .from('rooms')
        .update({ 
          game_mode: selectedGameMode,
          status: 'waiting',
          game_session_id: null
        })
        .eq('id', roomId)
        .select()
        .single();

      if (updateError) throw updateError;

      // Update local state
      if (data) {
        roomData = data;
        selectedGameMode = data.game_mode;
        currentGameMode.set(data.game_mode);
        
        // Force a refresh of the players' status
        await loadPlayers();
        
        // Reset local ready state
        isReady = false;
      }

      console.log('✅ Game mode updated successfully:', selectedGameMode);

    } catch (err) {
      console.error('❌ Error updating game mode:', err);
      error = 'Failed to update game mode';
      // Revert selection on error
      selectedGameMode = roomData?.game_mode;
    } finally {
      isLoading = false;
    }
  }

  async function loadGameSession() {
    try {
      const { data: session, error } = await supabase
        .from('game_sessions')
        .select('*')
        .eq('room_id', roomId)
        .eq('is_active', true)
        .single();

      if (error) {
        console.error('Error loading game session:', error);
        throw error;
      }

      if (!session) {
        console.error('No active game session found for room:', roomId);
        return null;
      }

      console.log('Loaded game session:', session);
      gameSession = session;
      return session;
    } catch (err) {
      console.error('Error in loadGameSession:', err);
      return null;
    }
  }

  async function handleGameStart() {
    console.log('🎮 Initiating game start...');
    try {
      // Check for existing active session
      const { data: existingSession } = await supabase
        .from('game_sessions')
        .select('*')
        .eq('room_id', roomId)
        .eq('is_active', true)
        .single();

      if (existingSession) {
        console.log('⚠️ Active session already exists:', existingSession.id);
        
        // Update local game state with existing session
        gameSession = existingSession;
        gameStarted = true;
        currentPlayerIndex = existingSession.current_player_index;
        isMyTurn = existingSession.player_sequence[existingSession.current_player_index] === userId;
        isCardRevealed = existingSession.current_card_revealed;

        // Load current card data
        if (existingSession.current_card) {
          const { data: cardData, error: cardError } = await supabase
            .from('game_cards')
            .select('content')
            .eq('game_mode', roomData.game_mode)
            .eq('card_index', existingSession.current_card)
            .single();

          if (cardError) throw cardError;
          currentCard = cardData;
        }

        // Update game state
        currentGameState.set({
          deckName: roomData.game_mode,
          currentCardIndex: existingSession.current_card_index,
          totalCards: existingSession.card_sequence.length,
          isDrawPhase: isMyTurn && !isCardRevealed
        });

        console.log('✨ Game state updated with existing session!', {
          isMyTurn,
          currentPlayerIndex,
          isCardRevealed,
          isDrawPhase: isMyTurn && !isCardRevealed
        });

        return true;
      }

      // 1. Update room status to 'starting'
      const { error: roomUpdateError } = await supabase
        .from('rooms')
        .update({ status: 'starting' })
        .eq('id', roomId)
        .eq('status', 'waiting'); // Only update if status is 'waiting'

      if (roomUpdateError) throw roomUpdateError;

      // 2. Get all cards for the current game mode
      const { data: cards, error: cardsError } = await supabase
        .from('game_cards')
        .select('card_index')
        .eq('game_mode', roomData.game_mode)
        .order('card_index');

      if (cardsError) throw cardsError;
      if (!cards?.length) {
        throw new Error('No cards found for this game mode');
      }

      // 3. Create randomized card sequence
      const cardSequence = cards
        .map(card => card.card_index)
        .sort(() => Math.random() - 0.5);

      // 4. Create player sequence (starting with admin)
      const playerSequence = players
        .sort((a, b) => {
          // Ensure admin is first
          if (a.user_id === roomData.admin_id) return -1;
          if (b.user_id === roomData.admin_id) return 1;
          return 0;
        })
        .map(player => player.user_id);

      console.log('📊 Game setup:', {
        cardSequence,
        playerSequence,
        gameMode: roomData.game_mode
      });

      // 5. Create game session using the safe function
      const { data: session, error: sessionError } = await supabase
        .rpc('create_game_session_safe', {
          p_room_id: roomId,
          p_card_sequence: cardSequence,
          p_player_sequence: playerSequence,
          p_started_at: new Date().toISOString()
        });

      if (sessionError) throw sessionError;

      // 6. Update local game state
      gameSession = session;
      gameStarted = true;
      currentPlayerIndex = 0;
      isMyTurn = userId === playerSequence[0];
      isCardRevealed = false;

      // 7. Update game state store
      currentGameState.set({
        deckName: roomData.game_mode,
        currentCardIndex: 0,
        totalCards: cardSequence.length,
        isDrawPhase: isMyTurn
      });

      // 8. Load first card
      if (session.current_card) {
        const { data: cardData, error: cardError } = await supabase
          .from('game_cards')
          .select('content')
          .eq('game_mode', roomData.game_mode)
          .eq('card_index', session.current_card)
          .single();

        if (cardError) throw cardError;
        currentCard = cardData;
      }

      // 9. Update room status to 'playing'
      const { error: finalRoomUpdateError } = await supabase
        .from('rooms')
        .update({ status: 'playing' })
        .eq('id', roomId);

      if (finalRoomUpdateError) throw finalRoomUpdateError;

      console.log('✨ Game start initiated successfully!');
      return true;

    } catch (err) {
      console.error('💥 Error in handleGameStart:', err);
      error = 'Failed to start game. Please try again.';
      return false;
    }
  }

  async function startGameForAllUsers() {
    console.log('🎬 Starting game for all users...');
    try {
      // First, check if the room status is 'playing'
      const { data: currentRoom, error: roomError } = await supabase
        .from('rooms')
        .select('status, game_session_id')
        .eq('id', roomId)
        .single();

      if (roomError) throw roomError;

      console.log('📊 Current room state:', currentRoom);

      if (!currentRoom.game_session_id) {
        console.log('⚠️ No game session ID found in room');
        return;
      }

      // Now load the game session
      const session = await loadGameSession();
      
      if (!session) {
        console.log('⚠️ No active session found');
        return;
      }

      console.log('✅ Game session loaded:', {
        sessionId: session.id,
        roomId: session.room_id,
        status: currentRoom.status
      });

      if (session && session.room_id === roomId) {
        // Set game state before navigation
        gameStarted = true;
        gameSession = session;
        currentPlayerIndex = session.current_player_index;
        isMyTurn = session.player_sequence[session.current_player_index] === userId;
        isCardRevealed = session.current_card_revealed;

        // Update game state store
        currentGameState.set({
          deckName: roomData.game_mode,
          currentCardIndex: session.current_card_index,
          totalCards: session.card_sequence.length,
          isDrawPhase: isMyTurn && !isCardRevealed
        });

        // Store game session ID in localStorage
        if (browser) {
          localStorage.setItem('gameSessionId', session.id);
        }

        console.log('🎮 Navigating to game page...');
        
        // Use a timeout to ensure state is updated before navigation
        setTimeout(() => {
          goto(`/game/${roomId}`);
        }, 100);
      }
    } catch (err) {
      console.error('💥 Error starting game for all users:', err);
      error = 'Failed to start game. Please refresh and try again.';
    }
  }

  $: if (gameStarted && updateInterval) {
    clearInterval(updateInterval);
    updateInterval = null;
  }

  onDestroy(() => {
    if (updateInterval) {
      clearInterval(updateInterval);
    }
    
    // Clean up subscriptions
    if (typeof cleanupSubscriptions === 'function') {
      cleanupSubscriptions();
    }

    // Store current game state if game has started
    if (gameStarted && browser) {
      localStorage.setItem('gameState', JSON.stringify({
        gameStarted,
        currentPlayerIndex,
        isMyTurn,
        isCardRevealed,
        gameSessionId: gameSession?.id
      }));
    }
  });

  async function handleCardReveal() {
    if (!isMyTurn || isCardRevealed || isLoading) {
      console.log('⚠ Card reveal blocked:', { isMyTurn, isCardRevealed, isLoading });
      return;
    }
    
    isLoading = true;
    
    try {
      // Get the current card index from the game session
      const currentCardIndex = gameSession.card_sequence[gameSession.current_card_index];
      
      // Fetch the card content
      const { data: cardData, error: cardError } = await supabase
        .from('game_cards')
        .select('*')  // Select all fields to get both content and card_index
        .eq('game_mode', roomData.game_mode)
        .eq('card_index', currentCardIndex)
        .single();

      if (cardError) throw cardError;

      // Update game session to mark card as revealed and include card content
      const { error: updateError } = await supabase
        .from('game_sessions')
        .update({
          current_card_revealed: true,
          current_card: cardData.card_index,  // Store the card index
          last_update: new Date().toISOString()
        })
        .eq('id', gameSession.id);

      if (updateError) throw updateError;
      
      // Update local state
      currentCard = cardData;
      isCardRevealed = true;
      
      console.log('✅ Card revealed:', cardData);
    } catch (err) {
      console.error('💥 Error revealing card:', err);
      error = 'Failed to reveal card';
    } finally {
      isLoading = false;
    }
  }

  // Update the reactive statement to properly handle draw phase
  $: if (gameStarted) {
    const newDrawPhase = isMyTurn && !isCardRevealed && currentCard !== null;
    console.log('🎲 Game state update:', {
      isMyTurn,
      isCardRevealed,
      hasCurrentCard: currentCard !== null,
      newDrawPhase,
      currentPlayerIndex,
      userId,
      playerSequence: gameSession?.player_sequence,
      currentPlayer: gameSession?.player_sequence[currentPlayerIndex]
    });

    // Update all local states
    currentGameState.update(state => {
      const updatedState = {
        ...state,
        isDrawPhase: newDrawPhase,
        deckName: roomData?.game_mode || state.deckName,
        currentCardIndex: gameSession?.current_card_index || state.currentCardIndex,
        totalCards: gameSession?.card_sequence?.length || state.totalCards
      };
      console.log(' Updated game state:', updatedState);
      return updatedState;
    });

    // Ensure local state variables are in sync
    if (gameSession) {
      currentPlayerIndex = gameSession.current_player_index;
      isMyTurn = gameSession.player_sequence[currentPlayerIndex] === userId;
      isCardRevealed = gameSession.current_card_revealed;
    }
  }

  // Add a reactive statement to handle currentCard updates
  $: {
    if (gameSession && !currentCard) {
      console.log('🃏 Loading current card...', {
        gameMode: roomData?.game_mode,
        currentCardIndex: gameSession.current_card
      });
      loadCurrentCard();
    }
  }

  // Add helper function to load current card
  async function loadCurrentCard() {
    if (!gameSession || !roomData) return;
    
    try {
      const { data: cardData, error: cardError } = await supabase
        .from('game_cards')
        .select('content')
        .eq('game_mode', roomData.game_mode)
        .eq('card_index', gameSession.current_card)
        .single();

      if (cardError) throw cardError;
      
      console.log('✅ Card loaded:', cardData);
      currentCard = cardData;
    } catch (err) {
      console.error('💥 Error loading card:', err);
    }
  }

  // Add this function near your other helper functions
  function isLastCard() {
    if (!gameSession?.card_sequence) return false;
    return gameSession.current_card_index === gameSession.card_sequence.length - 1;
  }

  onMount(() => {
    const gameSessionSubscription = supabase
      .from(`game_sessions:id=eq.${gameSession.id}`)
      .on('UPDATE', payload => {
        console.log('🔔 Game session updated:', payload.new);
        gameSession = payload.new;
        updateLocalGameState();
      })
      .subscribe();

    return () => {
      supabase.removeSubscription(gameSessionSubscription);
    };
  });

  function updateLocalGameState() {
    currentCard = gameSession.current_card_revealed ? { content: gameSession.current_card_content } : null;
    isCardRevealed = gameSession.current_card_revealed;
    currentGameState.set({
      deckName: roomData.game_mode,
      currentCardIndex: gameSession.current_card_index,
      totalCards: gameSession.card_sequence.length,
      isDrawPhase: isMyTurn && !isCardRevealed
    });
  }

  async function handleGameEnd() {
    console.log('🏁 Handling game end...');
    isLoading = true;

    try {
      // 1. Update game session to inactive
      const { error: sessionError } = await supabase
        .from('game_sessions')
        .update({
          is_active: false,
          last_update: new Date().toISOString()
        })
        .eq('id', gameSession.id);

      if (sessionError) throw sessionError;

      // 2. Update room status
      const { error: roomError } = await supabase
        .from('rooms')
        .update({
          status: 'waiting',
          game_session_id: null
        })
        .eq('id', roomId);

      if (roomError) throw roomError;

      // 3. Reset local game state
      gameStarted = false;
      gameSession = null;
      currentCard = null;
      isMyTurn = false;
      isCardRevealed = false;
      currentPlayerIndex = 0;

      // 4. Reset game state store
      currentGameState.set({
        deckName: '',
        currentCardIndex: 0,
        totalCards: 0,
        isDrawPhase: false
      });

      console.log('✅ Game ended successfully');

      // 5. Redirect to lobby or show end game screen
      goto(`/lobby/${roomId}`);
    } catch (err) {
      console.error('💥 Error ending game:', err);
      error = 'Failed to end game';
    } finally {
      isLoading = false;
    }
  }

  async function handleEndTurn() {
    console.log('🔄 Handling end turn...');
    if (!isMyTurn || !isCardRevealed || isLoading) {
      console.log('⚠ End turn blocked:', { isMyTurn, isCardRevealed, isLoading });
      return;
    }

    isLoading = true;

    try {
      // Calculate next player index
      const nextPlayerIndex = (currentPlayerIndex + 1) % gameSession.player_sequence.length;
      const nextCardIndex = gameSession.current_card_index + 1;
      const nextCard = gameSession.card_sequence[nextCardIndex];

      console.log('📊 Turn transition:', {
        currentIndex: currentPlayerIndex,
        nextIndex: nextPlayerIndex,
        nextCardIndex,
        nextCard
      });

      // Update game session
      const { error: updateError } = await supabase
        .from('game_sessions')
        .update({
          current_player_index: nextPlayerIndex,
          current_card_index: nextCardIndex,
          current_card: nextCard,
          current_card_revealed: false,
          last_update: new Date().toISOString()
        })
        .eq('id', gameSession.id);

      if (updateError) throw updateError;

      // Update local state
      currentPlayerIndex = nextPlayerIndex;
      isMyTurn = gameSession.player_sequence[nextPlayerIndex] === userId;
      isCardRevealed = false;
      currentCard = null;

      console.log('✅ Turn ended successfully:', {
        nextPlayer: players[nextPlayerIndex]?.username,
        isMyTurn,
        currentCardIndex: nextCardIndex
      });

    } catch (err) {
      console.error('💥 Error ending turn:', err);
      error = 'Failed to end turn';
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    const gameSessionSubscription = supabase
      .channel(`game_sessions:${gameSession?.id}`)
      .on('postgres_changes', 
        { 
          event: 'UPDATE', 
          schema: 'public', 
          table: 'game_sessions',
          filter: `id=eq.${gameSession?.id}`
        }, 
        async (payload) => {
          console.log('🔄 Game session updated:', payload.new);
          
          // Update game session data
          gameSession = payload.new;
          
          // Update local state based on game session changes
          currentPlayerIndex = payload.new.current_player_index;
          isMyTurn = payload.new.player_sequence[currentPlayerIndex] === userId;
          isCardRevealed = payload.new.current_card_revealed;
          
          // If card is revealed, fetch and update card content
          if (payload.new.current_card_revealed && !currentCard) {
            const { data: cardData } = await supabase
              .from('game_cards')
              .select('*')
              .eq('game_mode', roomData.game_mode)
              .eq('card_index', payload.new.current_card)
              .single();
              
            if (cardData) {
              currentCard = cardData;
            }
          }
          
          // Update game state store
          currentGameState.update(state => ({
            ...state,
            isDrawPhase: isMyTurn && !isCardRevealed,
            currentCardIndex: payload.new.current_card_index,
            totalCards: payload.new.card_sequence.length
          }));
        })
        .subscribe();

    return () => {
      supabase.removeChannel(gameSessionSubscription);
    };
  });

</script>

<!-- Content -->
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

  <!-- Main Content -->
  <div class="relative z-10 min-h-screen flex items-center justify-center p-4">
    {#if gameStarted}
      <!-- Game Card -->
      <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
        <Card.Header class="space-y-4">
          <Card.Title class="text-2xl font-bold text-center">
            {roomData?.room_name || 'Loading...'}
          </Card.Title>
          
          <!-- Current Card Display -->
          {#if currentCard}
            <div class="card-container flex justify-center items-center w-full max-w-xl mx-auto">
              <div class="w-full space-y-4">
                <!-- Deck info and turn indicator -->
                <div class="flex flex-col gap-2 mb-4">
                  <div class="flex justify-between items-center text-sm text-muted-foreground px-2">
                    <span>Deck: {gameModes[roomData?.game_mode]?.name}</span>
                    <span>
                      Card {gameSession?.current_card_index + 1}/{gameSession?.card_sequence?.length} 
                      {#if isLastCard()} 
                        <span class="text-orange-500 font-medium">(Final Card!)</span>
                      {/if}
                    </span>
                  </div>
                  
                </div>

                <!-- Card -->
                <div class="card-content relative w-full h-full">
                  <!-- Card Container -->
                  <div class="game-card-container w-full aspect-[3/4] relative">
                    <button
                      type="button"
                      class="game-card w-full h-full {$currentGameState.isDrawPhase ? 'active pulse-animation' : ''}"
                      on:click={() => $currentGameState.isDrawPhase && handleCardReveal() && handleDrawCard()}
                      disabled={!$currentGameState.isDrawPhase || isLoading}
                    >
                      <div class="card-inner {isCardRevealed ? 'revealed' : ''} w-full h-full">
                        <!-- Face-down state -->
                        <div class="card-face card-front absolute inset-0">
                          <div class="flex flex-col items-center justify-center h-full p-8 text-center">
                            {#if $currentGameState.isDrawPhase}
                              <div class="space-y-4 animate-pulse">
                                <p class="text-2xl font-semibold text-primary">Your Turn!</p>
                                <p class="text-lg text-muted-foreground">Click to Draw Card</p>
                              </div>
                            {:else if !isMyTurn}
                              <div class="loading-card-state space-y-6">
                                <div class="loading-animation">
                                  <div class="card-stack">
                                    {#each Array(3) as _, i}
                                      <!-- svelte-ignore element_invalid_self_closing_tag -->
                                      <div 
                                        class="stacked-card" 
                                        style="--delay: {i * 150}ms; --offset: {i * 4}px"
                                      ></div>
                                    {/each}
                                  </div>
                                </div>
                                <p class="text-lg text-muted-foreground animate-pulse">
                                  Waiting for {players[currentPlayerIndex]?.username}'s move...
                                </p>
                              </div>
                            {/if}
                          </div>
                        </div>
                        <!-- Face-up state -->
                        <div class="card-face card-back absolute inset-0">
                          {#if isCardRevealed && currentCard?.content}
                            <div class="flex flex-col items-center justify-center h-full p-8 text-center space-y-6">
                              <div class="card-content-wrapper max-w-sm mx-auto p-8 rounded-xl bg-card/50 backdrop-blur-sm">
                                <p class="text-2xl font-medium leading-relaxed text-primary">
                                  {currentCard.content}
                                </p>
                              </div>
                            </div>
                          {/if}
                        </div>
                      </div>
                    </button>
                  </div>
                </div>

                <!-- Turn control button -->
                {#if isMyTurn && isCardRevealed}
                  <div class="flex justify-center mt-4">
                    <Button
                      variant={isLastCard() ? "destructive" : "default"}
                      size="lg"
                      on:click={isLastCard() ? handleGameEnd : handleEndTurn}
                      disabled={!isMyTurn || !isCardRevealed || isLoading}
                    >
                      {#if isLoading}
                        Processing...
                      {:else if isLastCard()}
                        End Game - Last Card!
                      {:else}
                        End Turn
                      {/if}
                    </Button>
                  </div>
                {/if}
              </div>
            </div>
          {/if}

          <!-- Turn Information -->
          <div class="text-center space-y-4">
            <div class="flex items-center justify-center gap-2">
              <span class="text-sm text-muted-foreground">Current Turn:</span>
              <Badge variant={isMyTurn ? "default" : "outline"} class="text-base">
                {players[currentPlayerIndex]?.username || 'Loading...'}
                {isMyTurn ? " (You)" : ""}
              </Badge>
            </div>
          </div>
        </Card.Header>

        <Card.Content class="space-y-4">
          <!-- Player List -->
          <div class="space-y-2">
            <div class="flex items-center gap-2 text-muted-foreground">
              <Users class="h-5 w-5" />
              <span>Players ({players.length})</span>
            </div>
            <div class="space-y-2">
              {#each players as player}
                <div class="flex items-center justify-between p-2 rounded-lg bg-accent/50">
                  <span class={player.user_id === userId ? 'font-semibold' : ''}>
                    {player.username}
                    {#if player.user_id === userId}
                      <span class="text-xs text-muted-foreground">(You)</span>
                    {/if}
                  </span>
                  {#if player.user_id === players[currentPlayerIndex]?.user_id}
                    <Badge variant="secondary">Current Turn</Badge>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        </Card.Content>

        <Card.Footer>
          <Button
            variant="outline"
            size="lg"
            class="w-full hover:bg-destructive hover:text-destructive-foreground"
            disabled={isLoading}
            on:click={() => showLeaveConfirm = true && handlePlayerLeaveDuringGame}
          >
            Leave Game
          </Button>
          {#if isTurnActive}
            <div>
                <p>{currentQuestion}</p>
                <Button on:click={endTurn}>
                    End Turn
                </Button>
            </div>
          {/if}
        </Card.Footer>
      </Card.Root>
    {:else}
      <!-- Original Lobby Card -->
      <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
        <Card.Header>
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
          <div class="space-y-4">
            <!-- Game Mode Selection -->
            <div class="space-y-4">
              <Label class="text-foreground/80">
                Game Mode
              </Label>
              {#if roomData}
                {#if userId === roomData.admin_id}
                  <div class="grid grid-cols-1 gap-4">
                    {#each Object.entries(gameModes) as [id, mode]}
                      <div class="space-y-2">
                        <button
                          type="button"
                          class="w-full relative flex items-center p-4 cursor-pointer rounded-lg border border-input bg-background hover:bg-accent/5 transition-colors
                            {selectedGameMode === id ? 'border-primary ring-2 ring-ring' : ''}"
                          on:click={() => handleGameModeChange(id)}
                        >
                          <div class="font-medium flex items-center gap-2">
                            {mode.name}
                          </div>
                        </button>
                        
                        {#if selectedGameMode === id}
                          <div 
                            class="text-sm text-muted-foreground px-4 py-2 bg-muted/30 rounded-md"
                            transition:slide={{ duration: 200 }}
                          >
                            {mode.description}
                          </div>
                        {/if}
                      </div>
                    {/each}
                  </div>
                  {#if selectedGameMode !== roomData.game_mode}
                    <Button
                      variant="outline"
                      size="sm"
                      class="w-full mt-2"
                      on:click={saveGameMode}
                      disabled={isLoading}
                    >
                      Save Game Mode
                    </Button>
                  {/if}
                {:else}
                  <div class="space-y-2">
                    <div class="p-4 rounded-lg border border-input bg-background">
                      <div class="font-medium">
                        {#key roomData.game_mode}
                          <div class="flex items-center gap-2" transition:slide={{ duration: 200 }}>
                            {gameModes[roomData.game_mode]?.name || 'Unknown Mode'}
                          </div>
                        {/key}
                      </div>
                    </div>
                    {#key roomData.game_mode}
                      <div 
                        class="text-sm text-muted-foreground px-4 py-2 bg-muted/30 rounded-md"
                        transition:slide={{ duration: 200 }}
                      >
                        {gameModes[roomData.game_mode]?.description || 'Mode description not available'}
                      </div>
                    {/key}
                  </div>
                {/if}
              {:else}
                <div class="p-4 rounded-lg border border-input bg-background">
                  <div class="font-medium">Loading game mode...</div>
                </div>
              {/if}
            </div>
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
              ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30' 
              : 'bg-red-500/20 text-red-300 border border-red-500/30'
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
            disabled={isLoading || (userId === roomData?.admin_id && selectedGameMode !== roomData?.game_mode)}
            on:click={toggleReady}
          >
            {#if isLoading}
              <span class="animate-pulse">Loading...</span>
            {:else if players.length < 2}
              <Users class="h-5 w-5 mr-2" />
              Waiting for Players ({players.length}/2)
            {:else if userId === roomData?.admin_id && selectedGameMode !== roomData?.game_mode}
              Finalize Game Mode
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
    {/if}
  </div>
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

<!-- Add Player Warning Dialog -->
<Dialog.Root bind:open={showPlayerWarningDialog}>
  <Dialog.Content class="bg-background border-border">
    <Dialog.Header>
      <Dialog.Title class="text-foreground">Waiting for Players</Dialog.Title>
      <Dialog.Description class="text-muted-foreground">
        At least 2 players are required to start the game. Share this room code with your friends:
      </Dialog.Description>
    </Dialog.Header>
    <div class="p-4 space-y-4">
      <div class="flex items-center justify-between p-3 rounded-lg bg-accent">
        <span class="font-mono text-lg">{roomCode}</span>
        <Button
          variant="ghost"
          size="sm"
          class="hover:text-primary"
          on:click={copyRoomCode}
        >
          <Copy class="h-4 w-4" />
          <span class="sr-only">Copy room code</span>
        </Button>
      </div>
      <p class="text-sm text-muted-foreground text-center">
        Current Players: {players.length}/2
      </p>
    </div>
    <Dialog.Footer>
      <Button 
        variant="outline" 
        on:click={() => showPlayerWarningDialog = false}
      >
        Cancel
      </Button>
    </Dialog.Footer>
  </Dialog.Content>
</Dialog.Root>
<style>
.pulse-animation {
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0% {
    transform: scale(1);
    box-shadow: 0 0 0 0 rgba(var(--primary) / 0.7);
  }
  
  70% {
    transform: scale(1.05);
    box-shadow: 0 0 0 10px rgba(var(--primary) / 0);
  }
  
  100% {
    transform: scale(1);
    box-shadow: 0 0 0 0 rgba(var(--primary) / 0);
  }
}
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

  svg {
    height: 100%;
    width: 100%;
    mix-blend-mode: screen;
    opacity: 0.7;
  }

  .card-container {
    width: 100%;
    padding: 1rem;
  }

  .game-card {
    @apply bg-card rounded-xl transition-all duration-300 ease-out;
    border: 1px solid hsl(var(--border));
    min-height: 400px;
    perspective: 1000px;
  }

  .game-card:not(:disabled).active {
    @apply cursor-pointer hover:border-primary/50;
  }

  .game-card:not(:disabled).active:hover {
    transform: translateY(-4px);
    box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1),
                0 8px 10px -6px rgb(0 0 0 / 0.1);
  }

  .card-inner {
    position: relative;
    width: 100%;
    height: 100%;
    transform-style: preserve-3d;
    transition: transform 0.6s cubic-bezier(0.23, 1, 0.32, 1);
  }

  .card-inner.revealed {
    transform: rotateY(180deg);
  }

  .card-face {
    position: absolute;
    width: 100%;
    height: 100%;
    backface-visibility: hidden;
    @apply rounded-xl overflow-hidden;
  }

  .card-back {
    transform: rotateY(180deg);
  }

  .card-content-wrapper {
    @apply bg-card/50 backdrop-blur-sm rounded-lg p-6;
    border: 1px solid hsl(var(--border));
  }

  .loading-card-state {
    @apply flex flex-col items-center justify-center;
  }

  .loading-animation {
    @apply relative w-24 h-32 mb-4;
  }

  .card-stack {
    @apply relative w-full h-full;
    perspective: 1000px;
  }

  .stacked-card {
    @apply absolute inset-0 rounded-xl border border-primary/20;
    background: linear-gradient(
      135deg,
      hsl(var(--primary) / 0.1),
      hsl(var(--primary) / 0.05)
    );
    animation: float 2s ease-in-out infinite;
    animation-delay: var(--delay);
    transform: translateY(var(--offset)) scale(0.95);
    box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1),
                0 2px 4px -2px rgb(0 0 0 / 0.1);
  }

  @keyframes float {
    0%, 100% {
      transform: translateY(var(--offset)) scale(0.95);
    }
    50% {
      transform: translateY(calc(var(--offset) - 8px)) scale(0.95);
    }
  }

  .game-card {
    @apply bg-card rounded-xl transition-all duration-300 ease-out;
    border: 1px solid hsl(var(--border));
    min-height: 400px;
    perspective: 1000px;
  }

  .game-card:not(:disabled).active {
    @apply cursor-pointer hover:border-primary/50;
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }

  @keyframes pulse {
    0%, 100% {
      box-shadow: 0 0 0 0 hsl(var(--primary) / 0.3);
    }
    50% {
      box-shadow: 0 0 0 8px hsl(var(--primary) / 0);
    }
  }

  .card-inner {
    position: relative;
    transform-style: preserve-3d;
    transition: transform 0.6s cubic-bezier(0.23, 1, 0.32, 1);
  }

  .card-face {
    backface-visibility: hidden;
    @apply rounded-xl overflow-hidden;
  }
  </style>
