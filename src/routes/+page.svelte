<script>
  import { goto } from '$app/navigation';
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';
  import { Separator } from '$lib/components/ui/separator';
  import { onMount } from 'svelte';

  onMount(() => {
    // Always use dark mode
    document.documentElement.classList.add('dark');
  });

  function handleRoomAction(action) {
    localStorage.setItem('roomAction', action);
    goto('/username');
  }
</script>

<div class="relative min-h-screen w-full bg-background">
  <!-- Animated Background -->
  <div class="absolute inset-0 w-full h-full">
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <defs>
        <radialGradient id="Gradient2" cx="50%" cy="50%" fx="10%" fy="50%" r=".5">
          <animate attributeName="fx" dur="23.5s" values="0%;3%;0%" repeatCount="indefinite" />
          <stop offset="0%" stop-color="hsl(300 100% 50%)" />
          <stop offset="100%" stop-color="hsl(300 100% 50% / 0)" />
        </radialGradient>
        <radialGradient id="Gradient3" cx="50%" cy="50%" fx="50%" fy="50%" r=".5">
          <animate attributeName="fx" dur="21.5s" values="0%;3%;0%" repeatCount="indefinite" />
          <stop offset="0%" stop-color="hsl(180 100% 50%)" />
          <stop offset="100%" stop-color="hsl(180 100% 50% / 0)" />
        </radialGradient>
        <radialGradient id="Gradient1" cx="50%" cy="50%" fx="10%" fy="50%" r=".5">
          <animate attributeName="fx" dur="34s" values="0%;3%;0%" repeatCount="indefinite" />
          <stop offset="0%" stop-color="hsl(60 100% 50%)" />
          <stop offset="100%" stop-color="hsl(60 100% 50% / 0)" />
        </radialGradient>
      </defs>
      <rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient3)">
        <animate attributeName="x" dur="25s" values="0%;25%;0%" repeatCount="indefinite" />
        <animate attributeName="y" dur="26s" values="0%;25%;0%" repeatCount="indefinite" />
        <animateTransform attributeName="transform" type="rotate" from="360 50 50" to="0 50 50" dur="19s" repeatCount="indefinite" />
      </rect>
      <rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient1)">
        <animate attributeName="x" dur="20s" values="25%;0%;25%" repeatCount="indefinite" />
        <animate attributeName="y" dur="21s" values="0%;25%;0%" repeatCount="indefinite" />
        <animateTransform attributeName="transform" type="rotate" from="0 50 50" to="360 50 50" dur="17s" repeatCount="indefinite" />
      </rect>
      <rect x="0" y="0" width="100%" height="100%" fill="url(#Gradient2)">
        <animate attributeName="x" dur="23s" values="-25%;0%;-25%" repeatCount="indefinite" />
        <animate attributeName="y" dur="24s" values="0%;50%;0%" repeatCount="indefinite" />
        <animateTransform attributeName="transform" type="rotate" from="0 50 50" to="360 50 50" dur="18s" repeatCount="indefinite" />
      </rect>
      
    </svg>
  </div>

  <!-- Content -->
  <div class="relative z-10 min-h-screen flex items-center justify-center p-4">
    <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
      <Card.Header class="space-y-2">
        <Card.Title class="text-4xl font-bold tracking-tight text-card-foreground text-center">
          Revelax
        </Card.Title>
        <Card.Description class="text-center text-muted-foreground">
          Where conversations begin.
        </Card.Description>
      </Card.Header>

      <Card.Footer class="flex flex-col gap-4 p-6">
        <Button 
          variant="default"
          size="lg"
          class="w-full text-lg py-6 bg-primary text-primary-foreground hover:bg-primary/90"
          on:click={() => handleRoomAction('create')}
        >
          Create Room
        </Button>
        
        <Separator class="bg-border" />
        
        <Button 
          variant="secondary"
          size="lg"
          class="w-full text-lg py-6 bg-secondary text-secondary-foreground hover:bg-secondary/80"
          on:click={() => handleRoomAction('join')}
        >
          Join Room
        </Button>
      </Card.Footer>
    </Card.Root>
  </div>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow-x: hidden;
    background-color: hsl(var(--background));
    color: hsl(var(--foreground));
  }

  svg {
    height: 100%;
    width: 100%;
    mix-blend-mode: screen;
    opacity: 0.7;
  }

  :global(.card) {
    background-color: hsl(var(--card));
    color: hsl(var(--card-foreground));
    border: 1px solid hsl(var(--border));
    animation: fadeIn 0.5s ease-out;
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
  