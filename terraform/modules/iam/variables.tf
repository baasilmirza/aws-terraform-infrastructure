variable "environment" {
  description = "Environment suffix for role/profile names"
  type        = string
}

variable "region" {
  description = "AWS region (used in ARNs)"
  type        = string
}

variable "ssm_session_allowed" {
  description = "True = allow SSM sessions on this stack's instance via the ops role; false = add an explicit Deny (least-privilege demo)"
  type        = bool
  default     = true
}
