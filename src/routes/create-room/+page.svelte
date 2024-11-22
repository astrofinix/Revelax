<script>
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';
  import { Label } from '$lib/components/ui/label';
  import * as Select from '$lib/components/ui/select';

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

<div class="relative min-h-screen w-full bg-[#020202] flex items-center justify-center p-4">
  <Card.Root class="w-full max-w-md bg-background/90">
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

      <!-- Game mode select -->
      <div class="space-y-2">
        <Label for="gameMode" class="text-foreground/80">
          Game Mode
        </Label>
        <Select.Root bind:value={selectedMode}>
          <Select.Trigger 
            id="gameMode" 
            class="w-full"
          >
            <Select.Value placeholder="Select game mode" />
          </Select.Trigger>
          <Select.Content>
            {#each gameModes as mode}
              <Select.Item value={mode.id}>{mode.name}</Select.Item>
            {/each}
          </Select.Content>
        </Select.Root>
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
        disabled={!roomName.trim() || isLoading}
        class="w-full"
        variant="default"
        size="lg"
        on:click={handleSubmit}
      >
        {isLoading ? 'Creating Room...' : 'Create Room'}
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
    background-color: #020202;
  }

  /* Add animation for the card */
  :global(.card) {
    animation: fadeIn 0.5s ease-out;
  }

  /* Override default input styles */
  :global(input::placeholder) {
    opacity: 0.5;
  }

  :global(.input:focus) {
    box-shadow: none;
    border-color: rgba(255, 255, 255, 0.2);
  }

  /* Style select component */
  :global(.select-trigger) {
    background-color: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.2);
  }

  :global(.select-content) {
    background-color: rgba(23, 23, 23, 0.95);
    border-color: rgba(255, 255, 255, 0.1);
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
