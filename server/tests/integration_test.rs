use std::env;

fn set_test_env() {
    env::set_var("DATABASE_URL", "postgres://pixez:pixez_test@localhost:5432/pixez_sync");
    env::set_var("JWT_SECRET", "ci-test-jwt-secret-never-used-in-production");
    env::set_var("ADMIN_PASSWORD", "ci-test-admin-password-never-used-in-production");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_required() {
        set_test_env();
        let config = pixez_sync_server::config::Config::from_env();
        assert!(!config.jwt_secret.is_empty());
        assert!(!config.admin_password.is_empty());
        assert!(config.jwt_expiration_hours > 0);
        assert!(!config.bind_address.is_empty());
    }
}