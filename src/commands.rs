use tauri::{command, AppHandle, Runtime};

use crate::models::*;
use crate::ContextMenuExt;
use crate::Result;

#[command]
pub(crate) async fn ping<R: Runtime>(app: AppHandle<R>, payload: ContextMenuOptions) -> Result<()> {
    app.context_menu().popup(payload)
}
