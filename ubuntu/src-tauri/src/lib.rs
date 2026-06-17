use std::env;
use std::fs;
use std::path::PathBuf;

#[tauri::command]
fn load_session() -> Result<Option<String>, String> {
    let path = session_file_path()?;

    match fs::read_to_string(&path) {
        Ok(contents) => Ok(Some(contents)),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(error.to_string()),
    }
}

#[tauri::command]
fn save_session(state_json: String) -> Result<(), String> {
    let path = session_file_path()?;
    let directory = path
        .parent()
        .ok_or_else(|| "Session path does not have a parent directory".to_string())?;

    fs::create_dir_all(directory).map_err(|error| error.to_string())?;
    fs::write(path, state_json).map_err(|error| error.to_string())
}

#[tauri::command]
fn save_note_file(path: String, content: String) -> Result<(), String> {
    fs::write(path, content).map_err(|error| error.to_string())
}

#[tauri::command]
fn session_path() -> Result<String, String> {
    session_file_path().map(|path| path.to_string_lossy().to_string())
}

fn session_file_path() -> Result<PathBuf, String> {
    Ok(session_directory()?.join("session.json"))
}

fn session_directory() -> Result<PathBuf, String> {
    let data_home = env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/share")))
        .ok_or_else(|| "Could not resolve a user data directory".to_string())?;

    Ok(data_home.join("myPad"))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            load_session,
            save_session,
            save_note_file,
            session_path
        ])
        .run(tauri::generate_context!())
        .expect("error while running myPad Ubuntu");
}
