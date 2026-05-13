use crate::model::{ChainState, genesis_state};
use anyhow::{Context, Result};
use std::fs;
use std::path::{Path, PathBuf};

pub const DEFAULT_STATE_PATH: &str = "devnet/local/state.json";

pub fn default_state_path() -> PathBuf {
    PathBuf::from(DEFAULT_STATE_PATH)
}

pub fn load_state(path: &Path) -> Result<ChainState> {
    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read state file {}", path.display()))?;
    serde_json::from_str(&body)
        .with_context(|| format!("failed to parse state file {}", path.display()))
}

pub fn load_or_genesis(path: &Path) -> Result<ChainState> {
    if path.exists() {
        load_state(path)
    } else {
        Ok(genesis_state())
    }
}

pub fn save_state(path: &Path, state: &ChainState) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create state directory {}", parent.display()))?;
    }
    let body = serde_json::to_string_pretty(state)?;
    fs::write(path, format!("{body}\n"))
        .with_context(|| format!("failed to write state file {}", path.display()))
}

pub fn reset_state(path: &Path) -> Result<ChainState> {
    if let Some(parent) = path.parent()
        && parent.exists()
    {
        fs::remove_dir_all(parent)
            .with_context(|| format!("failed to remove {}", parent.display()))?;
    }
    let state = genesis_state();
    save_state(path, &state)?;
    Ok(state)
}
