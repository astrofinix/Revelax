<script>
	import '../app.css';
	import { onMount } from 'svelte';

	onMount(() => {
		document.documentElement.classList.add('dark');
	});
</script>

<slot />
