export function pulseFX() {
  document.querySelectorAll('.text').forEach((el) => {
      const textTop = el.querySelector('.text-top');
      if (!textTop) return; // Exit if '.text-top' is not found

      const bottomSpan = document.createElement('span');
      bottomSpan.className = 'text-bottom';
      bottomSpan.textContent = textTop.textContent ?? ''; // Handle null safety
      el.prepend(bottomSpan);
  });
}