<script>
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';

  let roomName = '';
  let roomCode = '';
  let error = '';
  let copied = false;

  async function createRoom() {
    try {
      // Generate a random 4-digit room code
      roomCode = generateRoomCode();
      const userId = crypto.randomUUID();
      const username = localStorage.getItem('username');

      // Check if room code already exists
      const { data: existingRoom } = await supabase
        .from('rooms')
        .select('room_code')
        .eq('room_code', roomCode)
        .single();

      if (existingRoom) {
        // If code exists, try again
        return createRoom();
      }

      // Create new room
      const { data: room, error: roomError } = await supabase
        .from('rooms')
        .insert({
          room_code: roomCode,
          room_name: roomName,
          admin_id: userId,
          is_active: true
        })
        .select()
        .single();

      if (roomError) throw roomError;

      // ... rest of the create room logic ...
    } catch (err) {
      console.error('Error creating room:', err);
      error = 'Failed to create room';
    }
  }

  function generateRoomCode() {
    // Generate a random number between 1000 and 9999
    return Math.floor(1000 + Math.random() * 9000).toString();
  }
  async function copyToClipboard() {
    try {
      await navigator.clipboard.writeText(roomCode);
      copied = true;
      setTimeout(() => copied = false, 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  }

  function startGame() {
    goto(`/room/${roomCode}`);
  }
</script>

<div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white">
  <h1 class="text-4xl font-bold mb-8">Create Room</h1>
  
  {#if !roomCode}
    <div class="w-full max-w-md">
      <input
        type="text"
        placeholder="Enter Room Name"
        bind:value={roomName}
        class="w-full px-4 py-3 rounded-lg bg-gray-700 text-white mb-4"
      />
      
      {#if error}
        <p class="text-red-500 text-sm mb-4">{error}</p>
      {/if}

      <button
        on:click={createRoom}
        class="w-full bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-md"
        disabled={!roomName}
      >
        Create Room
      </button>
    </div>
  {:else}
    <div class="text-center">
      <h2 class="text-2xl mb-4">Room Created!</h2>
      <div class="text-6xl font-bold mb-6">{roomCode}</div>
      
      <div class="space-y-4">
        <button
          on:click={copyToClipboard}
          class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-md w-full"
        >
          Copy Room Code
        </button>

        {#if copied}
          <div class="text-green-400">Room code copied!</div>
        {/if}

        <button
          on:click={startGame}
          class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-md w-full mt-4"
        >
          Start Game
        </button>
      </div>
    </div>
  {/if}
</div>