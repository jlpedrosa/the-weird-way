

locals {
  validiy_hours = 60000
  organization = "Developers, Inc"
  all_cert_uses = [
    "any_extended",
    "cert_signing",
    "client_auth",
    "code_signing",
    "content_commitment",
    "crl_signing",
    "data_encipherment",
    "decipher_only",
    "digital_signature",
    "email_protection",
    "encipher_only",
    "ipsec_end_system",
    "ipsec_tunnel",
    "ipsec_user",
    "key_agreement",
    "key_encipherment",
    "microsoft_commercial_code_signing",
    "microsoft_kernel_code_signing",
    "microsoft_server_gated_crypto",
    "netscape_server_gated_crypto",
    "ocsp_signing",
    "server_auth",
    "timestamping",
  ]
}

# RSA key of size 4096 bits
resource "tls_private_key" "ca_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_private_key.private_key_pem

  subject {
    common_name  = "kubernetes"
    organization = local.organization
  }

  is_ca_certificate     = true
  validity_period_hours = local.validiy_hours
  allowed_uses          = local.all_cert_uses
}

# RSA key of size 4096 bits
resource "tls_private_key" "node_private_key" {
  for_each = local.nodes
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "node_cert_request" {
  for_each = local.nodes
  private_key_pem = tls_private_key.node_private_key[each.key].private_key_pem

  subject {
    common_name  = each.key
    organization = local.organization
  }
}

resource "tls_locally_signed_cert" "node_cert" {
  for_each           = local.nodes
  cert_request_pem   = tls_cert_request.node_cert_request[each.key].cert_request_pem
  ca_private_key_pem = tls_self_signed_cert.ca_cert.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = local.validiy_hours
  allowed_uses          = local.all_cert_uses
}