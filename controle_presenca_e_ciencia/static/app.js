/* ── User search / chip selector for the ATA create form ───────────────── */
(function () {
  const searchInput = document.getElementById('user-search');
  if (!searchInput) return;   // only on the create page

  const dropdown     = document.getElementById('user-dropdown');
  const chipsWrap    = document.getElementById('chips-container');
  const chipsEmpty   = document.getElementById('chips-empty');
  const recipientsIn = document.getElementById('recipients-json');

  let selected = [];   // [{ email, name }]
  let debounce = null;

  function renderChips() {
    chipsWrap.querySelectorAll('.chip').forEach(c => c.remove());
    if (selected.length === 0) {
      chipsEmpty.style.display = '';
    } else {
      chipsEmpty.style.display = 'none';
      selected.forEach((r, idx) => {
        const chip = document.createElement('div');
        chip.className = 'chip';
        chip.innerHTML = `
          <span>${escHtml(r.name || r.email)}</span>
          <button type="button" class="chip-remove" data-idx="${idx}" title="Remover">✕</button>
        `;
        chipsWrap.appendChild(chip);
      });
    }
    recipientsIn.value = JSON.stringify(selected);
  }

  function addUser(user) {
    if (!selected.find(r => r.email === user.email)) {
      selected.push(user);
      renderChips();
    }
    closeDropdown();
    searchInput.value = '';
    searchInput.focus();
  }

  function removeUser(idx) {
    selected.splice(idx, 1);
    renderChips();
  }

  function openDropdown() { dropdown.classList.add('open'); }
  function closeDropdown() { dropdown.classList.remove('open'); dropdown.innerHTML = ''; }

  function escHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  async function fetchUsers(q) {
    try {
      const resp = await fetch(`/api/users?q=${encodeURIComponent(q)}`);
      if (!resp.ok) return [];
      return await resp.json();
    } catch { return []; }
  }

  function renderDropdown(users) {
    dropdown.innerHTML = '';
    if (!users.length) {
      dropdown.innerHTML = '<div class="user-option"><span class="user-option-email">Nenhum usuário encontrado.</span></div>';
      openDropdown();
      return;
    }
    users.forEach(u => {
      const el = document.createElement('div');
      el.className = 'user-option';
      el.innerHTML = `
        <div class="user-option-name">${escHtml(u.name || u.email)}</div>
        <div class="user-option-email">${escHtml(u.email)}</div>
      `;
      el.addEventListener('mousedown', e => {
        e.preventDefault();   // prevent blur from firing first
        addUser(u);
      });
      dropdown.appendChild(el);
    });
    openDropdown();
  }

  searchInput.addEventListener('input', () => {
    clearTimeout(debounce);
    const q = searchInput.value.trim();
    if (q.length < 2) { closeDropdown(); return; }
    debounce = setTimeout(async () => {
      const users = await fetchUsers(q);
      renderDropdown(users);
    }, 280);
  });

  searchInput.addEventListener('blur', () => {
    // Small delay so mousedown on an option fires first
    setTimeout(closeDropdown, 180);
  });

  // Chip removal via event delegation
  chipsWrap.addEventListener('click', e => {
    const btn = e.target.closest('.chip-remove');
    if (btn) removeUser(Number(btn.dataset.idx));
  });

  // Block form submission if no recipients
  const form = document.getElementById('ata-form');
  if (form) {
    form.addEventListener('submit', e => {
      if (selected.length === 0) {
        e.preventDefault();
        alert('Adicione ao menos um destinatário antes de continuar.');
        searchInput.focus();
      }
    });
  }

  renderChips(); // init
})();
