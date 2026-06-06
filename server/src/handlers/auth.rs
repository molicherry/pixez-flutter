use actix_web::{web, HttpResponse};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::Utc;
use jsonwebtoken::{encode, EncodingKey, Header};
use sqlx::PgPool;

use crate::config::Config;
use crate::errors::AppError;
use crate::models::user::{
    AuthResponse, Claims, LoginRequest, RegisterRequest, User, UserPublic,
};
use crate::middleware::auth::AuthenticatedUser;

pub async fn register(
    pool: web::Data<PgPool>,
    config: web::Data<Config>,
    body: web::Json<RegisterRequest>,
) -> Result<HttpResponse, AppError> {
    let username = body.username.trim().to_lowercase();
    let password = body.password.trim();

    if username.len() < 3 || username.len() > 64 {
        return Err(AppError::BadRequest("username must be 3-64 characters".into()));
    }
    if password.len() < 6 {
        return Err(AppError::BadRequest("password must be at least 6 characters".into()));
    }

    let existing = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM users WHERE username = $1")
        .bind(&username)
        .fetch_one(pool.get_ref())
        .await?;

    if existing > 0 {
        return Err(AppError::Conflict("username already exists".into()));
    }

    let salt = SaltString::generate(&mut OsRng);
    let password_hash = Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| {
            log::error!("Password hashing error: {}", e);
            AppError::Internal("password hashing failed".into())
        })?
        .to_string();

    let user = sqlx::query_as::<_, User>(
        "INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id, username, password_hash, is_admin, created_at"
    )
        .bind(&username)
        .bind(&password_hash)
        .fetch_one(pool.get_ref())
        .await?;

    let token = generate_token(&user, &config)?;
    let public: UserPublic = user.into();

    Ok(HttpResponse::Created().json(serde_json::json!({
        "ok": true,
        "data": AuthResponse { token, user: public },
    })))
}

pub async fn login(
    pool: web::Data<PgPool>,
    config: web::Data<Config>,
    body: web::Json<LoginRequest>,
) -> Result<HttpResponse, AppError> {
    let username = body.username.trim().to_lowercase();

    let user = sqlx::query_as::<_, User>("SELECT id, username, password_hash, is_admin, created_at FROM users WHERE username = $1")
        .bind(&username)
        .fetch_optional(pool.get_ref())
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid username or password".into()))?;

    let parsed_hash = PasswordHash::new(&user.password_hash).map_err(|_| {
        AppError::Internal("invalid stored password hash".into())
    })?;

    Argon2::default()
        .verify_password(body.password.as_bytes(), &parsed_hash)
        .map_err(|_| AppError::Unauthorized("invalid username or password".into()))?;

    let token = generate_token(&user, &config)?;
    let public: UserPublic = user.into();

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": AuthResponse { token, user: public },
    })))
}

pub async fn refresh(
    user: AuthenticatedUser,
    config: web::Data<Config>,
) -> Result<HttpResponse, AppError> {
    let now = Utc::now();
    let exp = (now + chrono::Duration::hours(config.jwt_expiration_hours)).timestamp() as usize;

    let claims = Claims {
        sub: user.user_id,
        username: user.username.clone(),
        exp,
        iat: now.timestamp() as usize,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(config.jwt_secret.as_bytes()),
    )?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": { "token": token },
    })))
}

pub async fn delete_account(
    user: AuthenticatedUser,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, AppError> {
    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(user.user_id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "data": { "message": "account deleted" },
    })))
}

fn generate_token(user: &User, config: &Config) -> Result<String, AppError> {
    let now = Utc::now();
    let exp = (now + chrono::Duration::hours(config.jwt_expiration_hours)).timestamp() as usize;

    let claims = Claims {
        sub: user.id,
        username: user.username.clone(),
        exp,
        iat: now.timestamp() as usize,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(config.jwt_secret.as_bytes()),
    )
    .map_err(|e| e.into())
}
