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
	import * as Dialog from '$lib/components/ui/dialog';
	import { Badge } from '$lib/components/ui/badge';
	import { Users, Crown } from 'lucide-svelte';
	import { gameModes } from '$lib/config/gameModes.ts';
	import { pulseFX } from '$lib/pulse';
	import { Label } from '$lib/components/ui/label';
	import { slide } from 'svelte/transition';
	import { writable, derived } from 'svelte/store';

	let hasCurrentCard = null;
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
	let isCardRevealed = false;
	let selectedGameMode = '';
	let currentCardCount = 0;
	let currentGameMode = writable(null);
	let currentGameModeData = derived(currentGameMode, ($mode) => gameModes[$mode] || null);
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
			await Promise.all([loadPlayers(), loadGameSession()]);

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
					key: userId
				}
			}
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
				const nextAdmin = players.find((p) => p.user_id !== userId);
				if (nextAdmin) {
					await supabase.from('rooms').update({ admin_id: nextAdmin.user_id }).eq('id', roomId);
				}
			}

			// Remove player from room
			await supabase.from('players').delete().eq('user_id', userId).eq('room_id', roomId);

			if (browser) {
				localStorage.removeItem('roomId');
				localStorage.removeItem('currentRoomCode');
			}
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
				const nextAdmin = players.find((p) => p.user_id !== userId);
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
		// console.log(`🔄 Updating player status for room: ${roomId}...`);
		try {
			// Don't update if game is already started
			if (gameStarted) {
				// console.log(`⏩ Game already started for room: ${roomId}, skipping player status update`);
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
			const currentPlayer = players.find((p) => p.user_id === userId);
			if (currentPlayer) {
				isReady = currentPlayer.is_ready;
			}

			// Update ready count
			const readyCount = players.filter((p) => p.is_ready).length;
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
	// Update the subscription handler to include game end cleanup
function setupSubscriptions() {
  
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
        // Handle other updates as before
        const hasChanges = 
          payload.new.current_card_revealed !== gameSession?.current_card_revealed ||
          payload.new.current_card_content !== gameSession?.current_card_content ||
          payload.new.current_player_index !== gameSession?.current_player_index ||
          payload.new.current_card_index !== gameSession?.current_card_index;

        if (hasChanges) {
          await updateGameSession();
        }
      })
    .subscribe();

  return () => {
    supabase.removeChannel(gameSessionSubscription);
  };
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
			const currentPlayer = players.find((p) => p.user_id === userId);
			if (currentPlayer) {
				isReady = currentPlayer.is_ready;
			}

			// Update ready count
			const readyCount = players.filter((p) => p.is_ready).length;
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
				.eq('activity_status', 'active')
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
				.eq('activity_status', 'active')
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
			const cardSequence = cards.map((card) => card.card_index).sort(() => Math.random() - 0.5);

			// 4. Create player sequence (starting with admin)
			const playerSequence = players
				.sort((a, b) => {
					// Ensure admin is first
					if (a.user_id === roomData.admin_id) return -1;
					if (b.user_id === roomData.admin_id) return 1;
					return 0;
				})
				.map((player) => player.user_id);

			console.log('📊 Game setup:', {
				cardSequence,
				playerSequence,
				gameMode: roomData.game_mode
			});

			// 5. Create game session using the safe function
			const { data: session, error: sessionError } = await supabase.rpc(
				'create_game_session_safe',
				{
					p_room_id: roomId,
					p_card_sequence: cardSequence,
					p_player_sequence: playerSequence,
					p_started_at: new Date().toISOString()
				}
			);

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
			localStorage.setItem(
				'gameState',
				JSON.stringify({
					gameStarted,
					currentPlayerIndex,
					isMyTurn,
					isCardRevealed,
					gameSessionId: gameSession?.id
				})
			);
		}
	});

	async function handleCardReveal() {
		if (!isMyTurn || isCardRevealed || isLoading) return;
		isLoading = true;

		try {
			const currentCardIndex = gameSession.current_card_index;
			const cardIndexInSequence = gameSession.card_sequence[currentCardIndex];

			// 1. Fetch card content
			const { data: cardData, error: cardError } = await supabase
				.from('game_cards')
				.select('content')
				.eq('game_mode', roomData.game_mode)
				.eq('card_index', cardIndexInSequence)
				.single();

			if (cardError) throw cardError;

			// 2. Update game session with card content
			const { error: updateError } = await supabase
				.from('game_sessions')
				.update({
					current_card_revealed: true,
					current_card_content: cardData.content,
					current_card: cardIndexInSequence,
					last_update: new Date().toISOString()
				})
				.eq('id', gameSession.id);

			if (updateError) throw updateError;

			// 3. Force immediate update
			await updateGameSession();
		} catch (err) {
			console.error('Error revealing card:', err);
			error = 'Failed to reveal card';
		} finally {
			isLoading = false;
		}
	}

	// Make sure to call setupSubscriptions when the game starts
	$: if (gameStarted && gameSession?.id) {
		const cleanup = setupSubscriptions();
		onDestroy(() => {
			cleanup();
		});
	}

	// Update the reactive statement
	$: if (gameStarted) {
		const newDrawPhase = isMyTurn && !isCardRevealed;

		// Update game state store while preserving card content
		currentGameState.update((state) => {
			const updatedState = {
				...state,
				isDrawPhase: newDrawPhase,
				deckName: roomData?.game_mode || state.deckName,
				currentCardIndex: gameSession?.current_card_index || state.currentCardIndex,
				totalCards: gameSession?.card_sequence?.length || state.totalCards,
				currentCardContent: gameSession?.current_card_content // Preserve card content
			};
			
			return updatedState;
		});
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
			.on('UPDATE', (payload) => {
				gameSession = payload.new;
				updateLocalGameState();
			})
			.subscribe();

		return () => {
			supabase.removeSubscription(gameSessionSubscription);
		};
	});

	function updateLocalGameState() {
		currentCard = gameSession.current_card_revealed
			? { content: gameSession.current_card_content }
			: currentCard; // Preserve current card if it exists

		isCardRevealed = gameSession.current_card_revealed;

		currentGameState.set({
			deckName: roomData.game_mode,
			currentCardIndex: gameSession.current_card_index,
			totalCards: gameSession.card_sequence.length,
			isDrawPhase: isMyTurn && !isCardRevealed,
			currentCardContent: isCardRevealed ? gameSession.current_card_content : null
		});
	}

	async function handleGameEnd() {
  console.log('🏁 Initiating game end...');
  isLoading = true;

  try {
    // 1. First, set game session to inactive
    const { error: sessionUpdateError } = await supabase
      .from('game_sessions')
      .update({ 
        activity_status: 'ending',
        last_update: new Date().toISOString()
      })
      .eq('id', gameSession.id)
      .eq('room_id', roomId);

    if (sessionUpdateError) throw sessionUpdateError;

    // The subscription will handle the rest of the cleanup
    console.log('✅ Game session marked as ending...');

  } catch (err) {
    console.error('💥 Error ending game:', err);
    error = 'Failed to end game. Please try again.';
  } finally {
    isLoading = false;
  }
}

	async function handleEndTurn() {
		if (!isMyTurn || !isCardRevealed || isLoading) return;
		isLoading = true;

		try {
			console.log('🎮 Current game state:', {
				currentPlayerIndex,
				cardIndex: gameSession.current_card_index,
				totalPlayers: gameSession.player_sequence.length,
				totalCards: gameSession.card_sequence.length
			});

			if (isLastCard()) {
				await handleGameEnd();
				return;
			}

			const nextPlayerIndex = (currentPlayerIndex + 1) % gameSession.player_sequence.length;
			const nextCardIndex = gameSession.current_card_index + 1;

			// Validate indices before update
			if (nextCardIndex >= gameSession.card_sequence.length) {
				console.error('❌ Invalid next card index:', nextCardIndex);
				throw new Error('Invalid card index');
			}

			// Get the next card from sequence
			const nextCardInSequence = gameSession.card_sequence[nextCardIndex];

			console.log('🔄 Updating to next turn:', {
				nextPlayerIndex,
				nextCardIndex,
				nextCardInSequence
			});

			// Update game session with only existing columns
			const { error: updateError } = await supabase
				.from('game_sessions')
				.update({
					current_player_index: nextPlayerIndex,
					current_card_index: nextCardIndex,
					current_card: nextCardInSequence,
					current_card_content: null,
					current_card_revealed: false,
					last_update: new Date().toISOString()
				})
				.eq('id', gameSession.id);

			if (updateError) {
				console.error('💥 Update error details:', updateError);
				throw updateError;
			}

			// Update local state
			currentPlayerIndex = nextPlayerIndex;
			isMyTurn = gameSession.player_sequence[nextPlayerIndex] === userId;
			isCardRevealed = false;
			currentCard = null;

			// Update game state store
			currentGameState.set({
				deckName: roomData?.game_mode,
				currentCardIndex: nextCardIndex,
				totalCards: gameSession.card_sequence.length,
				isDrawPhase: isMyTurn,
				currentCardContent: null
			});

			console.log('✅ Turn ended successfully');
		} catch (err) {
			console.error('💥 Error ending turn:', err);
			error = 'Failed to end turn. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	async function updateGameSession() {
		try {
			// 1. First check if session is still active and game status
			const { data: sessionStatus, error: statusError } = await supabase
				.from('game_sessions')
				.select('activity_status, started_at')
				.eq('id', gameSession.id)
				.single();

			// Get current game session state
			const { data: currentSession, error: sessionError } = await supabase
				.from('game_sessions')
				.select('*')
				.eq('id', gameSession.id)
				.single();

			console.log('🔄 Current game session:', currentSession);
			if (sessionError) throw sessionError;

			// Update local state based on session
			gameSession = currentSession;
			currentPlayerIndex = currentSession.current_player_index;
			isMyTurn = currentSession.player_sequence[currentSession.current_player_index] === userId;
			isCardRevealed = currentSession.current_card_revealed;
						// Only trigger cleanup if:
			// 1. Session exists
			// 2. Session is inactive
			// 3. Game has already started (gameStarted is true)
			// 4. It's been more than a few seconds since session started (to avoid cleanup during game initialization)
			if (sessionStatus && 
				sessionStatus.activity_status === 'ending' && 
				gameStarted && 
				sessionStatus.started_at && 
				(new Date() - new Date(sessionStatus.started_at)) > 10000) {
				handleGameEndCleanup();
				return;
			}
			// Always update card content when it exists
			if (currentSession.current_card_content) {
				currentCard = {
					content: currentSession.current_card_content
				};
			}

			// Update game state store
			currentGameState.set({
				deckName: roomData?.game_mode,
				currentCardIndex: currentSession.current_card_index,
				totalCards: currentSession.card_sequence.length,
				isDrawPhase: isMyTurn && !currentSession.current_card_revealed,
				currentCardContent: currentSession.current_card_content
			});
		} catch (err) {
			console.error('💥 Error updating game session:', err);
			throw err;
		}
	}

	// Update the reactive statement for game state changes
	$: if (gameStarted && gameSession?.id) {
		// Force update when game state changes
		updateGameSession();
	}

	async function handleGameEndCleanup() {
  try {
    // First, check if cleanup has already been performed
    const { data: currentRoom } = await supabase
      .from('rooms')
      .select('status, game_session_id')
      .eq('id', roomId)
      .single();

    // If room is already in 'waiting' state and has no game session, cleanup was already done
    if (currentRoom.status === 'waiting' && !currentRoom.game_session_id) {
      console.log('✨ Cleanup already performed, skipping database operations');
      
      // Still reset local state
      gameStarted = false;
      gameSession = null;
      currentCard = null;
      isMyTurn = false;
      isCardRevealed = false;
      currentPlayerIndex = 0;
      isReady = false;

      // Reset game state store
      currentGameState.set({
        deckName: '',
        currentCardIndex: 0,
        totalCards: 0,
        isDrawPhase: false,
        currentCardContent: null
      });
	  
      // Redirect to lobby
      goto(`/lobby`);
      return;
    }

    // If cleanup hasn't been performed, do it now
    const { error: playersError } = await supabase
      .from('players')
      .update({ 
        is_ready: false,
        last_updated: new Date().toISOString()
      })
      .eq('room_id', roomId);

    if (playersError) throw playersError;

    // Update room status and remove game session reference
    const { error: roomError } = await supabase
      .from('rooms')
      .update({
        status: 'waiting',
        game_session_id: null,
        game_mode: roomData.game_mode // Preserve the current game mode
      })
      .eq('id', roomId);

    if (roomError) throw roomError;

    // Delete the inactive game session
    const { error: sessionError } = await supabase
      .from('game_sessions')
      .delete()
      .eq('id', gameSession.id)
      .eq('room_id', roomId);

    if (sessionError) throw sessionError;

    // Reset all local state
    gameStarted = false;
    gameSession = null;
    currentCard = null;
    isMyTurn = false;
    isCardRevealed = false;
    currentPlayerIndex = 0;
    isReady = false;

    // Reset game state store
    currentGameState.set({
      deckName: '',
      currentCardIndex: 0,
      totalCards: 0,
      isDrawPhase: false,
      currentCardContent: null
    });

    // Force a refresh of the players' status
    await loadPlayers();

    // Redirect to lobby
    goto(`/lobby`);

    console.log('✅ Game end cleanup completed successfully');

  } catch (err) {
    console.error('💥 Error in game end cleanup:', err);
  }
}
	// Add new function to handle game end for all players
async function handleGameEndForAll() {
  console.log('🏁 Handling game end for all players...');
  try {
    // Reset local state
    gameStarted = false;
    gameSession = null;
    currentCard = null;
    isMyTurn = false;
    isCardRevealed = false;
    currentPlayerIndex = 0;
    isReady = false;

    // Reset game state store
    currentGameState.set({
      deckName: '',
      currentCardIndex: 0,
      totalCards: 0,
      isDrawPhase: false,
      currentCardContent: null
    });

    // Force a refresh of the players' status
    await loadPlayers();
    
    // Navigate back to lobby
    console.log('🔄 Redirecting to lobby...');
    goto(`/lobby`);

  } catch (err) {
    console.error('💥 Error in handleGameEndForAll:', err);
    error = 'Failed to end game properly. Please refresh the page.';
  }
}
</script>

<!-- Content -->
<div class="relative min-h-screen w-full bg-background">
	<!-- Animated Background -->
	<div class="absolute inset-0 h-full w-full">
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
				<animateTransform
					attributeName="transform"
					type="rotate"
					from="360 50 50"
					to="0 50 50"
					dur="19s"
					repeatCount="indefinite"
				/>
			</rect>
			<rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient1)">
				<animate attributeName="x" dur="20s" values="25%;0%;25%" repeatCount="indefinite" />
				<animate attributeName="y" dur="21s" values="0%;25%;0%" repeatCount="indefinite" />
				<animateTransform
					attributeName="transform"
					type="rotate"
					from="0 50 50"
					to="360 50 50"
					dur="17s"
					repeatCount="indefinite"
				/>
			</rect>
			<rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient2)">
				<animate attributeName="x" dur="23s" values="-25%;0%;-25%" repeatCount="indefinite" />
				<animate attributeName="y" dur="24s" values="0%;50%;0%" repeatCount="indefinite" />
				<animateTransform
					attributeName="transform"
					type="rotate"
					from="0 50 50"
					to="360 50 50"
					dur="18s"
					repeatCount="indefinite"
				/>
			</rect>
		</svg>
	</div>

	<!-- Main Content -->
	<div class="relative z-10 flex min-h-screen items-center justify-center p-4">
		{#if gameStarted}
			<!-- Game Card -->
			<Card.Root class="w-full max-w-md border border-border bg-card/95 backdrop-blur-lg">
				<Card.Header class="space-y-4">
					<Card.Title class="text-center text-2xl font-bold">
						{roomData?.room_name || 'Loading...'}
					</Card.Title>

					<!-- Current Card Display -->
					{#if currentCard}
						<div class="card-container mx-auto flex w-full max-w-xl items-center justify-center">
							<div class="w-full space-y-4">
								<!-- Deck info and turn indicator -->
								<div class="mb-4 flex flex-col gap-2">
									<div class="flex items-center justify-between px-2 text-sm text-muted-foreground">
										<span>Deck: {gameModes[roomData?.game_mode]?.name}</span>
										<span>
											Card {gameSession?.current_card_index + 1}/{gameSession?.card_sequence
												?.length}
											{#if isLastCard()}
												<span class="font-medium text-orange-500">(Final Card!)</span>
											{/if}
										</span>
									</div>
								</div>

								<!-- Card -->
								<div class="card-content relative h-full w-full">
									<div class="game-card-container relative aspect-[3/4] w-full">
										<button
											type="button"
											class="game-card h-full w-full {$currentGameState.isDrawPhase
												? 'active'
												: ''}"
											on:click={() => $currentGameState.isDrawPhase && handleCardReveal()}
											disabled={!$currentGameState.isDrawPhase || isLoading}
										>
											<!-- Base card -->
											<div class="card-base absolute inset-0">
												<div
													class="flex h-full flex-col items-center justify-center p-8 text-center space-y-4"
												>
													{#if $currentGameState.isDrawPhase}
														<div class="text text-2xl font-semibold text-primary">
															<span class="text-bottom">Your Turn!</span>
															<span class="text-top">Your Turn!</span>
														</div>
														<div class="text text-lg text-muted-foreground">
															<span class="text-bottom">Click to Draw Card</span>
															<span class="text-top">Click to Draw Card</span>
														</div>
													{:else if !gameSession?.current_card_revealed}
													<div class="loading-card-state space-y-6">
														<div class="loading-animation">
														  <div class="card-stack">
															{#each Array(3) as _, i}
															  <!-- svelte-ignore element_invalid_self_closing_tag -->
															  <div 
																class="stacked-card" 
																style="--delay: {i * 150}ms; --offset: {i * 4}px"
															  />
															{/each}
														  </div>
														</div>
														<div class="text text-lg text-muted-foreground">
															<span class="text-bottom">
																Waiting for {players[currentPlayerIndex]?.username}'s move...</span>
															<span class="text-top">
																Waiting for {players[currentPlayerIndex]?.username}'s move...</span>
														</div>
													  </div>
													{/if}
												</div>
											</div>

											<!-- Question card (visible to all when revealed) -->
											{#if gameSession?.current_card_revealed}
												<div
													class="question-card absolute inset-0 transform transition-all duration-300"
													
													class:active={gameSession?.current_card_revealed}
												>
													<div
														class="flex h-full flex-col items-center justify-center p-8 text-center"
													>
														<div
															class="card-content-wrapper mx-auto max-w-sm rounded-xl bg-card/50 p-6 backdrop-blur-sm"
														>
															<p class="text-2xl font-medium leading-relaxed text-primary">
																{gameSession.current_card_content}
															</p>
														</div>
													</div>
												</div>
											{/if}
										</button>
									</div>
								</div>

								<!-- Add End Turn button after the card -->
								{#if isMyTurn && gameSession?.current_card_revealed}
									<div class="mt-4 flex justify-center" transition:slide>
										<Button
											variant="default"
											class="w-full max-w-xs"
											on:click={handleEndTurn}
											disabled={isLoading}
										>
											{#if isLoading}
												Loading...
											{:else if isLastCard()}
												End Game (Final Card)
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
					<div class="space-y-4 text-center">
						<div class="flex items-center justify-center gap-2">
							<span class="text-sm text-muted-foreground">Current Turn:</span>
							<Badge variant={isMyTurn ? 'default' : 'outline'} class="text-base">
								{players[currentPlayerIndex]?.username || 'Loading...'}
								{isMyTurn ? ' (You)' : ''}
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
								<div class="flex items-center justify-between rounded-lg bg-accent/50 p-2">
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
						on:click={() => (showLeaveConfirm = true)}
					>
						Leave Game
					</Button>
				</Card.Footer>
			</Card.Root>
		{:else}
			<!-- Original Lobby Card -->
			<Card.Root class="w-full max-w-md border border-border bg-card/95 backdrop-blur-lg">
				<Card.Header>
					<Card.Title class="text-center text-3xl font-bold text-card-foreground">Lobby</Card.Title>

					<!-- Room Info -->
					<div class="flex flex-col items-center gap-2">
						<h2 class="text-xl font-semibold text-foreground">
							{roomData?.room_name || 'Loading...'}
						</h2>

						<Badge variant="outline" class="bg-background/50 px-4 py-1.5 text-lg">
							Room Code: {roomCode}
							<Button
								variant="ghost"
								size="icon"
								class="ml-2 h-6 w-6 hover:text-primary"
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
							<Label class="text-foreground/80">Game Mode</Label>
							{#if roomData}
								{#if userId === roomData.admin_id}
									<div class="grid grid-cols-1 gap-4">
										{#each Object.entries(gameModes) as [id, mode]}
											<div class="space-y-2">
												<button
													type="button"
													class="relative flex w-full cursor-pointer items-center rounded-lg border border-input bg-background p-4 transition-colors hover:bg-accent/5
                            {selectedGameMode === id ? 'border-primary ring-2 ring-ring' : ''}"
													on:click={() => handleGameModeChange(id)}
												>
													<div class="flex items-center gap-2 font-medium">
														{mode.name}
													</div>
												</button>

												{#if selectedGameMode === id}
													<div
														class="rounded-md bg-muted/30 px-4 py-2 text-sm text-muted-foreground"
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
											class="mt-2 w-full"
											on:click={saveGameMode}
											disabled={isLoading}
										>
											Save Game Mode
										</Button>
									{/if}
								{:else}
									<div class="space-y-2">
										<div class="rounded-lg border border-input bg-background p-4">
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
												class="rounded-md bg-muted/30 px-4 py-2 text-sm text-muted-foreground"
												transition:slide={{ duration: 200 }}
											>
												{gameModes[roomData.game_mode]?.description ||
													'Mode description not available'}
											</div>
										{/key}
									</div>
								{/if}
							{:else}
								<div class="rounded-lg border border-input bg-background p-4">
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
					<div class="max-h-[200px] space-y-2 overflow-y-auto pr-2">
						{#each players as player}
							<div
								class="flex items-center justify-between rounded-lg p-3 transition-all duration-200
                        {player.user_id === userId
									? 'border border-primary/30 bg-primary/20'
									: 'bg-accent hover:bg-accent/80'}"
							>
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
									variant={player.is_ready ? 'success' : 'secondary'}
									class="animate-in fade-in-50 text-xs duration-300"
								>
									{player.is_ready ? '✓ Ready' : '⋯ Waiting'}
								</Badge>
							</div>
						{/each}
					</div>

					<!-- Error Display -->
					{#if error}
						<div
							class="animate-in fade-in-50 rounded-md p-3 text-sm {error.includes('copied')
								? 'border border-emerald-500/30 bg-emerald-500/20 text-emerald-300'
								: 'border border-red-500/30 bg-red-500/20 text-red-300'}"
						>
							{error}
						</div>
					{/if}
				</Card.Content>

				<Card.Footer class="flex flex-col gap-2">
					<Button
						variant="default"
						size="lg"
						class="w-full {isReady ? 'bg-primary hover:bg-primary/90' : ''}"
						disabled={isLoading ||
							(userId === roomData?.admin_id && selectedGameMode !== roomData?.game_mode)}
						on:click={toggleReady}
					>
						{#if isLoading}
							<span class="animate-pulse">Loading...</span>
						{:else if players.length < 2}
							<Users class="mr-2 h-5 w-5" />
							Waiting for Players ({players.length}/2)
						{:else if userId === roomData?.admin_id && selectedGameMode !== roomData?.game_mode}
							Finalize Game Mode
						{:else if isReady && players.every((p) => p.is_ready)}
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
						on:click={() => (showLeaveConfirm = true)}
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
	<Dialog.Content class="border-border bg-background">
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
			<Button variant="outline" on:click={() => (showLeaveConfirm = false)}>Cancel</Button>
			<Button variant="destructive" on:click={handleLeaveRoom} disabled={isLoading}>
				{isLoading ? 'Leaving...' : 'Leave Room'}
			</Button>
		</Dialog.Footer>
	</Dialog.Content>
</Dialog.Root>

<!-- Add Player Warning Dialog -->
<Dialog.Root bind:open={showPlayerWarningDialog}>
	<Dialog.Content class="border-border bg-background">
		<Dialog.Header>
			<Dialog.Title class="text-foreground">Waiting for Players</Dialog.Title>
			<Dialog.Description class="text-muted-foreground">
				At least 2 players are required to start the game. Share this room code with your friends:
			</Dialog.Description>
		</Dialog.Header>
		<div class="space-y-4 p-4">
			<div class="flex items-center justify-between rounded-lg bg-accent p-3">
				<span class="font-mono text-lg">{roomCode}</span>
				<Button variant="ghost" size="sm" class="hover:text-primary" on:click={copyRoomCode}>
					<Copy class="h-4 w-4" />
					<span class="sr-only">Copy room code</span>
				</Button>
			</div>
			<p class="text-center text-sm text-muted-foreground">
				Current Players: {players.length}/2
			</p>
		</div>
		<Dialog.Footer>
			<Button variant="outline" on:click={() => (showPlayerWarningDialog = false)}>Cancel</Button>
		</Dialog.Footer>
	</Dialog.Content>
</Dialog.Root>

<style>
</style>