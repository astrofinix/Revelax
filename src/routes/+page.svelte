<script>
// @ts-nocheck

  import { goto } from '$app/navigation';
  import * as Card from '$lib/components/ui/card';
  import { Button } from '$lib/components/ui/button';
  import { Separator } from '$lib/components/ui/separator';
  import * as Dialog from '$lib/components/ui/dialog';
  import { Checkbox } from '$lib/components/ui/checkbox';
  import { Label } from '$lib/components/ui/label';
  import { onMount } from 'svelte';

  let termsAccepted = false;
  let showTerms = false;
  let isFirstVisit = true;

  onMount(() => {
    // Always use dark mode
    document.documentElement.classList.add('dark');
    
    // Check if user has previously accepted terms
    const hasAcceptedTerms = localStorage.getItem('termsAccepted');
    if (hasAcceptedTerms === 'true') {
      termsAccepted = true;
      isFirstVisit = false;
    } else {
      // Show terms dialog automatically on first visit
      showTerms = true;
      isFirstVisit = true;
    }
  });

  function handleTermsAccept() {
    termsAccepted = true;
    showTerms = false;
    localStorage.setItem('termsAccepted', 'true');
  }

  function handleRoomAction(action) {
    if (!termsAccepted) {
      showTerms = true;
      return;
    }
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

  <div class="noise"></div>

  <!-- Content -->
  <div class="relative z-10 min-h-screen flex items-center justify-center p-1">
    <Card.Root class="w-full max-w-md bg-card/95 backdrop-blur-lg border border-border">
      <Card.Header class="space-y-1">
        <Card.Title class="signature-font text-6xl font-bold tracking-tight text-card-foreground text-center revelax-title mt-[0.5em]">
          Revelax
        </Card.Title>
        <Card.Description class="sans-font font-[600] text-center text-muted-foreground ">
          Where conversations begin.
        </Card.Description>
      </Card.Header>

      <Card.Content class="px-6 pb-1">
        <div class="flex justify-center">
          <img class="pb-10" src="./revelax.gif" alt="A fun GIF" width="160">
        </div>
        <div class="flex justify-center space-x-2">
          <Checkbox 
            id="terms" 
            bind:checked={termsAccepted}
            on:change={(e) => {
              if (!e.target.checked) {
                showTerms = true;
              }
            }}
          />
          <Label
            for="terms"
            class="text-sm text-muted-foreground leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
          >
            I agree to follow the
            <button 
              class="text-primary hover:underline focus:outline-none"
              on:click={() => showTerms = true}
              type="button"
            >
              community guidelines
            </button>
          </Label>
        </div>
      </Card.Content>

      <Card.Footer class="flex flex-col gap-3 p-6">
        <Button 
          variant="default"
          size="lg"
          class="sans-font font-[600] w-full text-lg py-6 bg-primary text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
          on:click={() => handleRoomAction('create')}
          disabled={!termsAccepted}
        >
          Create Room
        </Button>
        
        <Separator class="bg-border" />
        
        <Button 
          variant="secondary"
          size="lg"
          class="w-full text-lg py-6 bg-secondary text-secondary-foreground hover:bg-secondary/80 disabled:opacity-50"
          on:click={() => handleRoomAction('join')}
          disabled={!termsAccepted}
        >
          Join Room
        </Button>
      </Card.Footer>
    </Card.Root>

    <!-- Terms Modal -->
    <Dialog.Root 
      bind:open={showTerms}
      onOpenChange={(open) => {
        // Prevent closing on first visit
        if (isFirstVisit && !termsAccepted) {
          showTerms = true;
        }
      }}
    >
      <Dialog.Content class="max-w-md max-h-[80vh] overflow-y-auto ">
        <Dialog.Header class="space-y-3 py-3 px-3 ">
          <Dialog.Title class="text-2xl font-bold signature-font">Welcome to Revelax! 👋</Dialog.Title>
          <Dialog.Description class="text-muted-foreground text-justify">
            Before we start having fun, here's a quick overview of how we can make this a great experience for everyone.

            <p class="text-muted-foreground mt-5">Updated: {new Date().toLocaleDateString()}</p>
          </Dialog.Description>
        </Dialog.Header>

        <div class="space-y-6 mt-[-1em] py-3 px-3 text-sm text-justify">
          <div class="space-y-2">
            <h3 class="text-lg font-medium text-foreground signature-font">🤝 Playing Together</h3>
            <p class="text-muted-foreground">
              By joining Revelax, you're becoming part of our community of people who love meaningful conversations and fun interactions!
            </p>
          </div>

          <div class="space-y-2">
            <h3 class="text-lg font-medium text-foreground signature-font">💭 Community Guidelines</h3>
            <p class="text-muted-foreground">Here's how we can make this fun for everyone:</p>
            <ul class="list-disc pl-4 space-y-2 mt-2 text-muted-foreground">
              <li>When in doubt about the card, use you best judgement, deer🦌.</li>
              <li>Be kind and respectful to other players</li>
              <li>Keep conversations friendly and appropriate</li>
              <li>Let's create a safe space for everyone</li>
              <li>What happens in Revelax, stays in Revelax</li>
            </ul>
          </div>

          <div class="space-y-2">
            <h3 class="text-lg font-medium text-foreground signature-font">🔒 Your Privacy Matters</h3>
            <p class="text-muted-foreground">
              We care about your privacy and keep your information safe. We only collect what's needed to make your experience awesome!
            </p>
          </div>
        </div>

        <Dialog.Footer class="gap-2">
          <Button 
            variant="default"
            class="bg-primary hover:bg-primary/90"
            on:click={handleTermsAccept}
          >
            {isFirstVisit ? "I Agree! Let's Play! ✨" : "Let's Play! ✨"}
          </Button>
          {#if !isFirstVisit}
            <Button 
              variant="outline"
              on:click={() => showTerms = false}
            >
              Maybe Later
            </Button>
          {/if}
        </Dialog.Footer>
      </Dialog.Content>
    </Dialog.Root>
  </div>
</div>

<canvas id="noise" class="noise" style="z-index: 2;"></canvas>

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
  :global(.checkbox) {
    @apply border-2 border-muted-foreground/50;
  }
</style>
  