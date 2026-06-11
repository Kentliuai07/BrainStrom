/* BrainStrom 設計稿 v2 · 舞台腳本（不進 App）
   - 主題切換：.phone ←→ .phone.day
   - 狀態切換：phone 加 st-<state> class；頁面 CSS 自行顯隱
   - 直條交互：把手/模糊區/✕
   - 撥動開關：點擊切換（純展示）                                  */
(function () {
  const phone = document.getElementById('phone');
  if (!phone) return;

  /* 主題 */
  document.querySelectorAll('[data-theme]').forEach(btn => {
    btn.addEventListener('click', () => {
      phone.classList.toggle('day', btn.dataset.theme === 'day');
      document.querySelectorAll('[data-theme]').forEach(b => b.classList.toggle('on', b === btn));
    });
  });

  /* 狀態 */
  const stBtns = document.querySelectorAll('[data-state]');
  function setState(name) {
    [...phone.classList].filter(c => c.startsWith('st-')).forEach(c => phone.classList.remove(c));
    phone.classList.add('st-' + name);
    stBtns.forEach(b => b.classList.toggle('on', b.dataset.state === name));
  }
  stBtns.forEach(btn => btn.addEventListener('click', () => setState(btn.dataset.state)));
  if (stBtns.length) setState(stBtns[0].dataset.state);

  /* 直條 */
  const handle = document.getElementById('handle');
  const scrim = document.getElementById('scrim');
  if (handle) handle.addEventListener('click', () => phone.classList.add('rail-open'));
  if (scrim) scrim.addEventListener('click', () => phone.classList.remove('rail-open'));
  document.querySelectorAll('.rail .key.close').forEach(k =>
    k.addEventListener('click', () => phone.classList.remove('rail-open')));

  /* 撥動開關 */
  document.querySelectorAll('.sw').forEach(sw =>
    sw.addEventListener('click', e => { sw.classList.toggle('on'); e.stopPropagation(); }));
})();
