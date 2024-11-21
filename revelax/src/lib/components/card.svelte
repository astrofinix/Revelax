<script>
// @ts-nocheck

  import { onMount } from "svelte";

  export let text = ""; // Main text to display inside the card
  export let subtitle = ""; // Subtitle text to display under the main text

  let card;
  let gloss;
  let textElement;
  let subtitleElement;

  function handleMouseMove(e) {
    if (!card || !gloss || !textElement || !subtitleElement) return;

    const pointerX = e.clientX;
    const pointerY = e.clientY;

    const cardRect = card.getBoundingClientRect();

    const halfWidth = cardRect.width / 2;
    const halfHeight = cardRect.height / 2;

    const cardCenterX = cardRect.left + halfWidth;
    const cardCenterY = cardRect.top + halfHeight;

    const deltaX = pointerX - cardCenterX;
    const deltaY = pointerY - cardCenterY;

    const distanceToCenter = Math.sqrt(deltaX ** 2 + deltaY ** 2);
    const maxDistance = Math.max(halfWidth, halfHeight);

    const degree = (distanceToCenter * 10) / maxDistance;
    const rx = deltaY / halfHeight;
    const ry = deltaX / halfWidth;

    // Apply rotation to the card
    card.style.transform = `perspective(400px) rotate3d(${-rx}, ${ry}, 0, ${degree}deg)`;

    // Apply gloss effect transformation
    gloss.style.transform = `translate(${-ry * 100}%, ${-rx * 100}%) scale(2.4)`;
    gloss.style.opacity = (distanceToCenter * 0.6) / maxDistance;

    // Apply the same transformation to the text elements
    textElement.style.transform = `rotate3d(${-rx}, ${ry}, 0, ${degree}deg)`;
    subtitleElement.style.transform = `rotate3d(${-rx}, ${ry}, 0, ${degree}deg)`;
  }

  function handleMouseLeave() {
    if (!card || !gloss || !textElement || !subtitleElement) return;

    card.style = null;
    gloss.style.opacity = 0;
    textElement.style.transform = "none"; // Reset the text rotation when mouse leaves
    subtitleElement.style.transform = "none"; // Reset the subtitle rotation when mouse leaves
  }

  onMount(() => {
    if (!card || !gloss || !textElement || !subtitleElement) return;

    card.addEventListener("mousemove", handleMouseMove);
    card.addEventListener("mouseleave", handleMouseLeave);

    return () => {
      card.removeEventListener("mousemove", handleMouseMove);
      card.removeEventListener("mouseleave", handleMouseLeave);
    };
  });
</script>

<div bind:this={card} id="card">
  <div bind:this={gloss} id="gloss"></div>
  <div bind:this={textElement} class="card-content">
    {text}
  </div>
  {#if subtitle}
    <div bind:this={subtitleElement} class="card-subtitle">
      {subtitle}
    </div>
  {/if}
</div>

<style>
  @import url("https://fonts.googleapis.com/css2?family=Quicksand:wght@300..700&display=swap");

  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  :root {
	--primary-color: #282c4c;
	--secondary-color: #58546c;
	--accent-color: #dc9c1b;
	--accent-color-dark: #d14d14;

	--font-base: 'Inter', sans-serif;
	--font-mont: 'Montserrat', sans-serif;
}


  #card {
    width: 400px;
    height: 400px;
    background: linear-gradient(
      to bottom right,
      var(--accent-color),
      var(--accent-color-dark)
    );
    border-radius: 1rem;
    cursor: pointer;
    transition: all 0.2s ease;
    position: relative;
    overflow: hidden;
    box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1),
      0 8px 10px -6px rgb(0 0 0 / 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-direction: column;
  }

  #gloss {
    opacity: 0;
    width: 100%;
    height: 100%;
    position: absolute;
    left: 0;
    top: 0;
    border-radius: 50%;
    background: radial-gradient(
      circle,
      rgba(255, 255, 255, 1) 0%,
      rgba(255, 255, 255, 0) 50%,
      rgba(255, 255, 255, 0) 100%
    );
    will-change: opacity;
    transition: 0.2s opacity ease-out;
    z-index: 1;
  }

  .card-content {
    color: var(--primary-color);
    z-index: 1;
    font-family: "Inter", sans-serif;
    font-weight: 500;
    font-size: 15rem; /* Main text size */
    margin-top: -5rem;
    text-align: center;
    transition: transform 0.2s ease-out, color 0.5s ease-out;
  }

  .card-subtitle {
    color: var(--primary-color);
    z-index: 1;
    font-weight: 500;
    font-size: 1.5rem; /* Subtitle size */
    text-align: center;
    margin-top: -5rem;
    transition: transform 0.2s ease-out, color 0.3s ease-out;
  }

  #card:hover .card-subtitle {
    color: white;
  }

  .card-content:hover {
    color: white;
  }
</style>
