use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Serialize, Deserialize)]
pub struct SyncRecord {
    pub data_type: String,
    pub data_key: String,
    pub payload: Value,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct PushRequest {
    pub records: Vec<SyncRecord>,
}

#[derive(Debug, Deserialize)]
pub struct PullRequest {
    pub last_sync: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
pub struct PullResponse {
    pub records: Vec<SyncRecord>,
    pub server_time: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct PushSettingsRequest {
    pub payload: Value,
}

#[derive(Debug, Serialize)]
pub struct PullSettingsResponse {
    pub payload: Value,
    pub updated_at: Option<DateTime<Utc>>,
}
