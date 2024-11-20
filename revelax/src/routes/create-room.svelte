<script>
  import { goto } from '$app/navigation'; // For navigation after room creation

  let roomName = '';
  let roomCode = '';
  let copied = false; // To show the notification when the code is copied

  // Simulate creating a room and generating a 4-digit code
  function createRoom() {
    // In a real app, you'd call an API to create the room
    // roomCode = Math.floor(1000 + Math.random() * 9000); // Generate a 4-digit number
    // After creating the room, navigate to the username page
    goto('/username');
  }

  // Copy the room code to clipboard
  function copyToClipboard() {
    navigator.clipboard.writeText(roomCode.toString()).then(() => {
      copied = true;
      setTimeout(() => copied = false, 2000); // Reset copied notification after 2 seconds
    });
  }
</script>

<div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white">
  <h1 class="text-4xl font-bold mb-8">Create Room</h1>
  
  <input
    type="text"
    placeholder="Enter Room Name"
    bind:value={roomName}
    class="bg-gray-700 text-white px-4 py-2 rounded-md mb-4"
  />
  
  <button
    on:click={createRoom}
    class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-md"
    disabled={!roomName}
  >
    Create Room
  </button>

  {#if roomCode}
    <!-- Display Room Code in a large font -->
    <div class="mt-8 text-6xl font-bold text-center">{roomCode}</div>

    <!-- Button to copy room code -->
    <button
      on:click={copyToClipboard}
      class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-md mt-4"
    >
      Copy Code
    </button>

    <!-- Notification when code is copied -->
    {#if copied}
      <div class="text-green-400 mt-2">Room code copied to clipboard!</div>
    {/if}
  {/if}
</div>
