<script>
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


  let players = [];
  let roomData = null;
  let isReady = false;
  let error = '';
  let isLoading = false;
  let readyStatus = '';
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
  let gameSubscription;
  let isCardRevealed = false;
  let selectedGameMode = '';
  let currentCardCount = 0;
  let playersSubscription;
  let roomSubscription;
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
        loadGameSession()  // This will now have access to roomData.game_mode
      ]);

      // Initialize subscriptions after data is loaded
      setupSubscriptions();
      setupPresence();
      
      // Start periodic updates
      updateInterval = setInterval(async () => {
        await updatePlayerStatus();
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

  async function handleRoomChange(newRoomData) {
    try {
      if (!newRoomData) return;
      
      console.log('Processing room change:', newRoomData);
      
      const gameModeChanged = roomData?.game_mode !== newRoomData.game_mode;
      
      // Update room data
      roomData = newRoomData;
      
      // Handle game mode changes
      if (gameModeChanged) {
        console.log(`Game mode changed to: ${newRoomData.game_mode}`);
        
        // Update all game mode related states
        selectedGameMode = newRoomData.game_mode;
        currentGameMode.set(newRoomData.game_mode);
        
        // Update card count
        const count = await getCardCount(newRoomData.game_mode);
        currentCardCount = count;
        
        // Reset ready state
        isReady = false;
        
        // Show feedback
        successMessage = `Game mode changed to ${gameModes[newRoomData.game_mode].name}!`;
        setTimeout(() => successMessage = '', 3000);
        
        // Force state refresh
        roomData = { ...roomData };
        
        // Force player status update
        await updatePlayerStatus();
      }
    } catch (err) {
      console.error('Error in handleRoomChange:', err);
      error = 'Failed to update room state';
    }
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
      console.log('Loaded room data:', roomData);
      console.log('Game mode:', roomData?.game_mode);
      return data;
    } catch (err) {
      console.error('Failed to load room:', err);
      return null;
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

  async function checkAllPlayersReady() {
    console.log('🔍 Checking all players ready status...');
    try {
      // Get fresh room data
      const { data: currentRoom } = await supabase
        .from('rooms')
        .select('status, game_session_id')
        .eq('id', roomId)
        .single();

      // Don't proceed if game is already in progress
      if (currentRoom?.status === 'playing' || currentRoom?.game_session_id) {
        console.log('⚠️ Game already in progress');
        return false;
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
      if (roomData?.admin_id === userId && currentRoom?.status === 'waiting') {
        console.log('✨ All conditions met for game start!');
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

      isLoading = true;
      const newReadyState = !isReady;
      
      // First update local state
      isReady = newReadyState;
      
      // Then update database (removed last_updated field)
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

  async function getCardCount(gameMode) {
  try {
    if (!gameMode) {
      console.error('No game mode provided for card count');
      return 0;
    }

    const { count, error } = await supabase
      .from('game_cards')
      .select('*', { count: 'exact' })
      .eq('game_mode', gameMode);

    if (error) {
      console.error('Error getting card count:', error);
      return 0;
    }

    return count || 0;
  } catch (err) {
    console.error('Error in getCardCount:', err);
    return 0;
  }
}

  // Update generateCardSequence to use dynamic card count
  async function generateCardSequence(gameMode) {
    const deckSize = await getCardCount(gameMode);
    
    console.log(`Generating sequence for ${gameMode} with ${deckSize} cards`);
    
    // Generate sequence using the actual deck size
    const sequence = Array.from({ length: deckSize }, (_, i) => i + 1);
    
    // Fisher-Yates shuffle algorithm
    for (let i = sequence.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [sequence[i], sequence[j]] = [sequence[j], sequence[i]];
    }

    console.log('Generated card sequence:', sequence);
    return sequence;
  }

  // Add function to deactivate existing sessions
  async function deactivateExistingSessions(roomId) {
    try {
      // First, get all active sessions
      const { data: activeSessions, error: fetchError } = await supabase
        .from('game_sessions')
        .select('id')
        .eq('room_id', roomId)
        .eq('is_active', true);

      if (fetchError) throw fetchError;

      if (!activeSessions?.length) {
        return; // No active sessions to deactivate
      }

      // Deactivate all sessions in a single transaction
      const { error } = await supabase.rpc('deactivate_game_sessions', {
        p_room_id: roomId,
        p_timestamp: new Date().toISOString()
      });

      if (error) throw error;
      
      // Add delay to ensure deactivation is complete
      await new Promise(resolve => setTimeout(resolve, 500));
    } catch (err) {
      console.error('Failed to deactivate sessions:', err);
      throw err;
    }
  }

  // Update startGame function
  async function startGame() {
    try {
      isLoading = true;
      error = null; // Clear any previous errors
      
      // First, ensure all existing sessions are deactivated
      await deactivateExistingSessions(roomId);
      
      // Get the card sequence
      const cardSequence = await generateCardSequence(roomData.game_mode);
      const playerSequence = players.map(p => p.user_id);
      
      // Validate sequence
      if (!cardSequence?.length || cardSequence.length < 2) {
        error = 'Not enough cards in the deck to start the game';
        return false;
      }

      // Create new session using RPC to handle race conditions
      const { data: newSession, error: sessionError } = await supabase.rpc(
        'create_game_session_safe',
        {
          p_room_id: roomId,
          p_card_sequence: cardSequence,
          p_player_sequence: playerSequence,
          p_started_at: new Date().toISOString()
        }
      );

      if (sessionError) {
        console.error('Session creation error:', sessionError);
        throw sessionError;
      }

      if (!newSession) {
        throw new Error('Failed to create game session');
      }

      // Update local state
      gameSession = newSession;
      gameStarted = true;
      currentPlayerIndex = 0;
      isMyTurn = playerSequence[0] === userId;
      isCardRevealed = false;
      currentCard = null;

      // Load initial card data
      if (isMyTurn) {
        const initialCardId = cardSequence[0];
        const cardData = await loadCardData(roomData.game_mode, initialCardId);
        if (cardData) {
          currentCard = cardData;
        }
      }

      return true;
    } catch (err) {
      console.error('Error starting game:', err);
      error = 'Failed to start game. Please try again.';
      return false;
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

  async function handlePlayerInactive(inactiveUserId) {
    try {
      // Remove player from the room
      const { error: deleteError } = await supabase
        .from('players')
        .delete()
        .eq('user_id', inactiveUserId)
        .eq('room_id', roomId);

      if (deleteError) throw deleteError;

      // If this was the last player, cleanup the room
      const { data: remainingPlayers, error: countError } = await supabase
        .from('players')
        .select('user_id')
        .eq('room_id', roomId);

      if (countError) throw countError;

      if (remainingPlayers.length === 0) {
        await cleanupRoom();
      } else if (gameStarted) {
        // Update player sequence if game is in progress
        await updatePlayerSequence(remainingPlayers.map(p => p.user_id));
      }

    } catch (err) {
      console.error('Error handling inactive player:', err);
    }
  }

  async function cleanupRoom() {
    try {
      // Deactivate game session if exists
      const { error: sessionError } = await supabase
        .from('game_sessions')
        .update({ is_active: false })
        .eq('room_id', roomId)
        .eq('is_active', true);

      if (sessionError) throw sessionError;

      // Delete the room
      const { error: roomError } = await supabase
        .from('rooms')
        .delete()
        .eq('id', roomId);

      if (roomError) throw roomError;

      // Redirect remaining players to home
      goto('/');
    } catch (err) {
      console.error('Error cleaning up room:', err);
    }
  }

  async function updatePlayerSequence(activePlayerIds) {
    try {
      const { error: updateError } = await supabase
        .from('game_sessions')
        .update({
          player_sequence: activePlayerIds,
          current_player_index: 0,  // Reset to first player in new sequence
          last_update: new Date().toISOString()
        })
        .eq('room_id', roomId)
        .eq('is_active', true);

      if (updateError) throw updateError;
    } catch (err) {
      console.error('Error updating player sequence:', err);
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

    } catch (err) {
      console.error('Error handling player leave:', err);
    }
  }

  onDestroy(() => {
    console.log('Component destroying, cleaning up...');
    if (updateInterval) {
      clearInterval(updateInterval);
    }
    if (playersSubscription) {
      playersSubscription.unsubscribe();
    }
    if (gameSubscription) {
      gameSubscription.unsubscribe();
    }
    if (browser) {
      window.removeEventListener('beforeunload', handlePlayerLeave);
    }
    // Reset all states
    selectedGameMode = null;
    roomData = null;
    currentGameMode.set(null);
    
    // Cleanup subscriptions
    if (roomSubscription) {
      roomSubscription.unsubscribe();
    }
    if (playersSubscription) {
      playersSubscription.unsubscribe();
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

  // 2. Add game state handler
  async function handleGameStateChange(payload) {
    try {
      const session = payload.new;
      
      if (!session) return;

      console.log('🎲 Game session changed:', session);
      
      // Update game session state
      gameSession = session;
      gameStarted = session.game_started;
      currentPlayerIndex = session.current_player_index;
      isMyTurn = session.player_sequence[session.current_player_index] === userId;
      isCardRevealed = session.current_card_revealed;

      // Force game started state if we have an active session
      if (session.is_active && !gameStarted) {
        console.log('🎯 Forcing game started state');
        gameStarted = true;
      }

      // Update card state
      if (session.current_card_revealed || isMyTurn) {
        if (!currentCard || currentCard.card_index !== session.current_card) {
          const cardData = await loadCardData(roomData.game_mode, session.current_card);
          if (cardData) {
            currentCard = cardData;
            console.log('🃏 Card loaded:', cardData);
          }
        }
      } else {
        currentCard = {
          index: session.current_card,
          content: null, // Face down state
          game_mode: roomData.game_mode
        };
      }

    } catch (err) {
      console.error('💥 Error in handleGameStateChange:', err);
      error = 'Failed to sync game state';
    }
  }

  // 3. Update handleEndTurn to use sequence indices
  async function handleEndTurn() {
    try {
      if (!isMyTurn || !isCardRevealed || !gameSession) {
        return;
      }
      
      isLoading = true;
      error = null;

      // Calculate next player index
      const nextPlayerIndex = (gameSession.current_player_index + 1) % gameSession.player_sequence.length;
      const nextCardIndex = gameSession.current_card_index + 1;

      // Update game session for next turn
      const { error: updateError } = await supabase
        .from('game_sessions')
        .update({
          current_player_index: nextPlayerIndex,
          current_card_index: nextCardIndex,
          current_card: gameSession.card_sequence[nextCardIndex],
          current_card_revealed: false,  // Reset card to face down for next player
          last_update: new Date().toISOString()
        })
        .eq('id', gameSession.id);

      if (updateError) throw updateError;

      // Local state will be updated by the subscription handler

    } catch (err) {
      console.error('Error ending turn:', err);
      error = 'Failed to end turn';
    } finally {
      isLoading = false;
    }
  }

  // 4. Add game session loading
  async function loadGameSession() {
    console.log('📥 Loading game session...');
    try {
      const { data: session, error } = await supabase
        .from('game_sessions')
        .select('*')
        .eq('room_id', roomId)
        .eq('is_active', true)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        // Only throw if it's not a "no rows returned" error
        throw error;
      }

      if (session) {
        console.log('✅ Active session found:', session);
        gameSession = session;
        gameStarted = true;
        currentPlayerIndex = session.current_player_index;
        isMyTurn = session.player_sequence[session.current_player_index] === userId;
        isCardRevealed = session.current_card_revealed;

        // Load initial card state
        if (isMyTurn || session.current_card_revealed) {
          const cardData = await loadCardData(roomData.game_mode, session.current_card);
          if (cardData) {
            currentCard = cardData;
          }
        }
      } else {
        // Check room status to determine if game should be started
        const { data: room } = await supabase
          .from('rooms')
          .select('status')
          .eq('id', roomId)
          .single();

        if (room?.status === 'playing') {
          console.log('🎮 Room is in playing state but no active session found');
          gameStarted = true;
          // Attempt to recover game state
          await syncGameState();
        } else {
          console.log('ℹ️ No active session found and room not in playing state');
          resetGameState();
        }
      }
    } catch (err) {
      console.error('💥 Error loading game session:', err);
      error = 'Failed to load game session';
      // Don't reset game state here, let the room status handle that
    }
  }

  // 2. Add new function to update player status
  async function updatePlayerStatus() {
    console.log('🔄 Updating player status...');
    try {
      // Get fresh player data
      const { data: currentPlayers, error: fetchError } = await supabase
        .from('players')
        .select('*')
        .eq('room_id', roomId)
        .order('created_at');

      if (fetchError) {
        console.error('Failed to fetch players:', fetchError);
        throw fetchError;
      }

      if (!currentPlayers) {
        console.log('No players found');
        return;
      }

      console.log('👥 Current players:', currentPlayers);
      players = currentPlayers;
      
      // Update ready status for current user
      const currentPlayer = players.find(p => p.user_id === userId);
      if (currentPlayer) {
        isReady = currentPlayer.is_ready;
      }

      // Update ready count
      const readyCount = players.filter(p => p.is_ready).length;
      readyStatus = `${readyCount}/${players.length} players ready`;
      console.log('📊 Ready status:', readyStatus);

      // Only check all players ready if everyone is ready
      if (readyCount === players.length && readyCount >= 2) {
        console.log('✨ All players ready, checking conditions...');
        await checkAllPlayersReady();
      }

    } catch (err) {
      console.error('💥 Error updating player status:', err);
      // Don't throw the error, just log it
    }
  }

  function checkGameEnd() {
    if (!gameSession) return false;
    return gameSession.current_card_index >= gameSession.card_sequence.length - 1;
  }

  // Update setupSubscriptions function for better real-time updates
  function setupSubscriptions() {
    try {
      console.log('🔌 Setting up subscriptions...');
      
      // Game session subscription with enhanced payload handling
      const gameChannel = supabase.channel(`game_${roomId}`)
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'game_sessions',
          filter: `room_id=eq.${roomId}`
        }, async (payload) => {
          console.log('📡 Game session update received:', payload);
          if (payload.new) {
            // Handle all game session changes
            await handleGameStateChange(payload);
          }
        })
        .subscribe();

      // Enhanced room status subscription
      const roomChannel = supabase.channel(`room_${roomId}`)
        .on('postgres_changes', {
          event: '*',  // Listen to all events
          schema: 'public',
          table: 'rooms',
          filter: `id=eq.${roomId}`
        }, async (payload) => {
          console.log('🏠 Room update received:', payload);
          await handleRoomStateChange(payload);
        })
        .subscribe();

      // Player status subscription
      const playerChannel = supabase.channel(`players_${roomId}`)
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'players',
          filter: `room_id=eq.${roomId}`
        }, async (payload) => {
          console.log('👥 Player update received:', payload);
          await handlePlayerStateChange(payload);
        })
        .subscribe();

      return () => {
        gameChannel.unsubscribe();
        roomChannel.unsubscribe();
        playerChannel.unsubscribe();
      };
    } catch (err) {
      console.error('💥 Error in setupSubscriptions:', err);
      throw err;
    }
  }

  // Add new handler for room state changes
  async function handleRoomStateChange(payload) {
    try {
      const newRoomData = payload.new;
      if (!newRoomData) return;

      console.log('🏠 Room state changed:', newRoomData);
      roomData = newRoomData;

      // Check for game session and status
      if (newRoomData.status === 'playing' && newRoomData.game_session_id) {
        console.log('🎮 Game is now in progress');
        if (!gameStarted) {
          gameStarted = true;
          await loadGameSession();
        }
      } else if (newRoomData.status === 'waiting') {
        console.log('⏸️ Game reset to waiting state');
        resetGameState();
      }

      // Update game mode if changed
      if (newRoomData.game_mode) {
        currentGameMode.set(newRoomData.game_mode);
      }

    } catch (err) {
      console.error('💥 Error in handleRoomStateChange:', err);
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

  // 3. Add helper function to reset game state
  function resetGameState() {
    gameSession = null;
    gameStarted = false;
    currentCard = null;
    isMyTurn = false;
    currentPlayerIndex = 0;
    isCardRevealed = false;
    isReady = false; // Reset local ready state
  }

  // 1. Update handleCardReveal to use sequence indices
  async function handleCardReveal() {
    try {
      if (!isMyTurn || isCardRevealed || !gameSession) return;
      
      isLoading = true;
      error = null;

      // First load the card data
      const { data: cardData, error: cardError } = await supabase
        .from('game_cards')
        .select('*')
        .eq('game_mode', roomData.game_mode)
        .eq('card_index', gameSession.current_card)
        .single();

      if (cardError) throw cardError;

      // Then update game session to show card is revealed
      const { error: updateError } = await supabase
        .from('game_sessions')
        .update({
          current_card_revealed: true,
          last_update: new Date().toISOString()
        })
        .eq('id', gameSession.id);

      if (updateError) throw updateError;

      // Update local state
      isCardRevealed = true;
      currentCard = cardData;

    } catch (err) {
      console.error('Error revealing card:', err);
      error = 'Failed to reveal card';
    } finally {
      isLoading = false;
    }
  }

  // 2. Update syncGameState for better card synchronization
  async function syncGameState() {
    try {
      const { data: room } = await supabase
        .from('rooms')
        .select('status, game_mode')
        .eq('id', roomId)
        .single();

      if (room?.status === 'playing') {
        const { data: session } = await supabase
          .from('game_sessions')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_active', true)
          .maybeSingle();

        if (session) {
          gameSession = session;
          gameStarted = true;
          currentPlayerIndex = session.current_player_index;
          isMyTurn = session.player_sequence[session.current_player_index] === userId;
          isCardRevealed = session.current_card_revealed;

          if (session.current_card_revealed) {
            const cardData = await loadCardData(room.game_mode, session.current_card);
            if (cardData) {
              currentCard = cardData;
            }
          }
        } else {
          console.log('⚠️ No active session found for playing room');
          await handleGameStateReset();
        }
      } else {
        console.log('🔄 Room not in playing state, resetting game state');
        resetGameState();
      }
    } catch (err) {
      console.error('💥 Error in syncGameState:', err);
      error = 'Failed to sync game state';
    }
  }

  // Add validation before accessing card data
  async function loadCardData(gameMode, cardIndex) {
    try {
      console.log('Loading card data:', { gameMode, cardIndex });
      
      const { data, error } = await supabase
        .from('game_cards')
        .select('*')
        .eq('game_mode', gameMode)
        .eq('card_index', cardIndex)
        .single();

      if (error) {
        console.error('Error loading card:', error);
        throw error;
      }

      console.log('Card data loaded:', data);
      return data;
    } catch (err) {
      console.error('Error in loadCardData:', err);
      error = 'Failed to load card';
      return null;
    }
  }

  // Add game completion check function
  async function checkGameCompletion() {
    if (!gameSession) return false;
    
    const isLastCard = gameSession.current_card_index >= gameSession.card_sequence.length - 1;
    
    if (isLastCard && isMyTurn) { // Only admin updates the room status
      try {
        isLoading = true;
        
        // Update game session to inactive
        const { error: sessionError } = await supabase
          .from('game_sessions')
          .update({ 
            is_active: false,
            last_update: new Date().toISOString()
          })
          .eq('id', gameSession.id);

        if (sessionError) throw sessionError;

        // Update room status to trigger all clients
        const { error: roomError } = await supabase
          .from('rooms')
          .update({ 
            status: 'waiting',
            game_session_id: null
          })
          .eq('id', roomId);

        if (roomError) throw roomError;
        
        return true;
      } catch (err) {
        console.error('Error handling game completion:', err);
        error = 'Error ending game session';
        return false;
      } finally {
        isLoading = false;
      }
    }
    
    return false;
  }

  // Add a helper function to get remaining cards
  function getRemainingCards() {
    if (!gameSession) return 0;
    return gameSession.card_sequence.length - gameSession.current_card_index;
  }

  // Update the reactive statement for card count
  $: if (selectedGameMode || roomData?.game_mode) {
    getCardCount(selectedGameMode || roomData?.game_mode).then(count => {
      currentCardCount = count;
      console.log(`${selectedGameMode || roomData?.game_mode} has ${count} cards available`);
    });
  }

  // Update the game session subscription to handle status changes
  onMount(() => {
    const gameSubscription = supabase
      .channel('game_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'game_sessions',
        filter: `room_id=eq.${roomId}`
      }, async (payload) => {
        console.log('Game session changed:', payload);
        await syncGameState();
      })
      .subscribe();

    return () => {
      gameSubscription?.unsubscribe();
    };
  });

  // Add subscription for room status changes
  onMount(() => {
    const roomSubscription = supabase
      .channel('room_status')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'rooms',
        filter: `id=eq.${roomId}`
      }, async (payload) => {
        console.log('Room status changed:', payload);
        if (payload.new.status === 'waiting') {
          // Game has ended, reset local state
          await handleGameEnd();
        }
        roomData = payload.new;
      })
      .subscribe();

    return () => {
      roomSubscription?.unsubscribe();
    };
  });

  // Add function to handle game end for all players
  async function handleGameEnd() {
    try {
      isLoading = true;
      
      if (!gameSession?.id) {
        console.error('No active game session to end');
        return;
      }

      // Deactivate the game session
      const { error: sessionError } = await supabase
        .from('game_sessions')
        .update({ 
          is_active: false,
          last_update: new Date().toISOString()
        })
        .eq('id', gameSession.id);

      if (sessionError) throw sessionError;

      // Reset room status to waiting
      const { error: roomError } = await supabase
        .from('rooms')
        .update({ 
          status: 'waiting',
          game_session_id: null
        })
        .eq('id', roomId);

      if (roomError) throw roomError;

      // Reset all players to not ready
      const { error: playersError } = await supabase
        .from('players')
        .update({ is_ready: false })
        .eq('room_id', roomId);

      if (playersError) throw playersError;

      // Reset local state
      resetGameState();
      successMessage = 'Game completed! All cards have been played. Ready for a new game!';
      error = null;

    } catch (err) {
      console.error('Error ending game:', err);
      error = 'Failed to end game properly';
    } finally {
      isLoading = false;
    }
  }

  // Add function to check for existing active session
  async function checkExistingSession(roomId) {
    try {
      const { data, error } = await supabase
        .from('game_sessions')
        .select('*')
        .eq('room_id', roomId)
        .eq('is_active', true)
        .maybeSingle();

      if (error) throw error;
      return data;
    } catch (err) {
      console.error('Error checking existing session:', err);
      return null;
    }
  }

  // Add helper function to check if current card is last
  function isLastCard() {
    return gameSession?.current_card_index === (gameSession?.card_sequence?.length - 1);
  }

  // Initialize selectedGameMode when roomData is loaded
  $: if (roomData?.game_mode && !selectedGameMode) {
    selectedGameMode = roomData.game_mode;
  }

  async function handleGameModeChange(newGameMode) {
    try {
      // If the game mode is different from current, reset admin's ready state
      if (newGameMode !== roomData.game_mode && userId === roomData.admin_id) {
        // Reset admin's ready state
        const { error: readyError } = await supabase
          .from('players')
          .update({ is_ready: false })
          .eq('user_id', userId)
          .eq('room_id', roomId);

        if (readyError) throw readyError;
        
        // Update local ready state
        isReady = false;
      }
      
      // Update selected game mode
      selectedGameMode = newGameMode;
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
      const { error: updateError } = await supabase
        .from('rooms')
        .update({ 
          game_mode: selectedGameMode,
          status: 'waiting',
          game_session_id: null
        })
        .eq('id', roomId);

      if (updateError) throw updateError;

      // Force reload room data to ensure clean state
      const { data: freshRoomData, error: roomError } = await supabase
        .from('rooms')
        .select('*')
        .eq('id', roomId)
        .single();

      if (roomError) throw roomError;

      // Update local state
      roomData = freshRoomData;
      selectedGameMode = freshRoomData.game_mode;

      console.log('Game mode updated successfully:', selectedGameMode);

    } catch (err) {
      console.error('Error updating game mode:', err);
      error = 'Failed to update game mode';
      // Revert selection on error
      selectedGameMode = roomData?.game_mode;
    } finally {
      isLoading = false;
    }
  }

  // Add reactive statement for game mode updates
  $: {
    if (roomData?.game_mode) {
      console.log('Reactive: Setting game mode to:', roomData.game_mode);
      currentGameMode.set(roomData.game_mode);
      getCardCount(roomData.game_mode).then(count => {
        currentCardCount = count;
      });
    }
  }

  // At the top of your script, add a room subscription alongside the players subscription
  onMount(async () => {
    try {
      // Load initial data
      const initialRoom = await loadRoom();
      if (!initialRoom) throw new Error('Failed to load room');

      // Set initial states
      roomData = initialRoom;
      selectedGameMode = initialRoom.game_mode;
      currentGameMode.set(initialRoom.game_mode);

      // Setup single subscription for all changes
      const subscription = await setupSubscriptions();
      
      // Store subscription for cleanup
      gameSubscription = subscription;

    } catch (err) {
      console.error('Error in component initialization:', err);
      error = 'Failed to initialize room';
    }
  });

  // Update handleGameStart function
  async function handleGameStart() {
    console.log('🎮 Starting game initialization...');
    try {
      // Set room to starting state first
      const { error: startingError } = await supabase
        .from('rooms')
        .update({ status: 'starting' })
        .eq('id', roomId)
        .eq('status', 'waiting');

      if (startingError) {
        console.error('Failed to set starting state:', startingError);
        return false;
      }

      // Generate card sequence
      const cardSequence = await generateCardSequence(roomData.game_mode);
      if (!cardSequence?.length) {
        throw new Error('Failed to generate card sequence');
      }

      // Create session parameters
      const sessionParams = {
        p_room_id: roomId,
        p_card_sequence: cardSequence,
        p_player_sequence: players.map(p => p.user_id),
        p_started_at: new Date().toISOString()
      };

      // Create new session using RPC
      const { data: newSession, error: sessionError } = await supabase.rpc(
        'create_game_session_safe',
        sessionParams
      );

      if (sessionError || !newSession) {
        throw new Error('Failed to create game session');
      }

      // Update local state
      gameSession = newSession;
      gameStarted = true;
      currentPlayerIndex = 0;
      isMyTurn = sessionParams.p_player_sequence[0] === userId;
      isCardRevealed = false;
      currentCard = null;

      return true;
    } catch (err) {
      console.error('💥 Error in handleGameStart:', err);
      // Reset room status on error
      await supabase
        .from('rooms')
        .update({ status: 'waiting' })
        .eq('id', roomId);
      return false;
    }
  }

  // Add this helper function if not already present
  async function loadCurrentCard() {
    console.log('📥 Loading current card...');
    if (!gameSession?.card_sequence || !roomData?.game_mode) return null;

    const currentCardIndex = gameSession.current_card_index;
    const cardIndexInSequence = gameSession.card_sequence[currentCardIndex];

    const { data, error } = await supabase
      .from('game_cards')
      .select('*')
      .eq('game_mode', roomData.game_mode)
      .eq('card_index', cardIndexInSequence)
      .single();

    if (error) {
      console.error('❌ Failed to load card:', error);
      return null;
    }

    console.log('✅ Card loaded:', data);
    return data;
  }

  async function handleGameStateReset() {
    console.log('🔄 Resetting game state...');
    try {
      // Reset local state
      gameStarted = false;
      isStartingGame = false;
      currentCard = null;
      isMyTurn = false;
      currentPlayerIndex = 0;
      isCardRevealed = false;
      gameSession = null;

      // Reset database state
      const { error: roomError } = await supabase
        .from('rooms')
        .update({ 
          status: 'waiting',
          game_session_id: null 
        })
        .eq('id', roomId);

      if (roomError) throw roomError;

      // Reset player ready states
      const { error: playerError } = await supabase
        .from('players')
        .update({ is_ready: false })
        .eq('room_id', roomId);

      if (playerError) throw playerError;

      console.log('✅ Game state reset complete');

    } catch (err) {
      console.error('💥 Error resetting game state:', err);
      error = 'Failed to reset game state';
    }
  }
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
                      on:click={() => $currentGameState.isDrawPhase && handleCardReveal()}
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
                                      <div 
                                        class="stacked-card" 
                                        style="--delay: {i * 150}ms; --offset: {i * 4}px"
                                      />
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
            on:click={() => showLeaveConfirm = true}
          >
            Leave Game
          </Button>
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
            <div class="text-center space-y-3">
              {#if roomData?.game_mode && gameModes[roomData.game_mode]}
                {#if userId === roomData?.admin_id && !gameStarted}
                  <div class="space-y-4">
                    <Label class="text-foreground/80">Game Mode</Label>
                    <div class="grid grid-cols-1 gap-4">
                      {#each Object.entries(gameModes) as [id, mode]}
                        <div class="space-y-2">
                          <button
                            type="button"
                            class="w-full relative flex items-center p-4 cursor-pointer rounded-lg border border-input bg-background hover:bg-accent/5 transition-colors
                              {selectedGameMode === id ? 'border-primary ring-2 ring-ring' : ''}"
                            on:click={() => handleGameModeChange(id)}
                            disabled={isLoading || gameStarted}
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

                    <!-- Update card count display -->
                    <p class="text-xs text-muted-foreground">
                      {currentCardCount} cards in deck
                    </p>
                    
                    <!-- Add Save button when changes are pending -->
                    {#if selectedGameMode !== roomData.game_mode}
                      <Button
                        class="w-full mt-4"
                        on:click={saveGameMode}
                        disabled={isLoading || gameStarted}
                      >
                        {isLoading ? 'Saving...' : 'Save Game Mode'}
                      </Button>
                    {/if}
                  </div>
                {:else}
                  <!-- Non-admin view -->
                  {#key roomData?.game_mode + currentCardCount}
                    <div class="text-center space-y-3" 
                      in:slide={{ duration: 200 }} 
                      out:slide={{ duration: 200 }}
                    >
                      {#if roomData?.game_mode && gameModes[roomData.game_mode]}
                        <div class="space-y-3 animate-in fade-in-50 duration-300">
                          <Badge 
                            variant="secondary" 
                            class="text-base px-4 py-1.5"
                          >
                            {#if $currentGameModeData}
                              {$currentGameModeData.name}
                            {:else}
                              {gameModes[roomData.game_mode].name}
                            {/if}
                          </Badge>
                          <p class="text-sm text-muted-foreground">
                            {#if $currentGameModeData}
                              {$currentGameModeData.description}
                            {:else}
                              {gameModes[roomData.game_mode].description}
                            {/if}
                          </p>
                          <p class="text-xs text-muted-foreground">
                            {currentCardCount} cards in deck
                          </p>
                        </div>
                      {:else}
                        <div class="animate-pulse">
                          <Badge variant="secondary" class="text-base px-4 py-1.5">
                            Loading game mode...
                          </Badge>
                        </div>
                      {/if}
                    </div>
                  {/key}
                {/if}
              {:else}
                <Badge variant="secondary" class="text-base px-4 py-1.5">
                  Loading game mode...
                </Badge>
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
              Save Game Mode Changes First
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
</style>