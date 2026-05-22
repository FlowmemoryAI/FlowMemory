use crate::model::{ChainState, genesis_state};
use anyhow::{Context, Result};
use serde::Serialize;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

pub const DEFAULT_STATE_PATH: &str = "local-runtime/local/state.json";

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
    write_json_pretty(path, state)
        .with_context(|| format!("failed to write state file {}", path.display()))
}

pub fn write_json_pretty<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create state directory {}", parent.display()))?;
    }
    let body = serde_json::to_string_pretty(value)?;
    write_text_atomic(path, &format!("{body}\n"))
}

fn write_text_atomic(path: &Path, body: &str) -> Result<()> {
    let parent = path.parent().unwrap_or_else(|| Path::new("."));
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("state.json");
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or_default();
    let tmp_path = parent.join(format!(".{file_name}.{}.{}.tmp", std::process::id(), nonce));

    {
        let mut file = fs::File::create(&tmp_path)
            .with_context(|| format!("failed to create temp file {}", tmp_path.display()))?;
        file.write_all(body.as_bytes())
            .with_context(|| format!("failed to write temp file {}", tmp_path.display()))?;
        file.sync_all()
            .with_context(|| format!("failed to sync temp file {}", tmp_path.display()))?;
    }

    replace_file(&tmp_path, path).with_context(|| {
        let _ = fs::remove_file(&tmp_path);
        format!(
            "failed to replace {} with {}",
            path.display(),
            tmp_path.display()
        )
    })
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

#[cfg(windows)]
fn replace_file(from: &Path, to: &Path) -> Result<()> {
    use std::os::windows::ffi::OsStrExt;
    use std::thread;
    use std::time::Duration;

    const MOVEFILE_REPLACE_EXISTING: u32 = 0x1;
    const MOVEFILE_WRITE_THROUGH: u32 = 0x8;
    const REPLACE_RETRY_ATTEMPTS: usize = 80;
    const REPLACE_RETRY_SLEEP_MS: u64 = 25;

    unsafe extern "system" {
        fn MoveFileExW(
            lpExistingFileName: *const u16,
            lpNewFileName: *const u16,
            dwFlags: u32,
        ) -> i32;
    }

    let from_wide = from
        .as_os_str()
        .encode_wide()
        .chain(std::iter::once(0))
        .collect::<Vec<_>>();
    let to_wide = to
        .as_os_str()
        .encode_wide()
        .chain(std::iter::once(0))
        .collect::<Vec<_>>();
    for attempt in 0..REPLACE_RETRY_ATTEMPTS {
        let moved = unsafe {
            MoveFileExW(
                from_wide.as_ptr(),
                to_wide.as_ptr(),
                MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
            )
        };
        if moved != 0 {
            return Ok(());
        }

        let error = std::io::Error::last_os_error();
        if !is_transient_windows_replace_error(&error) || attempt + 1 == REPLACE_RETRY_ATTEMPTS {
            return Err(error)
                .with_context(|| format!("failed to atomically replace {}", to.display()));
        }
        thread::sleep(Duration::from_millis(REPLACE_RETRY_SLEEP_MS));
    }

    unreachable!("replace retry loop returns on success or final failure")
}

#[cfg(windows)]
fn is_transient_windows_replace_error(error: &std::io::Error) -> bool {
    matches!(error.raw_os_error(), Some(5 | 32 | 33))
}

#[cfg(not(windows))]
fn replace_file(from: &Path, to: &Path) -> Result<()> {
    fs::rename(from, to).with_context(|| format!("failed to rename {}", from.display()))
}
