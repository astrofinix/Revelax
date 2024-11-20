<!-- src/routes/username.svelte -->
<script>
    import { goto } from '$app/navigation'; // Import the navigation function from SvelteKit
    let username = '';
    let errorMessage = '';
    let isSubmitEnabled = false;
  
    // Get the room action (create or join) from localStorage
    let roomAction = localStorage.getItem('roomAction') || '';
  
    // Validate username: only letters and numbers, between 2 and 20 characters
    function validateUsername() {
      const regex = /^[a-zA-Z0-9]{2,20}$/;
      if (regex.test(username)) {
        errorMessage = ''; // Clear any previous error
        isSubmitEnabled = true;
      } else {
        errorMessage = 'Username must be between 2 and 20 characters, and only letters and numbers are allowed.';
        isSubmitEnabled = false;
      }
    }
  
    // Handle username submission
    function handleSubmit() {
      if (isSubmitEnabled) {
        // Navigate to the appropriate room page based on the stored action
        if (roomAction === 'create') {
          goto('/create-room');
        } else if (roomAction === 'join') {
          goto('/join-room');
        }
      }
    }
  </script>
  
  <div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white">
    <h1 class="text-4xl font-bold mb-8">Create Your Username</h1>
    
    <!-- Username Input -->
    <input
      type="text"
      bind:value={username}
      on:input={validateUsername}
      placeholder="Enter your username"
      class="bg-gray-700 text-white px-4 py-2 rounded-md mb-4"
    />
    
    <!-- Error Message -->
    {#if errorMessage}
      <p class="text-red-500 text-center mb-4">{errorMessage}</p>
    {/if}
  
    <!-- Submit Button -->
    <button
      on:click={handleSubmit}
      class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-md"
      disabled={!isSubmitEnabled}
    >
      Submit
    </button>
  </div>
  