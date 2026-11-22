/* Sichtbarkeit aller Passwortfelder, auch bei zukünftig dynamisch ergänzten Formularen. */
(() => {
  'use strict';
  const eye = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg>';
  const eyeOff = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 3l18 18M10.6 5.1A11.2 11.2 0 0 1 12 5c6.4 0 10 7 10 7a14 14 0 0 1-3.1 3.7M6.2 6.3C3.5 8.1 2 12 2 12s3.6 7 10 7c1.6 0 3-.4 4.2-1"/><path d="M10 10a3 3 0 0 0 4 4"/></svg>';
  function attach(input) {
    if (input.closest('.password-field')) {
      const wrapper = input.closest('.password-field');
      if (wrapper.querySelector('.password-toggle')) return;
    }
    const wrapper = document.createElement('div');
    wrapper.className = 'password-field';
    input.parentNode.insertBefore(wrapper, input);
    wrapper.appendChild(input);
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'password-toggle';
    button.setAttribute('aria-label', 'Passwort anzeigen');
    button.setAttribute('aria-pressed', 'false');
    button.title = 'Passwort anzeigen';
    wrapper.appendChild(button);
  }
  function update(button) {
    const input = button.closest('.password-field')?.querySelector('input');
    if (!input) return;
    const visible = input.type === 'text';
    button.innerHTML = visible ? eyeOff : eye;
    button.setAttribute('aria-label', visible ? 'Passwort verbergen' : 'Passwort anzeigen');
    button.setAttribute('aria-pressed', String(visible));
    button.title = visible ? 'Passwort verbergen' : 'Passwort anzeigen';
  }
  function init() {
    document.querySelectorAll('input[type="password"]').forEach(attach);
    document.querySelectorAll('.password-toggle').forEach(update);
  }
  document.addEventListener('click', event => {
    const button = event.target.closest('.password-toggle');
    if (!button) return;
    const input = button.closest('.password-field')?.querySelector('input');
    if (!input) return;
    const start = input.selectionStart, end = input.selectionEnd;
    input.type = input.type === 'password' ? 'text' : 'password';
    update(button);
    input.focus({preventScroll:true});
    try { input.setSelectionRange(start,end); } catch (_) {}
  });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
  new MutationObserver(() => {
    document.querySelectorAll('input[type="password"]:not(.password-field input)').forEach(attach);
    document.querySelectorAll('.password-toggle:not([data-initialized])').forEach(button => {
      button.dataset.initialized = 'true';
      update(button);
    });
  }).observe(document.documentElement, {childList:true,subtree:true});
})();
