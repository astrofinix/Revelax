<script>
// @ts-nocheck

  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';
  import { Label } from '$lib/components/ui/label';
  import { Separator } from '$lib/components/ui/separator';

  let inviteCode = '';
  let error = '';
  let isLoading = false;

  const MAX_PLAYERS = 8; // Define maximum players allowed

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
        localStorage.setItem('pendingRoomCode', inviteCode); // Save the code
        goto('/username');
        return;
      }

      log(`Checking room code: ${inviteCode}`, 'info');

      // Check if room exists and is active
      const { data: room, error: roomError } = await supabase
        .from('rooms')
        .select('id, room_name, is_active, status')
        .eq('room_code', inviteCode)
        .eq('is_active', true)  // Only get active rooms
        .single();

      if (roomError || !room) {
        error = 'Room not found. Please check the code.';
        log('Room not found', 'error');
        return;
      }

      if (room.status === 'playing') {
        error = 'Game already in progress.';
        log('Game in progress', 'error');
        return;
      }

      // Check if player already exists in this room
      const { data: existingPlayer } = await supabase
        .from('players')
        .select('id')
        .eq('room_id', room.id)
        .eq('username', username)
        .single();

      if (existingPlayer) {
        error = 'You are already in this room.';
        log('Player already in room', 'error');
        return;
      }

      // Check current number of players in the room
      const { data: players, error: playersError } = await supabase
        .from('players')
        .select('id')
        .eq('room_id', room.id)
        .eq('is_connected', true);  // Only count connected players

      if (playersError) {
        throw playersError;
      }

      // Check if room is full
      if (players && players.length >= MAX_PLAYERS) {
        error = `Room is full (${MAX_PLAYERS} players maximum)`;
        log('Room is full', 'error');
        return;
      }

      // Generate a unique user ID
      const userId = crypto.randomUUID();

      // Create player entry
      const { error: playerError } = await supabase
        .from('players')
        .insert({
          room_id: room.id,
          user_id: userId,
          username: username,
          is_connected: true,
          is_ready: false
        });

      if (playerError) {
        if (playerError.code === '23505') { // Unique constraint violation
          error = 'You are already in this room.';
          log('Player already in room', 'error');
          return;
        }
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

<div class="relative min-h-screen w-full bg-background flex items-center justify-center p-4">
  <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
    <Card.Header>
      <Card.Title class="text-2xl font-bold text-center text-foreground/90">
        Join Room
      </Card.Title>
      <Card.Description class="text-center text-muted-foreground/70">
        Enter the 4-digit room code to join
      </Card.Description>
    </Card.Header>

    <Card.Content class="space-y-4">
      <div class="space-y-2">
        <Label for="inviteCode" class="text-foreground/80">Room Code</Label>
        <Input
          id="inviteCode"
          type="text"
          placeholder="Enter room code"
          bind:value={inviteCode}
          maxlength="4"
          disabled={isLoading}
          class="w-full text-center text-2xl tracking-widest"
        />
        <p class="text-xs text-muted-foreground text-center">
          Maximum {MAX_PLAYERS} players per room
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
        disabled={!inviteCode || isLoading}
        class="w-full"
        variant="default"
        size="lg"
        on:click={handleJoin}
      >
        {isLoading ? 'Joining Room...' : 'Join Room'}
      </Button>

      <Separator class="my-2" />

      <div class="text-center space-y-2">
        <p class="text-muted-foreground/70">Want to create your own room?</p>
        <Button
          variant="ghost"
          size="sm"
          class="hover:bg-accent hover:text-accent-foreground"
          on:click={goToCreateRoom}
        >
          Create Room
        </Button>
      </div>

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