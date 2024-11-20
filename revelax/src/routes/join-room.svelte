<!-- src/routes/join-room.svelte -->
<script>
    import { goto } from '$app/navigation'; // For navigation after joining the room
  
    let roomCode = '';
    let validCode = true;
  
    function joinRoom() {
      // Simulate checking if the room code is valid
      if (roomCode.length === 6) {  // Example check for valid code length
        validCode = true;
        goto('/username');  // Navigate to the username page after joining
      } else {
        validCode = false;  // Show error if code is invalid
      }
    }
  </script>
  
  <div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white">
    <h1 class="text-4xl font-bold mb-8">Join Room</h1>
    
    <input
      type="text"
      placeholder="Enter Room Code"
      bind:value={roomCode}
      class="bg-gray-700 text-white px-4 py-2 rounded-md mb-4"
    />
    
    <button
      on:click={joinRoom}
      class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-md"
      disabled={!roomCode}
    >
      Join Room
    </button>
  
    {#if !validCode}
      <div class="mt-4 text-red-500">Invalid Room Code</div>
    {/if}
  </div>
  