use actix_web::{web, HttpResponse};
use chrono::Utc;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::AuthenticatedUser;
use crate::models::sync_data::{
    PullRequest, PullResponse, PushRequest, PushSettingsRequest, PullSettingsResponse, SyncRecord,
};

pub async fn push(
    user: AuthenticatedUser,
    pool: web::Data<PgPool>,
    body: web::Json<PushRequest>,
) -> Result<HttpResponse, AppError> {
    let now = Utc::now();

    for record in &body.records {
        let data_type = record.data_type.trim();
        let data_key = record.data_key.trim();

        if data_type.is_empty() || data_key.is_empty() {
            continue;
        }

        sqlx::query(
            r#"INSERT INTO sync_records (user_id, data_type, data_key, payload, updated_at)
               VALUES ($1, $2, $3, $4, $5)
               ON CONFLICT (user_id, data_type, data_key)
               DO UPDATE SET payload = EXCLUDED.payload, updated_at = EXCLUDED.updated_at, is_deleted = FALSE"#,
        )
        .bind(user.user_id)
        .bind(data_type)
        .bind(data_key)
        .bind(&record.payload)
        .bind(record.updated_at)
        .execute(pool.get_ref())
        .await?;
    }

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": { "accepted": body.records.len(), "server_time": now },
    })))
}

pub async fn pull(
    user: AuthenticatedUser,
    pool: web::Data<PgPool>,
    body: web::Json<PullRequest>,
) -> Result<HttpResponse, AppError> {
    let now = Utc::now();
    let since = body.last_sync;

    let records = if let Some(since) = since {
        sqlx::query_as::<_, SyncRecordRow>(
            r#"SELECT data_type, data_key, payload, updated_at
               FROM sync_records
               WHERE user_id = $1 AND updated_at > $2 AND is_deleted = FALSE
               ORDER BY updated_at ASC
               LIMIT 1000"#,
        )
        .bind(user.user_id)
        .bind(since)
        .fetch_all(pool.get_ref())
        .await?
    } else {
        sqlx::query_as::<_, SyncRecordRow>(
            r#"SELECT data_type, data_key, payload, updated_at
               FROM sync_records
               WHERE user_id = $1 AND is_deleted = FALSE
               ORDER BY updated_at ASC
               LIMIT 1000"#,
        )
        .bind(user.user_id)
        .fetch_all(pool.get_ref())
        .await?
    };

    let response = PullResponse {
        records: records.into_iter().map(|r| r.into()).collect(),
        server_time: now,
    };

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": response,
    })))
}

pub async fn push_settings(
    user: AuthenticatedUser,
    pool: web::Data<PgPool>,
    body: web::Json<PushSettingsRequest>,
) -> Result<HttpResponse, AppError> {
    sqlx::query(
        r#"INSERT INTO user_settings (user_id, payload, updated_at)
           VALUES ($1, $2, NOW())
           ON CONFLICT (user_id)
           DO UPDATE SET payload = EXCLUDED.payload, updated_at = NOW()"#,
    )
    .bind(user.user_id)
    .bind(&body.payload)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
    })))
}

pub async fn pull_settings(
    user: AuthenticatedUser,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, AppError> {
    let row = sqlx::query_as::<_, SettingsRow>(
        "SELECT payload, updated_at FROM user_settings WHERE user_id = $1",
    )
    .bind(user.user_id)
    .fetch_optional(pool.get_ref())
    .await?;

    let response = match row {
        Some(r) => PullSettingsResponse {
            payload: r.payload,
            updated_at: Some(r.updated_at),
        },
        None => PullSettingsResponse {
            payload: serde_json::json!({}),
            updated_at: None,
        },
    };

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": response,
    })))
}

#[derive(Debug, sqlx::FromRow)]
struct SyncRecordRow {
    data_type: String,
    data_key: String,
    payload: serde_json::Value,
    updated_at: chrono::DateTime<Utc>,
}

impl From<SyncRecordRow> for SyncRecord {
    fn from(r: SyncRecordRow) -> Self {
        Self {
            data_type: r.data_type,
            data_key: r.data_key,
            payload: r.payload,
            updated_at: r.updated_at,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
struct SettingsRow {
    payload: serde_json::Value,
    updated_at: chrono::DateTime<Utc>,
}
