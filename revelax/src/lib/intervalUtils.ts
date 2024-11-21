import { onDestroy } from 'svelte';

export function onInterval(callback: () => void, milliseconds: number) {
  const interval = setInterval(callback, milliseconds);

  onDestroy(() => {
    clearInterval(interval);
  });
}