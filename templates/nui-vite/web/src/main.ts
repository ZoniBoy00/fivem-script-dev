import './style.css';
import { debugMessages, fetchNui, onNuiMessage } from './nui';
import type { ShopItem } from './types';

const app = document.querySelector<HTMLElement>('#app')!;
const list = document.querySelector<HTMLUListElement>('#items')!;
const status = document.querySelector<HTMLElement>('#status')!;
const closeBtn = document.querySelector<HTMLButtonElement>('#close')!;

function setVisible(visible: boolean): void {
  app.hidden = !visible; // hidden = display:none → nothing renders or animates while closed
  if (!visible) status.textContent = '';
}

function renderItems(items: ShopItem[]): void {
  // DOM APIs + textContent only: item data never becomes HTML (no XSS via labels)
  const rows = items.map((item) => {
    const li = document.createElement('li');
    li.className = 'item';

    const label = document.createElement('span');
    label.textContent = item.label;

    const price = document.createElement('span');
    price.className = 'price';
    price.textContent = `$${Number(item.price) || 0}`;

    const buy = document.createElement('button');
    buy.type = 'button';
    buy.textContent = 'Buy';
    buy.addEventListener('click', () => purchase(item, buy));

    li.append(label, price, buy);
    return li;
  });
  list.replaceChildren(...rows);
}

async function purchase(item: ShopItem, button: HTMLButtonElement): Promise<void> {
  button.disabled = true; // no double-submits while the server answers
  try {
    const result = await fetchNui('purchase', { item: item.name, quantity: 1 }, { ok: true });
    status.textContent = result.ok ? `Bought ${item.label}` : `Failed: ${result.reason ?? 'unknown'}`;
  } catch {
    status.textContent = 'Request failed';
  } finally {
    button.disabled = false;
  }
}

function close(): void {
  setVisible(false);
  void fetchNui('close', undefined, true);
}

onNuiMessage('setVisible', setVisible);
onNuiMessage('setItems', renderItems);

closeBtn.addEventListener('click', close);
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !app.hidden) close();
});

// `npm run dev` in a browser shows the UI with fake data
debugMessages([
  { action: 'setItems', data: [{ name: 'water', label: 'Water', price: 5 }, { name: 'bread', label: 'Bread', price: 3 }] },
  { action: 'setVisible', data: true },
]);
