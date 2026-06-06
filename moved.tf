# ==============================================================================
# STATE REFACTORING (Terraform 1.1+)
# These blocks instruct Terraform Cloud to move the state of renamed resources
# without attempting to destroy and recreate them in AWS.
# ==============================================================================

# 1. Map the EC2 Web Server Module
moved {
  from = module.web_server
  to   = module.web_dynamic
}

# 2. Map the Database
moved {
  from = aws_db_instance.postgres
  to   = aws_db_instance.db_dynamic
}

# 3. Map the Load Balancer Module
moved {
  from = module.alb
  to   = module.alb_dynamic
}

# 4. Map the Security Groups
moved {
  from = module.alb_sg
  to   = module.alb_dynamic_sg
}
moved {
  from = module.web_server_sg
  to   = module.web_dynamic_sg
}
moved {
  from = module.rds_sg
  to   = module.db_dynamic_sg
}

# 5. Target Group internal rename within ALB module
# The internal key changed from "web-tg" to "web-dynamic-tg"
moved {
  from = module.alb_dynamic.aws_lb_target_group.this["web-tg"]
  to   = module.alb_dynamic.aws_lb_target_group.this["web-dynamic-tg"]
}
