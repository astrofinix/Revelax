<script>
  import { goto } from '$app/navigation';

  let username = '';
  let error = '';
  let isLoading = false;

  function log(message, type = 'info') {
    const styles = {
      info: '📘 [username]',
      error: '🔴 [username]',
      success: '✅ [username]',
      warning: '⚠️ [username]'
    };
    console.log(`${styles[type]} ${message}`);
  }

  function validateUsername(name) {
    const alphanumericRegex = /^[a-zA-Z0-9]{2,20}$/;
    return alphanumericRegex.test(name);
  }

  async function handleSubmit() {
    try {
      isLoading = true;
      error = '';

      // Validate username
      if (!username.trim()) {
        error = 'Username is required';
        log('Empty username submitted', 'error');
        return;
      }

      if (!validateUsername(username)) {
        error = 'Username must be 2-20 alphanumeric characters only';
        log(`Invalid username format: ${username}`, 'error');
        return;
      }

      // Get previous username if exists
      const previousUsername = localStorage.getItem('username');
      if (previousUsername) {
        log(`Overwriting previous username: ${previousUsername}`, 'warning');
      }

      // Save to localStorage
      localStorage.setItem('username', username.trim());
      log(`Username saved: ${username}`, 'success');

      // Check where to redirect
      const roomAction = localStorage.getItem('roomAction');
      if (roomAction === 'create') {
        log('Redirecting to create room', 'info');
        localStorage.removeItem('roomAction');
        goto('/create-room');
      } else if (roomAction === 'join') {
        log('Redirecting to join room', 'info');
        localStorage.removeItem('roomAction');
        goto('/join-room');
      } else {
        log('Redirecting to home', 'info');
        goto('/');
      }

    } catch (err) {
      log(`Error: ${err.message}`, 'error');
      error = 'Something went wrong. Please try again.';
    } finally {
      isLoading = false;
    }
  }
</script>

<div class="min-h-screen flex flex-col justify-center items-center bg-gray-800 text-white p-4">
  <h1 class="text-2xl font-bold mb-8">Choose Your Username</h1>

  <div class="w-full max-w-md space-y-4">
    <!-- Username input -->
    <div class="space-y-2">
      <label for="username" class="block text-sm font-medium">
        Username
      </label>
      <input
        id="username"
        type="text"
        placeholder="Enter username"
        bind:value={username}
        maxlength="20"
        disabled={isLoading}
        class="w-full px-4 py-3 rounded-lg bg-gray-700 text-white border border-gray-600 focus:border-blue-500 outline-none"
      />
      <p class="text-sm text-gray-400">
        {username.length}/20 characters
      </p>
    </div>

    <!-- Error message -->
    {#if error}
      <p class="text-red-500 text-sm p-2 bg-red-500/10 rounded">
        {error}
      </p>
    {/if}

    <!-- Submit button -->
    <button
      type="submit"
      disabled={isLoading}
      class="w-full px-4 py-3 rounded-lg bg-blue-500 text-white font-medium hover:bg-blue-600 transition duration-300"
      on:click={handleSubmit}
    >
      {isLoading ? 'Saving...' : 'Save'}
    </button>
  </div>
</div>
