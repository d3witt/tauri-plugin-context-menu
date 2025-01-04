import { invoke } from "@tauri-apps/api/core";

export async function popup(options: {
    items: Array<{
        id: string;
        label: string;
        enabled?: boolean;
        selected?: boolean;
        subItems?: Array<any>;
    }>;
    x?: number;
    y?: number;
}): Promise<string | null> {
    return await invoke<{ id?: string }>("plugin:context-menu|popup", {
        payload: options,
    }).then((r) => (r.id ? r.id : null));
}
