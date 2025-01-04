use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime};

use crate::models::*;

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> crate::Result<ContextMenu<R>> {
    Ok(ContextMenu(app.clone()))
}

/// Access to the context-menu APIs.
pub struct ContextMenu<R: Runtime>(AppHandle<R>);

impl<R: Runtime> ContextMenu<R> {
    pub fn popup(&self, payload: ContextMenuOptions) -> crate::Result<()> {
        Ok(())
    }
}
