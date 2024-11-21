<script>
	// export let name = "World";

  import { Button } from "$lib/components/ui/button";
	import Gradient from "$lib/components/gradient.svelte";
	import Card from "$lib/components/card.svelte";
  
</script>

<main>
  <Gradient />

  <div class="content">
    <div class="aether-h1">Revelax</div>

    <div class="buttons flex gap-8">
      <Card text="♠" subtitle="Create Room" />
      <!-- leads to /lobby-host -->

      <Card text="♣" subtitle="Join Room" />
      <!-- leads to /lobby-play -->
    </div>

    
  </div>
</main>