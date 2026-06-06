use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

use crate::config::Config;

pub async fn create_pool(database_url: &str) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(10)
        .connect(database_url)
        .await
}

pub async fn run_migrations(pool: &PgPool) -> Result<(), sqlx::Error> {
    let sql = include_str!("../migrations/001_init.sql");
    for statement in sql.split(';') {
        let trimmed = statement.trim();
        if trimmed.is_empty() {
            continue;
        }
        sqlx::query(trimmed).execute(pool).await?;
    }
    log::info!("Database migrations completed");
    Ok(())
}

pub async fn upsert_admin(pool: &PgPool, config: &Config) -> Result<(), sqlx::Error> {
    let salt = SaltString::generate(&mut OsRng);
    let password_hash = Argon2::default()
        .hash_password(config.admin_password.as_bytes(), &salt)
        .map_err(|e| {
            log::error!("Admin password hashing error: {}", e);
            sqlx::Error::Protocol("password hashing failed".into())
        })?
        .to_string();

    sqlx::query(
        r#"INSERT INTO users (username, password_hash, is_admin)
           VALUES ($1, $2, TRUE)
           ON CONFLICT (username)
           DO UPDATE SET password_hash = EXCLUDED.password_hash, is_admin = TRUE"#,
    )
    .bind(&config.admin_username)
    .bind(&password_hash)
    .execute(pool)
    .await?;

    log::info!(
        "Admin user '{}' ensured",
        config.admin_username
    );
    Ok(())
}
