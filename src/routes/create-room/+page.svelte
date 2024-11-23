<script lang="ts">
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';
  import { Label } from '$lib/components/ui/label';
  import * as Select from '$lib/components/ui/select';
  import { gameModes } from '$lib/config/gameModes';
  import { slide } from 'svelte/transition';

  let roomName = '';
  let selectedMode = '';
  let error = '';
  let isLoading = false;

  $: console.log('Mode changed:', selectedMode);

  function handleModeChange(value: string) {
    console.log('Select value changed:', value);
    selectedMode = value;
  }

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
      log(`Attempting to create room with name: ${roomName} and mode: ${selectedMode}`, 'info');

      if (!validateRoomName(roomName)) {
        error = 'Room name must be 3-20 alphanumeric characters';
        log(`Invalid room name: ${roomName}`, 'error');
        return;
      }

      if (!selectedMode) {
        error = 'Please select a game mode';
        log('No game mode selected', 'error');
        return;
      }

      isLoading = true;
      const username = localStorage.getItem('username');
      if (!username) {
        error = 'No username found';
        log('No username found', 'error');
        return;
      }

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
          is_active: true,
          status: 'waiting'
        })
        .select()
        .single();

      if (roomError) {
        log(`Room creation error: ${roomError.message}`, 'error');
        throw new Error(roomError.message);
      }
      
      if (!room) {
        log('No room data returned', 'error');
        throw new Error('Failed to create room');
      }
      
      log('Room created successfully', 'success');

      // Create admin player
      const { error: playerError } = await supabase
        .from('players')
        .insert({
          room_id: room.id,
          user_id: userId,
          username: username,
          is_admin: true,
          is_connected: true,
          is_ready: false
        });

      if (playerError) {
        log(`Player creation error: ${playerError.message}`, 'error');
        // Clean up the room if player creation fails
        await supabase.from('rooms').delete().eq('id', room.id);
        throw new Error(playerError.message);
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
      error = err.message || 'Failed to create room. Please try again.';
    } finally {
      isLoading = false;
    }
  }
</script>

<div class="relative min-h-screen w-full bg-background flex items-center justify-center p-4">
  <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
    <Card.Header>
      <Card.Title class="text-2xl font-bold text-center text-foreground/90">
        Create Room
      </Card.Title>
      <Card.Description class="text-center text-muted-foreground/70">
        Set up your game room
      </Card.Description>
    </Card.Header>

    <Card.Content class="space-y-4">
      <!-- Room name input -->
      <div class="space-y-2">
        <Label for="roomName" class="text-foreground/80">
          Room Name
        </Label>
        <Input
          id="roomName"
          type="text"
          placeholder="Enter room name"
          bind:value={roomName}
          maxlength="20"
          disabled={isLoading}
          class="w-full"
        />
        <p class="text-sm text-muted-foreground/60 text-right">
          {roomName.length}/20 characters
        </p>
      </div>

      <!-- Game mode selection with conditional description -->
      <div class="space-y-2">
        <Label class="text-foreground/80">
          Game Mode
        </Label>
        <div class="grid grid-cols-1 gap-4">
          {#each Object.entries(gameModes) as [id, mode]}
            <div class="space-y-2">
              <button
                type="button"
                class="w-full relative flex items-center p-4 cursor-pointer rounded-lg border border-input bg-background hover:bg-accent/5 transition-colors
                  {selectedMode === id ? 'border-primary ring-2 ring-ring' : ''}"
                on:click={() => selectedMode = id}
              >
                <div class="font-medium flex items-center gap-2">
                  {mode.name}
                </div>
              </button>
              
              {#if selectedMode === id}
                <div 
                  class="text-sm text-muted-foreground px-4 py-2 bg-muted/30 rounded-md"
                  transition:slide={{ duration: 200 }}
                >
                  {mode.description}
                </div>
              {/if}
            </div>
          {/each}
        </div>
      </div>

      {#if error}
        <div class="p-3 text-sm text-destructive/90 bg-destructive/5 rounded-md border border-destructive/20">
          {error}
        </div>
      {/if}
    </Card.Content>

    <Card.Footer class="flex flex-col gap-2">
      <Button
        type="submit"
        disabled={!roomName.trim() || !selectedMode || isLoading}
        class="w-full"
        variant="default"
        size="lg"
        on:click={handleSubmit}
      >
        {#if isLoading}
          Creating Room...
        {:else}
          Create Room
        {/if}
      </Button>

      <Button
        variant="outline"
        size="lg"
        class="w-full"
        on:click={() => history.back()}
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

  :global(.select-content) {
    position: relative;
    z-index: 50;
    min-width: 8rem;
    max-height: var(--radix-select-content-available-height);
  }

  :global(.select-item[data-highlighted]) {
    background-color: hsl(var(--accent));
    color: hsl(var(--accent-foreground));
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

  @keyframes contentFadeIn {
    from {
      opacity: 0;
      transform: translateY(-4px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>