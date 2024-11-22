<script>
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';

  let inviteCode = '';
  let error = '';
  let isLoading = false;

  function log(message, type = 'info') {
    const styles = {
      info: '📘 [join-room]',
      error: '🔴 [join-room]',
      success: '✅ [join-room]'
    };
    console.log(`${styles[type]} ${message}`);
  }

  function validateInviteCode(code) {
    // Check if code is 4 digits
    const codeRegex = /^\d{4}$/;
    return codeRegex.test(code);
  }

  async function handleJoin() {
    try {
      error = '';
      isLoading = true;

      // Validate invite code format
      if (!validateInviteCode(inviteCode)) {
        error = 'Invalid code format. Please enter 4 digits.';
        log(`Invalid code format: ${inviteCode}`, 'error');
        return;
      }

      // Check if user has username
      const username = localStorage.getItem('username');
      if (!username) {
        log('No username found, redirecting to username page', 'error');
        localStorage.setItem('roomAction', 'join');
        goto('/username');
        return;
      }

      log(`Checking room code: ${inviteCode}`, 'info');

      // Check if room exists and is active
      const { data: room, error: roomError } = await supabase
        .from('rooms')
        .select('id, room_name, is_active')
        .eq('room_code', inviteCode)
        .single();

      if (roomError || !room) {
        error = 'Room not found. Please check the code.';
        log('Room not found', 'error');
        return;
      }

      if (!room.is_active) {
        error = 'This room is no longer active.';
        log('Room is inactive', 'error');
        return;
      }

      // Create player entry
      const userId = crypto.randomUUID();
      const { error: playerError } = await supabase
        .from('players')
        .insert({
          room_id: room.id,
          user_id: userId,
          username: username,
          is_connected: true
        });

      if (playerError) {
        throw playerError;
      }

      log('Successfully joined room', 'success');

      // Store data for lobby
      localStorage.setItem('userId', userId);
      localStorage.setItem('roomId', room.id);
      localStorage.setItem('currentRoomCode', inviteCode);

      // Redirect to lobby
      goto('/lobby');

    } catch (err) {
      log(`Error: ${err.message}`, 'error');
      error = 'Failed to join room. Please try again.';
    } finally {
      isLoading = false;
    }
  }

  function goToCreateRoom() {
    log('Redirecting to create room page', 'info');
    goto('/create-room');
  }
</script>

<div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white p-4">
  <h1 class="text-2xl font-bold mb-8">Join Room</h1>

  <div class="w-full max-w-md space-y-6">
    <!-- Invite code input -->
    <div class="space-y-2">
      <label for="inviteCode" class="block text-sm font-medium">
        Enter 4-Digit Room Code
      </label>
      <input
        id="inviteCode"
        type="text"
        placeholder="Enter room code"
        bind:value={inviteCode}
        maxlength="4"
        disabled={isLoading}
        class="w-full px-4 py-3 rounded-lg bg-gray-700 text-white border border-gray-600 focus:border-blue-500 outline-none text-center text-2xl tracking-widest"
      />
    </div>

    <!-- Error message -->
    {#if error}
      <p class="text-red-500 text-sm p-2 bg-red-500/10 rounded">
        {error}
      </p>
    {/if}

    <!-- Join button -->
    <button
      on:click={handleJoin}
      disabled={!inviteCode || isLoading}
      class="w-full bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
    >
      {#if isLoading}
        Joining Room...
      {:else}
        Join Room
      {/if}
    </button>

    <!-- Create room link -->
    <div class="text-center">
      <p class="text-gray-400">Want to create your own room?</p>
      <button
        on:click={goToCreateRoom}
        class="text-blue-400 hover:text-blue-300 font-medium mt-2"
      >
        Click here
      </button>
    </div>
  </div>
</div>