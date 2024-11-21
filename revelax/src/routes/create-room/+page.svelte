<script>
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  let roomName = '';
  let selectedMode = 'yap_sesh'; // default mode
  let error = '';
  let isLoading = false;

  const gameModes = [
    { id: 'fil_chill', name: 'The Filipino Chillnuman' },
    { id: 'yap_sesh', name: 'Yap Session' },
    { id: 'night_talk', name: 'Deep Night Talks' }
  ];

  function log(message, type = 'info') {
    const styles = {
      info: '📘 [create-room]',
      error: '🔴 [create-room]',
      success: '✅ [create-room]'
    };
    console.log(`${styles[type]} ${message}`);
  }

  onMount(() => {
    const username = localStorage.getItem('username');
    if (!username) {
      log('No username found, redirecting to username page', 'error');
      localStorage.setItem('roomAction', 'create');
      goto('/username');
    }
  });

  function validateRoomName(name) {
    const alphanumericRegex = /^[a-zA-Z0-9\s]{3,20}$/;
    return alphanumericRegex.test(name);
  }

  function generateRoomCode() {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  async function handleSubmit() {
    try {
      if (!validateRoomName(roomName)) {
        error = 'Room name must be 3-20 alphanumeric characters';
        log(`Invalid room name: ${roomName}`, 'error');
        return;
      }

      isLoading = true;
      const username = localStorage.getItem('username');
      const roomCode = generateRoomCode();
      const userId = crypto.randomUUID();

      log(`Creating room: ${roomName}, Mode: ${selectedMode}, Code: ${roomCode}`, 'info');

      // Create room in database
      const { data: room, error: roomError } = await supabase
        .from('rooms')
        .insert({
          room_code: roomCode,
          room_name: roomName.trim(),
          admin_id: userId,
          game_mode: selectedMode,
          is_active: true
        })
        .select()
        .single();

      if (roomError) throw roomError;
      log('Room created successfully', 'success');

      // Create admin player
      const { error: playerError } = await supabase
        .from('players')
        .insert({
          room_id: room.id,
          user_id: userId,
          username: username,
          is_admin: true,
          is_connected: true
        });

      if (playerError) {
        // Rollback room creation if player creation fails
        await supabase.from('rooms').delete().eq('id', room.id);
        throw playerError;
      }

      log('Admin player created successfully', 'success');

      // Store data for lobby
      localStorage.setItem('userId', userId);
      localStorage.setItem('roomId', room.id);
      localStorage.setItem('currentRoomCode', roomCode);

      log('Redirecting to lobby...', 'info');
      goto('/lobby');

    } catch (err) {
      log(`Error: ${err.message}`, 'error');
      error = 'Failed to create room. Please try again.';
    } finally {
      isLoading = false;
    }
  }
</script>

<div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white p-4">
  <h1 class="text-2xl font-bold mb-8">Create Room</h1>

  <div class="w-full max-w-md space-y-6">
    <!-- Room name input -->
    <div class="space-y-2">
      <label for="roomName" class="block text-sm font-medium">
        Room Name (3-20 alphanumeric characters)
      </label>
      <input
        id="roomName"
        type="text"
        placeholder="Enter room name"
        bind:value={roomName}
        maxlength="20"
        disabled={isLoading}
        class="w-full px-4 py-3 rounded-lg bg-gray-700 text-white border border-gray-600 focus:border-blue-500 outline-none"
      />
      <p class="text-sm text-gray-400">
        {roomName.length}/20 characters
      </p>
    </div>

    <!-- Game mode dropdown -->
    <div class="space-y-2">
      <label for="gameMode" class="block text-sm font-medium">
        Select Game Mode
      </label>
      <select
        id="gameMode"
        bind:value={selectedMode}
        disabled={isLoading}
        class="w-full px-4 py-3 rounded-lg bg-gray-700 text-white border border-gray-600 focus:border-blue-500 outline-none"
      >
        {#each gameModes as mode}
          <option value={mode.id}>
            {mode.name}
          </option>
        {/each}
      </select>
    </div>

    <!-- Error message -->
    {#if error}
      <p class="text-red-500 text-sm p-2 bg-red-500/10 rounded">
        {error}
      </p>
    {/if}

    <!-- Submit button -->
    <button
      on:click={handleSubmit}
      disabled={!roomName.trim() || isLoading}
      class="w-full bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
    >
      {#if isLoading}
        Creating Room...
      {:else}
        Create Room
      {/if}
    </button>
  </div>
</div>
