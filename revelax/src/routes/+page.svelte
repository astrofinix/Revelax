<!-- <script lang="ts">
  import { goto } from '$app/navigation';
  import { roomStore } from '$lib/stores/roomStore';
  import { validateUsername, generateRandomUsername } from '$lib/utils/validations';

  // Icons (using Lucide icons)
  import { PlusCircle, DoorOpen } from 'lucide-svelte';

  let username = '';
  let error = '';

  function createRoom() {
    if (!username) {
      username = generateRandomUsername();
    }

    const validationResult = validateUsername(username);
    
    if (validationResult.isValid) {
      const player = {
        id: crypto.randomUUID(),
        username,
        joinedAt: new Date()
      };

      const room = roomStore.createRoom(player);
      goto(`/room/${room.inviteCode}`);
    } else {
      error = validationResult.error || 'Invalid username';
    }
  }

  function joinRoom() {
    const inviteCode = prompt('Enter Room Invite Code:');
    if (inviteCode) {
      goto(`/room/${inviteCode}`);
    }
  }
</script>

<div class="min-h-screen bg-gradient-to-br from-purple-500 to-indigo-600 bg-[#020202] flex flex-col items-center justify-center p-4">
  <div class="bg-white shadow-2xl rounded-xl p-8 w-full max-w-md text-center">
    <h1 class="text-4xl font-bold mb-8 text-indigo-700">Revelax</h1>
    
    <!-- <div class="mb-6">
      <input 
        type="text" 
        bind:value={username}
        placeholder="Your Username (Optional)" 
        class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
      />
      {#if error}
        <p class="text-red-500 text-sm mt-2">{error}</p>
      {/if}
    </div> -->

    <!-- <div class="space-y-4">
      <button 
        on:click={createRoom} 
        class="w-full flex items-center justify-center bg-indigo-600 text-white py-3 rounded-lg hover:bg-indigo-700 transition duration-300 ease-in-out"
      >
        <PlusCircle class="mr-2" />
        Create Room
      </button>

      <button 
        on:click={joinRoom}
        class="w-full flex items-center justify-center bg-green-500 text-white py-3 rounded-lg hover:bg-green-600 transition duration-300 ease-in-out"
      >
        <DoorOpen class="mr-2" />
        Join Room
      </button>
    </div>
  </div>
</div> -->


<script>
    import { goto } from '$app/navigation'; // Import the navigation function from SvelteKit
    let roomAction = ''; // To store whether the user clicked 'create' or 'join'
  
    // Handle Create Room button click
    function handleCreate() {
      roomAction = 'create';
      localStorage.setItem('roomAction', roomAction); // Store the action in localStorage
      goto('/username');
    }
  
    // Handle Join Room button click
    function handleJoin() {
      roomAction = 'join';
      localStorage.setItem('roomAction', roomAction); // Store the action in localStorage
      goto('/username');
    }
  </script>
  
  <div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white">
    <h1 class="text-4xl font-bold mb-8">Revelax</h1>
    
    <!-- Create Room Button -->
    <button
      class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-md mb-4"
      on:click={handleCreate}
    >
      Create Room
    </button>
    
    <!-- Join Room Button -->
    <button
      class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-md"
      on:click={handleJoin}
    >
      Join Room
    </button>
  </div>
  