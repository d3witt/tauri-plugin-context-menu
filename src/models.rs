use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MenuItem {
    pub id: String,
    pub label: String,
    pub enabled: Option<bool>,
    pub selected: Option<bool>,
    pub sub_items: Option<Vec<MenuItem>>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ContextMenuOptions {
    pub items: Vec<MenuItem>,
    pub x: Option<f64>,
    pub y: Option<f64>,
}
