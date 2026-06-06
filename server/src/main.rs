use actix_cors::Cors;
use actix_files as fs;
use actix_web::{web, App, HttpServer};
use actix_web::middleware::Logger;

pub mod config;
mod db;
mod errors;
mod handlers;
pub mod middleware;
mod models;

use config::Config;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenvy::dotenv().ok();
    env_logger::init_from_env(env_logger::Env::default().default_filter_or("info"));

    let config = Config::from_env();
    let pool = db::create_pool(&config.database_url)
        .await
        .expect("Failed to create database pool");

    db::run_migrations(&pool)
        .await
        .expect("Failed to run migrations");

    db::upsert_admin(&pool, &config)
        .await
        .expect("Failed to ensure admin user");

    let bind = config.bind_address.clone();
    log::info!("Starting server on {}", bind);

    HttpServer::new(move || {
        let cors = Cors::permissive();

        App::new()
            .wrap(cors)
            .wrap(Logger::default())
            .app_data(web::Data::new(pool.clone()))
            .app_data(web::Data::new(config.clone()))
            .service(
                web::scope("/api")
                    .service(
                        web::scope("/auth")
                            .route("/register", web::post().to(handlers::auth::register))
                            .route("/login", web::post().to(handlers::auth::login))
                            .route("/refresh", web::post().to(handlers::auth::refresh))
                            .route("/account", web::delete().to(handlers::auth::delete_account)),
                    )
                    .service(
                        web::scope("/sync")
                            .route("/push", web::post().to(handlers::sync::push))
                            .route("/pull", web::post().to(handlers::sync::pull))
                            .route("/push-settings", web::post().to(handlers::sync::push_settings))
                            .route("/pull-settings", web::get().to(handlers::sync::pull_settings)),
                    )
                    .service(
                        web::scope("/admin")
                            .route("/users", web::get().to(handlers::admin::list_users))
                            .route("/users/{id}", web::delete().to(handlers::admin::delete_user))
                            .route("/users/{id}/data", web::get().to(handlers::admin::view_user_data))
                            .route("/users/{id}/password", web::put().to(handlers::admin::change_password))
                            .route("/me/data", web::get().to(handlers::admin::my_data))
                            .route("/me/records", web::get().to(handlers::admin::browse_records)),
                    ),
            )
            .route("/health", web::get().to(|| async { "ok" }))
            .service(fs::Files::new("/", "static").index_file("index.html"))
    })
    .bind(&bind)?
    .run()
    .await
}
