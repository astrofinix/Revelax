<script>
    import { onMount } from 'svelte';
  
    let drawnCard = null;
    let isLoading = false;
  
    async function drawCard() {
      isLoading = true;
      try {
        const response = await fetch('https://deckofcardsapi.com/api/deck/new/draw/?count=1');
        const data = await response.json();
        drawnCard = data.cards[0];
      } catch (error) {
        console.error('Error drawing card:', error);
      } finally {
        isLoading = false;
      }
    }
  
    onMount(() => {
      // Preload the card back image
      const img = new Image();
      img.src = 'https://deckofcardsapi.com/static/img/back.png';
    });
  </script>
  
  <div class="container mx-auto p-4">
    <h1 class="text-3xl font-bold mb-4 text-center">Card Deck</h1>
    
    <div class="flex justify-center mb-4">
      {#if drawnCard}
        <img src={drawnCard.image} alt={`${drawnCard.value} of ${drawnCard.suit}`} class="w-64 h-auto" />
      {:else}
        <button on:click={drawCard} disabled={isLoading} class="relative w-64 h-96 bg-white rounded-lg shadow-md overflow-hidden focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-transform transform hover:scale-105">
          <img src="https://deckofcardsapi.com/static/img/back.png" alt="Card back" class="w-full h-full object-cover" />
          {#if isLoading}
            <div class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50 text-white">
              Loading...
            </div>
          {/if}
        </button>
      {/if}
    </div>
    
    {#if drawnCard}
      <div class="text-center">
        <p class="text-xl font-semibold">{drawnCard.value} of {drawnCard.suit}</p>
        <button on:click={() => drawnCard = null} class="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50">
          Return to Deck
        </button>
      </div>
    {/if}
  </div>

<style>
img {
    max-width: 100%;
    height: auto;
}
    
.text-white {
    --tw-text-opacity: 1;
    color: rgb(255 255 255 / var(--tw-text-opacity, 1));
}

.py-2 {
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
}

.px-4 {
    padding-left: 1rem;
    padding-right: 1rem;
}

.bg-blue-500 {
    --tw-bg-opacity: 1;
    background-color: rgb(59 130 246 / var(--tw-bg-opacity, 1));
}

.rounded {
    border-radius: var(--radius - 4px);
}

.mt-4 {
    margin-top: 1rem;
}
</style>