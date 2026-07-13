'use strict';

const panel = document.getElementById('main-panel');
const panelTitle = document.getElementById('panel-title');
const itemsContainer = document.getElementById('items-container');
const closeBtn = document.getElementById('close-btn');

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

async function nuiCallback(name, data = {}) {
    try {
        const resp = await fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await resp.json();
    } catch (err) {
        console.error(`NUI callback "${name}" failed:`, err);
        return { error: err.message };
    }
}

function openPanel(data) {
    panel.classList.remove('hidden');
    panelTitle.textContent = data.title || 'Panel';
    itemsContainer.innerHTML = '';
    if (data.items && data.items.length > 0) {
        for (const item of data.items) {
            const div = document.createElement('div');
            div.className = 'item';
            div.innerHTML = `
                <span class="item-name">${escapeHtml(item.name)}</span>
                <span class="item-price">$${item.price ?? 0}</span>
                <button class="item-btn">Buy</button>
            `;
            div.querySelector('.item-btn').addEventListener('click', () => {
                nuiCallback('buyItem', { itemName: item.name, quantity: 1 });
            });
            itemsContainer.appendChild(div);
        }
    } else {
        itemsContainer.innerHTML = '<div class="empty-state">No items available</div>';
    }
}

function closePanel() {
    panel.classList.add('hidden');
    nuiCallback('close', {});
}

window.addEventListener('message', (event) => {
    switch (event.data.type) {
        case 'open': openPanel(event.data.data); break;
        case 'close': closePanel(); break;
        case 'update': openPanel(event.data.data); break;
    }
});

closeBtn.addEventListener('click', closePanel);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closePanel(); });
panel.addEventListener('mousedown', (e) => e.stopPropagation());
