# ==========================================
# 1. Proveedor OIDC único de GitHub
# ==========================================
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# ==========================================
# 2. Listado de repositorios y políticas de AWS
# ==========================================
locals {
  github_org = "lopezzuluagaj3-collab"

  github_repos = {
    "pipeline-sirius-tlc"        = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
    "matchiq_infrastructure_aws" = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  }
}

# ==========================================
# 3. Creación dinámica de Roles de IAM
# ==========================================
resource "aws_iam_role" "github_actions" {
  for_each = local.github_repos

  name = "github-actions-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action = [
          "sts:AssumeRoleWithWebIdentity",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${local.github_org}*/${each.key}*:*"
          }
        }
      }
    ]
  })
}

# ==========================================
# 4. Asignación de permisos específicos a cada Rol
# ==========================================
resource "aws_iam_role_policy_attachment" "github_attachments" {
  for_each   = local.github_repos
  role       = aws_iam_role.github_actions[each.key].name
  policy_arn = each.value
}

# ==========================================
# 5. Outputs para usar en tus pipelines de GitHub
# ==========================================
output "roles_creados" {
  value       = { for k, v in aws_iam_role.github_actions : k => v.arn }
  description = "ARNs de los roles creados. Cópialos en los respectivos flujos de GitHub Actions."
}

resource "aws_iam_policy" "sirius_terraform_deploy" {
  name        = "sirius-terraform-deploy-policy"
  description = "Permisos mínimos para que Terraform gestione la infraestructura de Sirius"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # --- S3: buckets del proyecto (raw, staging, mart, athena-results) ---
      {
        Sid    = "S3BucketLevel"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketTagging",
          "s3:GetBucketTagging",
          "s3:PutBucketVersioning",
          "s3:GetBucketVersioning",
          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketCors",
          "s3:PutBucketCors",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:GetAccelerateConfiguration",
          "s3:PutAccelerateConfiguration",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetBucketRequestPayment",
          "s3:PutBucketRequestPayment",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:GetReplicationConfiguration",
          "s3:PutReplicationConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:PutBucketObjectLockConfiguration",
          "s3:CreateBucket",
          "s3:DeleteBucket"
        ]
        Resource = "arn:aws:s3:::sirius-*"
      },
      {
        Sid    = "S3ObjectLevel"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Resource = "arn:aws:s3:::sirius-*/*"
      },

      # --- SQS: colas del proyecto ---
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:TagQueue",
          "sqs:ListQueueTags"
        ]
        Resource = "arn:aws:sqs:us-east-2:603437461408:sirius-*"
      },

      # --- Lambda: funciones del proyecto ---
      # --- Lambda: funciones del proyecto ---
      {
        Sid    = "LambdaAccess"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
          "lambda:ListVersionsByFunction",
          "lambda:GetFunctionCodeSigningConfig"
        ]
        Resource = "arn:aws:lambda:us-east-2:603437461408:function:sirius-*"
      },

      # --- Lambda: event source mappings (ARN con ID generado, no se puede acotar por nombre) ---
      {
        Sid    = "LambdaEventSourceMappings"
        Effect = "Allow"
        Action = [
          "lambda:CreateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:GetEventSourceMapping",
          "lambda:UpdateEventSourceMapping",
          "lambda:ListEventSourceMappings",
          "lambda:ListTags"
        ]
        Resource = "*"
      },

      # --- EventBridge: reglas del proyecto ---
      {
        Sid    = "EventBridgeAccess"
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:DeleteRule",
          "events:DescribeRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:ListTargetsByRule",
          "events:TagResource",
          "events:UntagResource",
          "events:ListTagsForResource"
        ]
        Resource = "arn:aws:events:us-east-2:603437461408:rule/sirius-*"
      },

      # --- Glue: databases, tablas y jobs del proyecto ---
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase",
          "glue:DeleteDatabase",
          "glue:GetDatabase",
          "glue:UpdateDatabase",
          "glue:CreateTable",
          "glue:DeleteTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:UpdateTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreateJob",
          "glue:DeleteJob",
          "glue:GetJob",
          "glue:UpdateJob",
          "glue:TagResource",
          "glue:UntagResource",
          "glue:GetTags"
        ]
        Resource = [
          "arn:aws:glue:us-east-2:603437461408:catalog",
          "arn:aws:glue:us-east-2:603437461408:database/sirius_*",
          "arn:aws:glue:us-east-2:603437461408:table/sirius_*/*",
          "arn:aws:glue:us-east-2:603437461408:job/sirius-*"
        ]
      },

      # --- Athena: workgroup y queries ---
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup",
          "athena:CreateWorkGroup",
          "athena:UpdateWorkGroup",
          "athena:DeleteWorkGroup"
        ]
        Resource = "*"
      },

      # --- IAM: solo roles/políticas propios del proyecto, con PassRole acotado ---
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = "arn:aws:iam::603437461408:role/sirius-*"
      },
      {
        Sid      = "IAMPassRoleScoped"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::603437461408:role/sirius-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "lambda.amazonaws.com",
              "glue.amazonaws.com"
            ]
          }
        }
      },

      # --- IAM: gestión de la propia política de Terraform ---
      {
        Sid    = "IAMPolicySelfManagement"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:ListEntitiesForPolicy"
        ]
        Resource = "arn:aws:iam::603437461408:policy/sirius-*"
      },

      # --- IAM: proveedor OIDC de GitHub (recurso único, no sigue el patrón sirius-*) ---
      {
        Sid    = "IAMOIDCProvider"
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviderTags"
        ]
        Resource = "arn:aws:iam::603437461408:oidc-provider/token.actions.githubusercontent.com"
      },

      # --- IAM: los propios roles de GitHub Actions (OIDC), gestionados por Terraform ---
      {
        Sid    = "IAMGitHubActionsRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies"
        ]
        Resource = "arn:aws:iam::603437461408:role/github-actions-*-role"
      },

      # --- Backend de Terraform: bucket de state ---
      {
        Sid      = "TerraformStateList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::sirius-tfstate-603437461408"
      },
      {
        Sid    = "TerraformStateObject"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::sirius-tfstate-603437461408/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sirius_terraform_deploy" {
  role       = aws_iam_role.github_actions["pipeline-sirius-tlc"].name
  policy_arn = aws_iam_policy.sirius_terraform_deploy.arn
}