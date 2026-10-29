// Contract between client.lua and the UI. Keep it in sync with SendNUIMessage / RegisterNUICallback.

export interface ShopItem {
  name: string;
  label: string;
  price: number;
}

// Lua → UI: SendNUIMessage({ action = ..., data = ... })
export type NuiMessage =
  | { action: 'setVisible'; data: boolean }
  | { action: 'setItems'; data: ShopItem[] };

// UI → Lua: fetchNui(name, payload) resolves with what the Lua cb(...) returned
export interface NuiCallbacks {
  close: { payload: undefined; response: boolean };
  purchase: { payload: { item: string; quantity: number }; response: { ok: boolean; reason?: string } };
}
