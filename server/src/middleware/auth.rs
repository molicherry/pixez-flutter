use actix_web::{dev::Payload, FromRequest, HttpRequest};
use jsonwebtoken::{decode, DecodingKey, Validation};
use std::future::{ready, Ready};

use crate::config::Config;
use crate::errors::AppError;
use crate::models::user::Claims;

#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub user_id: i32,
    pub username: String,
}

impl FromRequest for AuthenticatedUser {
    type Error = AppError;
    type Future = Ready<Result<Self, Self::Error>>;

    fn from_request(req: &HttpRequest, _payload: &mut Payload) -> Self::Future {
        let config = req.app_data::<actix_web::web::Data<Config>>();
        let config = match config {
            Some(c) => c,
            None => return ready(Err(AppError::Internal("missing config".into()))),
        };

        let auth_header = req
            .headers()
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "));

        let token = match auth_header {
            Some(t) => t,
            None => return ready(Err(AppError::Unauthorized("missing authorization header".into()))),
        };

        let token_data = match decode::<Claims>(
            token,
            &DecodingKey::from_secret(config.jwt_secret.as_bytes()),
            &Validation::default(),
        ) {
            Ok(data) => data,
            Err(e) => return ready(Err(e.into())),
        };

        ready(Ok(AuthenticatedUser {
            user_id: token_data.claims.sub,
            username: token_data.claims.username,
        }))
    }
}
