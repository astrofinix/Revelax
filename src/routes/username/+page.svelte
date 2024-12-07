<script>
  // @ts-nocheck
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';
  import { Label } from '$lib/components/ui/label';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  let username = '';
  let error = '';
  let isLoading = false;

  let sound;

  const soundFiles = {
    'snap': '/sounds/select1.wav',
    'click': '/sounds/select2.wav',
    'flip': '/sounds/paper.mp3',
    'wind': '/sounds/wind.mp3',
    'pop': '/sounds/pop.wav',
    'ping': '/sounds/ping.mp3',
    'error': '/sounds/error.mp3',
    'affirm': '/sounds/affirm.mp3'
  };

  onMount(() => {
    // Always use dark mode
    document.documentElement.classList.add('dark');

    if (typeof window !== 'undefined') {
      sound = new Audio();
    }
  });

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

  function playSound(soundName) {
    // Check if the soundName exists in the soundFiles object
    const soundPath = soundFiles[soundName];

    if (soundPath && sound) {
      // If the audio is already playing, stop it and reset to the beginning
      if (!sound.paused) {
        sound.pause();
        sound.currentTime = 0; // Reset audio to the start
      }

      // Set the new sound source and play
      sound.src = soundPath;
      sound.play().catch((error) => {
        console.error('Error playing sound: ', error);
      });
    } else {
      console.error('Sound not found or Audio not initialized: ' + soundName);
    }
  }

  async function handleSubmit() {
    try {
      isLoading = true;
      error = '';

      // Validate username
      if (!username.trim()) {
        playSound('error');
        error = 'Username is required';
        log('Empty username submitted', 'error');
        return;
      }

      if (!validateUsername(username)) {
        playSound('error');
        error = 'Username must be 2-20 alphanumeric characters only';
        log(`Invalid username format: ${username}`, 'error');
        return;
      }

      playSound("snap");

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

<div class="relative min-h-screen w-full bg-background flex items-center justify-center p-4">
  <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
    <Card.Header>
      <Card.Title class="text-3xl font-bold text-center text-card-foreground signature-font">
        Choose Your Username
      </Card.Title>
      <Card.Description class="text-center text-muted-foreground">
        Enter a username to continue
      </Card.Description>
    </Card.Header>

    <Card.Content class="space-y-4">
      <div class="space-y-2">
        <Label for="username" class="text-foreground">Username</Label>
        <Input
          id="username"
          type="text"
          placeholder="Enter username"
          bind:value={username}
          maxlength="20"
          disabled={isLoading}
          class="bg-background border-input text-foreground placeholder:text-muted-foreground"
        />
        <p class="text-sm text-muted-foreground text-right">
          {username.length}/20 characters
        </p>
      </div>

      {#if error}
        <div class="p-3 text-sm rounded-md animate-in fade-in-50 bg-red-500/20 text-red-300 border border-red-500/30">
          {error}
        </div>
      {/if}
    </Card.Content>

    <Card.Footer class="flex flex-col gap-2">
      <Button
        type="submit"
        disabled={isLoading}
        class="w-full bg-primary text-primary-foreground hover:bg-primary/90"
        variant="default"
        size="lg"
        on:click={handleSubmit}
      >
        {isLoading ? 'Saving...' : 'Continue'}
      </Button>

      <Button
        variant="outline"
        size="lg"
        class="w-full border-border text-foreground hover:bg-accent hover:text-accent-foreground"
        on:click={() => { playSound("pop"); history.back(); }}
      >
        Back
      </Button>
    </Card.Footer>
  </Card.Root>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow-x: hidden;
    background-color: hsl(var(--background));
    color: hsl(var(--foreground));
  }

  :global(.card) {
    background-color: hsl(var(--card));
    color: hsl(var(--card-foreground));
    border: 1px solid hsl(var(--border));
    animation: fadeIn 0.5s ease-out;
  }

  :global(.input) {
    background-color: hsl(var(--background));
    border-color: hsl(var(--input));
    color: hsl(var(--foreground));
  }

  :global(.input:focus) {
    outline: none;
    ring-color: hsl(var(--ring));
    border-color: hsl(var(--ring));
  }

  :global(.input::placeholder) {
    color: hsl(var(--muted-foreground));
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>

