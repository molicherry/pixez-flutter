use actix_web::{web, HttpResponse};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use serde::Deserialize;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::AuthenticatedUser;
use crate::models::user::UserPublic;

#[derive(Deserialize)]
pub struct RecordsQuery {
    pub data_type: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Deserialize)]
pub struct ChangePasswordRequest {
    pub password: String,
}

pub async fn change_password(
    admin: AuthenticatedUser,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
    body: web::Json<ChangePasswordRequest>,
) -> Result<HttpResponse, AppError> {
    let is_admin = sqlx::query_scalar::<_, bool>(
        "SELECT is_admin FROM users WHERE id = $1"
    )
    .bind(admin.user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !is_admin {
        return Err(AppError::Unauthorized("admin access required".into()));
    }

    let password = body.password.trim();
    if password.len() < 6 {
        return Err(AppError::BadRequest("password must be at least 6 characters".into()));
    }

    let salt = SaltString::generate(&mut OsRng);
    let password_hash = Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| {
            log::error!("Password hashing error: {}", e);
            AppError::Internal("password hashing failed".into())
        })?
        .to_string();

    let target_id = path.into_inner();
    sqlx::query("UPDATE users SET password_hash = $1 WHERE id = $2")
        .bind(&password_hash)
        .bind(target_id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({"ok": true})))
}

pub async fn list_users(
    admin: AuthenticatedUser,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, AppError> {
    let is_admin = sqlx::query_scalar::<_, bool>(
        "SELECT is_admin FROM users WHERE id = $1"
    )
    .bind(admin.user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !is_admin {
        return Err(AppError::Unauthorized("admin access required".into()));
    }

    let users = sqlx::query_as::<_, UserPublic>(
        "SELECT id, username, is_admin, created_at FROM users ORDER BY id"
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": users,
    })))
}

pub async fn delete_user(
    admin: AuthenticatedUser,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> Result<HttpResponse, AppError> {
    let is_admin = sqlx::query_scalar::<_, bool>(
        "SELECT is_admin FROM users WHERE id = $1"
    )
    .bind(admin.user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !is_admin {
        return Err(AppError::Unauthorized("admin access required".into()));
    }

    let target_id = path.into_inner();
    if target_id == admin.user_id {
        return Err(AppError::BadRequest("cannot delete yourself".into()));
    }

    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(target_id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({"ok": true})))
}

pub async fn view_user_data(
    admin: AuthenticatedUser,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> Result<HttpResponse, AppError> {
    let is_admin = sqlx::query_scalar::<_, bool>(
        "SELECT is_admin FROM users WHERE id = $1"
    )
    .bind(admin.user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !is_admin {
        return Err(AppError::Unauthorized("admin access required".into()));
    }

    let target_id = path.into_inner();
    let records = sqlx::query_as::<_, SyncRecordSummary>(
        "SELECT data_type, COUNT(*) as count, MAX(updated_at) as last_updated
         FROM sync_records WHERE user_id = $1 AND is_deleted = FALSE
         GROUP BY data_type ORDER BY data_type"
    )
    .bind(target_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": { "user_id": target_id, "records": records },
    })))
}

pub async fn my_data(
    user: AuthenticatedUser,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, AppError> {
    let records = sqlx::query_as::<_, SyncRecordSummary>(
        "SELECT data_type, COUNT(*) as count, MAX(updated_at) as last_updated
         FROM sync_records WHERE user_id = $1 AND is_deleted = FALSE
         GROUP BY data_type ORDER BY data_type"
    )
    .bind(user.user_id)
    .fetch_all(pool.get_ref())
    .await?;

    let settings = sqlx::query_scalar::<_, serde_json::Value>(
        "SELECT payload FROM user_settings WHERE user_id = $1"
    )
    .bind(user.user_id)
    .fetch_optional(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": {
            "user_id": user.user_id,
            "username": user.username,
            "records": records,
            "settings": settings,
        },
    })))
}

#[derive(Debug, serde::Serialize, serde::Deserialize, sqlx::FromRow)]
struct SyncRecordSummary {
    data_type: String,
    count: i64,
    last_updated: Option<chrono::DateTime<chrono::Utc>>,
}

pub async fn browse_records(
    user: AuthenticatedUser,
    pool: web::Data<PgPool>,
    query: web::Query<RecordsQuery>,
) -> Result<HttpResponse, AppError> {
    let limit = query.limit.unwrap_or(50).min(200);
    let offset = query.offset.unwrap_or(0);

    let rows = if let Some(ref dt) = query.data_type {
        sqlx::query_as::<_, SyncRecordRow>(
            "SELECT data_type, data_key, payload, updated_at
             FROM sync_records
             WHERE user_id = $1 AND data_type = $2 AND is_deleted = FALSE
             ORDER BY updated_at DESC
             LIMIT $3 OFFSET $4"
        )
        .bind(user.user_id)
        .bind(dt)
        .bind(limit)
        .bind(offset)
        .fetch_all(pool.get_ref())
        .await?
    } else {
        sqlx::query_as::<_, SyncRecordRow>(
            "SELECT data_type, data_key, payload, updated_at
             FROM sync_records
             WHERE user_id = $1 AND is_deleted = FALSE
             ORDER BY updated_at DESC
             LIMIT $2 OFFSET $3"
        )
        .bind(user.user_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(pool.get_ref())
        .await?
    };

    let total: (i64,) = if let Some(ref dt) = query.data_type {
        sqlx::query_as(
            "SELECT COUNT(*) FROM sync_records WHERE user_id = $1 AND data_type = $2 AND is_deleted = FALSE"
        )
        .bind(user.user_id)
        .bind(dt)
        .fetch_one(pool.get_ref())
        .await?
    } else {
        sqlx::query_as(
            "SELECT COUNT(*) FROM sync_records WHERE user_id = $1 AND is_deleted = FALSE"
        )
        .bind(user.user_id)
        .fetch_one(pool.get_ref())
        .await?
    };

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": {
            "total": total.0,
            "limit": limit,
            "offset": offset,
            "records": rows,
        },
    })))
}

#[derive(Debug, serde::Serialize, serde::Deserialize, sqlx::FromRow)]
struct SyncRecordRow {
    data_type: String,
    data_key: String,
    payload: serde_json::Value,
    updated_at: chrono::DateTime<chrono::Utc>,
}
