# CodePipeline Artifact用のS3バケット
resource "aws_s3_bucket" "artifact" {
  bucket = "${var.app-name}-${var.environment}-artifact-${random_string.suffix.result}"
  tags   = {}
}

resource "aws_s3_bucket_public_access_block" "artifact" {
  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.artifact.bucket
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CodePipeline(フロントエンド)
resource "aws_codepipeline" "frontend" {
  execution_mode = "QUEUED"
  name           = "${var.app-name}-${var.environment}-frontend"
  pipeline_type  = "V2"
  role_arn       = aws_iam_role.codepipeline_frontend.arn
  tags           = {}

  artifact_store {
    location = aws_s3_bucket.artifact.bucket
    type     = "S3"
  }

  # ソースステージ
  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "BranchName"           = var.target-branch
        "ConnectionArn"        = var.codestar-connection-arn
        "DetectChanges"        = "true"
        "FullRepositoryId"     = var.github-repository-name
        "OutputArtifactFormat" = "CODE_ZIP"
      }
      input_artifacts = []
      name            = "Source"
      namespace       = "SourceVariables"
      output_artifacts = [
        "SourceArtifact",
      ]
      owner     = "AWS"
      provider  = "CodeStarSourceConnection"
      run_order = 1
      version   = "1"
    }
  }

  # ビルドステージ
  stage {
    name = "Build"

    action {
      category = "Build"
      configuration = {
        "ProjectName" = aws_codebuild_project.frontend.name
      }
      input_artifacts = [
        "SourceArtifact",
      ]
      name      = "Build"
      namespace = "BuildVariables"
      output_artifacts = [
        "BuildArtifact",
      ]
      owner     = "AWS"
      provider  = "CodeBuild"
      run_order = 1
      version   = "1"
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "Source"

      push {
        branches {
          includes = [
            var.target-branch,
          ]
        }
        file_paths {
          includes = [
            "${var.frontend-src-root}/**",
          ]
        }
      }
    }
  }
}

# ビルドステージのビルドプロジェクト
resource "aws_codebuild_project" "frontend" {
  badge_enabled      = false
  build_timeout      = 60
  name               = "${var.app-name}-${var.environment}-frontend-codebuild"
  project_visibility = "PRIVATE"
  service_role       = aws_iam_role.codebuild_frontend.arn
  tags               = {}

  artifacts {
    encryption_disabled    = false
    name                   = "${var.app-name}-${var.environment}-frontend"
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  # ビルドコマンド
  source {
    buildspec = <<-EOT
            version: 0.2

            phases:
              pre_build:
                commands:
                   - npm -v
                   - node -v
                   - n 23.1.0
                   - node -v
                   - npm install -g yarn
                   - yarn --version
              build:
                commands:
                   - cd ./${var.frontend-src-root}
                   - touch .env
                   - echo "VITE_AUTH0_DOMAIN=${var.auth0_domain}" > .env
                   - echo "VITE_AUTH0_CLIENT_ID=${auth0_client.app.client_id}" >> .env
                   - echo "VITE_AUTH0_AUDIENCE=https://${aws_cloudfront_distribution.cdn.domain_name}" >> .env
                   - echo "VITE_API_BASE_URL=https://${aws_cloudfront_distribution.cdn.domain_name}" >> .env
                   - cat .env
                   - yarn install
                   - yarn build
                   - aws s3 cp ./dist s3://${aws_s3_bucket.web.bucket}/ --recursive
                   - aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.cdn.id} --paths "/*"
        EOT
    type      = "CODEPIPELINE"
  }
}

# CodePipeline(フロントエンド)のIAMロール
resource "aws_iam_role" "codepipeline_frontend" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codepipeline.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  max_session_duration = 3600
  name                 = "codepipeline-${var.app-name}-${var.environment}-frontend-role"
  path                 = "/service-role/"
  tags                 = {}
}

# CodePipeline(フロントエンド)のIAMポリシー
resource "aws_iam_policy" "codepipeline_frontend" {
  description = null
  name        = "codepipeline-${var.app-name}-${var.environment}-frontend-policy"
  path        = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "codestar-connections:UseConnection",
          ]
          Effect = "Allow"
          Resource = [
            var.codestar-connection-arn
          ]
        },
        {
          Action = [
            "s3:PutObject",
          ]
          Effect   = "Allow"
          Resource = "${aws_s3_bucket.artifact.arn}/*"
        },
        {
          Action = [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild",
            "codebuild:BatchGetBuildBatches",
            "codebuild:StartBuildBatch",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:log-group:/aws/codepipeline/*",
            "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:log-group:/aws/codepipeline/*:log-stream:*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {}
}

resource "aws_iam_role_policy_attachment" "codepipeline_frontend" {
  role       = aws_iam_role.codepipeline_frontend.name
  policy_arn = aws_iam_policy.codepipeline_frontend.arn

}

# CodeBuild(フロントエンド)のIAMロール
resource "aws_iam_role" "codebuild_frontend" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codebuild.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  name = "codebuild-${var.app-name}-${var.environment}-frontend-role"
  path = "/service-role/"
  tags = {}
}

# CodeBuild(フロントエンド)のIAMポリシー
resource "aws_iam_policy" "codebuild_frontend" {
  description = null
  name        = "codebuild-${var.app-name}-${var.environment}-frontend-policy"
  path        = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:PutLogEvents",
            "logs:CreateLogStream",
            "logs:DescribeLogStreams",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:log-group:/aws/codebuild/*",
            "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:log-group:/aws/codebuild/*:log-stream:*"
          ]
        },
        {
          Action = [
            "codebuild:UpdateReport",
            "codebuild:BatchPutCodeCoverages",
            "codebuild:BatchPutTestCases",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:codebuild:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:report-group/*",
          ]
        },
        {
          Action   = "s3:GetObject"
          Effect   = "Allow"
          Resource = "${aws_s3_bucket.artifact.arn}/*"
        },
        {
          Action   = "s3:PutObject"
          Effect   = "Allow"
          Resource = "${aws_s3_bucket.web.arn}/*"
        },
        {
          Action   = "cloudfront:CreateInvalidation"
          Effect   = "Allow"
          Resource = aws_cloudfront_distribution.cdn.arn
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {}
}

resource "aws_iam_role_policy_attachment" "codebuild_frontend" {
  role       = aws_iam_role.codebuild_frontend.name
  policy_arn = aws_iam_policy.codebuild_frontend.arn
}
