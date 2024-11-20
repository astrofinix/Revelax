<script lang="ts">
    import { goto } from '$app/navigation';
    import { roomStore } from '$lib/stores/roomStore';
    import { validateUsername, generateRandomUsername } from '$lib/utils/validations';
  
    // Icons (using Lucide icons)
    import { PlusCircle, DoorOpen } from 'lucide-svelte';
  
    let username = '';
    let error = '';
  
    function createRoom() {
      if (!username) {
        username = generateRandomUsername();
      }
  
      const validationResult = validateUsername(username);
      
      if (validationResult.isValid) {
        const player = {
          id: crypto.randomUUID(),
          username,
          joinedAt: new Date()
        };
  
        const room = roomStore.createRoom(player);
        goto(`/room/${room.inviteCode}`);
      } else {
        error = validationResult.error || 'Invalid username';
      }
    }
  
    function joinRoom() {
      const inviteCode = prompt('Enter Room Invite Code:');
      if (inviteCode) {
        goto(`/room/${inviteCode}`);
      }
    }
  </script>
<style global>
    /* Import the Libre Franklin font */
    @import url("https://fonts.googleapis.com/css?family=Libre+Franklin:400,700&subset=latin");

    /* Non-standard Tailwind styles for H1 */
    h1 {
      font: 10vmin/0.8 "Libre Franklin", sans-serif;
      letter-spacing: -0.05em;
      text-shadow: 0 0 5px #fff;
      mix-blend-mode: overlay;
    }
  
    svg {
      height: 100%;
      width: 100%;
    }
  </style>
  
  <div
    class="min-h-screen grid place-items-center"
    style="background-color: #020202;"
  >
    <svg
      viewBox="0 0 100 100"
      preserveAspectRatio="xMidYMid slice"
      class="absolute inset-0"
    >
      <defs>
        <radialGradient id="Gradient1" cx="50%" cy="50%" fx="10%" fy="50%" r="0.5">
          <animate attributeName="fx" dur="34s" values="0%;3%;0%" repeatCount="indefinite" />
          <stop offset="0%" stop-color="#f6bd3a" />
          <stop offset="100%" stop-color="#ff00" />
        </radialGradient>
        <radialGradient id="Gradient2" cx="50%" cy="50%" fx="10%" fy="50%" r="0.5">
          <animate attributeName="fx" dur="23.5s" values="0%;3%;0%" repeatCount="indefinite" />
          <stop offset="0%" stop-color="#4658a7" />
          <stop offset="100%" stop-color="#0ff0" />
        </radialGradient>
        <radialGradient id="Gradient3" cx="50%" cy="50%" fx="50%" fy="50%" r="0.5">
          <animate attributeName="fx" dur="21.5s" values="0%;3%;0%" repeatCount="indefinite" />
          <stop offset="0%" stop-color="#df4a2b" />
          <stop offset="100%" stop-color="#f0f0" />
        </radialGradient>
      </defs>
      <rect
        x="0"
        y="0"
        width="100%"
        height="100%"
        fill="url(#Gradient1)"
      >
        <animate attributeName="x" dur="20s" values="25%;0%;25%" repeatCount="indefinite" />
        <animate attributeName="y" dur="21s" values="0%;25%;0%" repeatCount="indefinite" />
        <animateTransform
          attributeName="transform"
          type="rotate"
          from="0 50 50"
          to="360 50 50"
          dur="17s"
          repeatCount="indefinite"
        />
      </rect>
      <rect
        x="0"
        y="0"
        width="100%"
        height="100%"
        fill="url(#Gradient2)"
      >
        <animate attributeName="x" dur="23s" values="-25%;0%;-25%" repeatCount="indefinite" />
        <animate attributeName="y" dur="24s" values="0%;50%;0%" repeatCount="indefinite" />
        <animateTransform
          attributeName="transform"
          type="rotate"
          from="0 50 50"
          to="360 50 50"
          dur="18s"
          repeatCount="indefinite"
        />
      </rect>
      <rect
        x="0"
        y="0"
        width="100%"
        height="100%"
        fill="url(#Gradient3)"
      >
        <animate attributeName="x" dur="25s" values="0%;25%;0%" repeatCount="indefinite" />
        <animate attributeName="y" dur="26s" values="0%;25%;0%" repeatCount="indefinite" />
        <animateTransform
          attributeName="transform"
          type="rotate"
          from="360 50 50"
          to="0 50 50"
          dur="19s"
          repeatCount="indefinite"
        />
      </rect>
    </svg>
    <h1
      class="text-white font-bold absolute"
      style="color: #fff4;"
    >
      R<br />
    </h1>
  </div>
  
  <!-- <div class="min-h-screen bg-gradient-to-br from-purple-500 to-indigo-600 flex flex-col items-center justify-center p-4">
    <div class="bg-white shadow-2xl rounded-xl p-8 w-full max-w-md text-center">
      <h1 class="text-4xl font-bold mb-8 text-indigo-700">Revelax</h1>
      
      <div class="mb-6">
        <input 
          type="text" 
          bind:value={username}
          placeholder="Your Username (Optional)" 
          class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
        />
        {#if error}
          <p class="text-red-500 text-sm mt-2">{error}</p>
        {/if}
      </div>
  
      <div class="space-y-4">
        <button 
          on:click={createRoom} 
          class="w-full flex items-center justify-center bg-indigo-600 text-white py-3 rounded-lg hover:bg-indigo-700 transition duration-300 ease-in-out"
        >
          <PlusCircle class="mr-2" />
          Create Room
        </button>
  
        <button 
          on:click={joinRoom}
          class="w-full flex items-center justify-center bg-green-500 text-white py-3 rounded-lg hover:bg-green-600 transition duration-300 ease-in-out"
        >
          <DoorOpen class="mr-2" />
          Join Room
        </button>
      </div>
    </div>
  </div> -->