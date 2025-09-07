resource "auth0_client" "app" {
  allowed_logout_urls = [
    "https://${aws_cloudfront_distribution.cdn.domain_name}",
  ]
  app_type = "spa"
  callbacks = [
    "https://${aws_cloudfront_distribution.cdn.domain_name}",
  ]
  cross_origin_auth = false
  grant_types = [
    "authorization_code",
    "implicit",
    "refresh_token",
  ]
  name            = "${var.app-name}-${var.environment}-aws-idp"
  oidc_conformant = true
  web_origins = [
    "https://${aws_cloudfront_distribution.cdn.domain_name}",
  ]

  jwt_configuration {
    alg = "RS256"
  }
}
