import type { NuiCallbacks, NuiMessage } from './types';

declare global {
  interface Window {
    GetParentResourceName?: () => string;
    invokeNative?: unknown;
  }
}

// True when opened with `npm run dev` in a normal browser instead of in-game
export const isBrowser = !window.invokeNative;

const resourceName = window.GetParentResourceName?.() ?? 'myres';

/** Call a RegisterNUICallback handler. In the browser it resolves with `mock` instead. */
export async function fetchNui<K extends keyof NuiCallbacks>(
  name: K,
  payload?: NuiCallbacks[K]['payload'],
  mock?: NuiCallbacks[K]['response'],
): Promise<NuiCallbacks[K]['response']> {
  if (isBrowser) return mock as NuiCallbacks[K]['response'];

  const resp = await fetch(`https://${resourceName}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload ?? {}),
  });
  return resp.json();
}

type Handler<A extends NuiMessage['action']> = (data: Extract<NuiMessage, { action: A }>['data']) => void;
const handlers: { [A in NuiMessage['action']]?: Handler<A> } = {};

/** Subscribe to SendNUIMessage({ action = name, data = ... }) */
export function onNuiMessage<A extends NuiMessage['action']>(action: A, handler: Handler<A>): void {
  (handlers as Record<string, unknown>)[action] = handler;
}

window.addEventListener('message', (event: MessageEvent<NuiMessage>) => {
  const msg = event.data;
  if (!msg || typeof msg !== 'object' || !('action' in msg)) return;
  const handler = handlers[msg.action] as ((data: unknown) => void) | undefined;
  handler?.(msg.data);
});

/** Dev only: simulate messages from Lua when running in a browser */
export function debugMessages(messages: NuiMessage[], delay = 100): void {
  if (!import.meta.env.DEV || !isBrowser) return;
  for (const data of messages) {
    setTimeout(() => window.dispatchEvent(new MessageEvent('message', { data })), delay);
  }
}
