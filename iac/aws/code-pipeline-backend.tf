locals {
  image-definition-file-name = "imagedefinitions.json"
  ecs_service_arn = format(
    "arn:aws:ecs:%s:%s:service/%s/%s",
    data.aws_region.current.region,
    data.aws_caller_identity.self.account_id,
    aws_ecs_cluster.cluster.name,
    aws_ecs_service.service.name
  )
}

resource "aws_codepipeline" "backend" {
  execution_mode = "QUEUED"
  name           = "${var.app-name}-${var.environment}-backend"
  pipeline_type  = "V2"
  role_arn       = aws_iam_role.backend-codepipeline.arn
  tags           = {}
  artifact_store {
    location = aws_s3_bucket.artifact.bucket
    region   = null
    type     = "S3"
  }

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
  stage {
    name = "Build"

    action {
      category = "Build"
      configuration = {
        "ProjectName" = aws_codebuild_project.backend.name
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
  stage {
    name = "Deploy"

    action {
      category = "Deploy"
      configuration = {
        "ClusterName" = aws_ecs_cluster.cluster.name
        "FileName"    = local.image-definition-file-name
        "ServiceName" = aws_ecs_service.service.name
      }
      input_artifacts = [
        "BuildArtifact",
      ]
      name             = "Deploy"
      namespace        = "DeployVariables"
      output_artifacts = []
      owner            = "AWS"
      provider         = "ECS"
      run_order        = 1
      version          = "1"
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
            "${var.backend-src-root}/**",
          ]
        }
      }
    }
  }

}


resource "aws_iam_role" "backend-codepipeline" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Condition = {
            StringEquals = {
              "aws:SourceAccount" = data.aws_caller_identity.self.account_id
            }
          }
          Effect = "Allow"
          Principal = {
            Service = "codepipeline.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  description          = null
  max_session_duration = 3600
  name                 = "${var.app-name}-${var.environment}-backend-codepipeline"
  path                 = "/service-role/"
  tags                 = {}
}


resource "aws_iam_role_policy" "backend-codepipeline" {
  name = "inline-2"
  policy = jsonencode(
    {
      Statement = [
        {
          Action   = "codebuild:StartBuild"
          Effect   = "Allow"
          Resource = aws_codebuild_project.backend.arn
        },
        {
          Action = [
            "ecr:DescribeImages",
          ]
          Effect   = "Allow"
          Resource = aws_ecr_repository.backend.arn
        },
        {
          Action = [
            "codebuild:BatchGetBuilds",
          ]
          Effect   = "Allow"
          Resource = aws_codebuild_project.backend.arn
        },
        {
          Action = [
            "s3:GetBucketVersioning",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
          ]
          Condition = {
            StringEquals = {
              "aws:ResourceAccount" = data.aws_caller_identity.self.account_id
            }
          }
          Effect   = "Allow"
          Resource = aws_s3_bucket.artifact.arn
        },
        {
          Action = [
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:GetObject",
            "s3:GetObjectVersion",
          ]
          Condition = {
            StringEquals = {
              "aws:ResourceAccount" = data.aws_caller_identity.self.account_id
            }
          }
          Effect   = "Allow"
          Resource = "${aws_s3_bucket.artifact.arn}/*"
        },
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
        {
          Action = [
            "ecs:ListClusters",
            "ecs:ListTaskDefinitions",
            "ecs:DescribeTasks",
            "ecs:DescribeTaskDefinition",
            "ecs:RegisterTaskDefinition",
          ]
          Effect = "Allow"
          Resource = [
            "*"
          ]
        },
        {
          Action = [
            "ecs:DescribeServices",
            "ecs:UpdateService",
          ]
          Effect = "Allow"
          Resource = [
            local.ecs_service_arn
          ]
        },
        {
          Action = [
            "ecs:TagResource",
          ]
          Effect = "Allow"
          Resource = [
            aws_ecs_cluster.cluster.arn,
            local.ecs_service_arn,
            aws_ecs_task_definition.task_definition.arn,
          ]
        },
        {
          Action = "iam:PassRole"
          Condition = {
            StringEquals = {
              "iam:PassedToService" = [
                "ecs.amazonaws.com",
                "ecs-tasks.amazonaws.com",
              ]
            }
          }
          Effect = "Allow"
          Resource = [
            aws_iam_role.execute_ecs_task.arn,
            aws_iam_role.ecs_task.arn,
          ]
        },
        {
          Action = [
            "ecs:DescribeClusters",
          ]
          Effect = "Allow"
          Resource = [
            aws_ecs_cluster.cluster.arn,
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
  role = aws_iam_role.backend-codepipeline.name
}

resource "aws_codebuild_project" "backend" {
  build_timeout      = 60
  name               = "${var.app-name}-${var.environment}-backend-codebuild"
  project_visibility = "PRIVATE"
  queued_timeout     = 480
  service_role       = aws_iam_role.backend-codebuild.arn
  tags               = {}

  artifacts {
    name = "${var.app-name}-${var.environment}-backend"
    type = "CODEPIPELINE"
  }

  cache {
    modes = []
    type  = "NO_CACHE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = null
      status      = "ENABLED"
      stream_name = null
    }
  }

  source {
    buildspec           = <<-EOT
              version: 0.2
  
              phases:
                pre_build:
                  commands:
                    - aws --version
                    - aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.self.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com
                    - REPOSITORY_URI=${aws_ecr_repository.backend.repository_url}
                    - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
                    - IMAGE_TAG=$${COMMIT_HASH:=latest}
                build:
                  commands:
                    - ORIGINAL_DIR=$(pwd)
                    - cd ./${var.backend-src-root}
                    - docker build -t $REPOSITORY_URI:latest -f ./Dockerfile .
                    - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
                post_build:
                  commands:
                    - docker push $REPOSITORY_URI:latest
                    - docker push $REPOSITORY_URI:$IMAGE_TAG
                    - cd $${ORIGINAL_DIR}
                    - printf '[{"name":"${var.app-name}","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > ${local.image-definition-file-name}
              artifacts:
                  files:
                    - ${local.image-definition-file-name}
          EOT
    git_clone_depth     = 0
    insecure_ssl        = false
    location            = null
    report_build_status = false
    type                = "CODEPIPELINE"
  }
}

resource "aws_iam_role" "backend-codebuild" {
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
  description          = null
  max_session_duration = 3600
  name                 = "${var.app-name}-${var.environment}-backend-codebuild-service-role"
  path                 = "/service-role/"
  tags                 = {}
}

resource "aws_iam_role_policy" "backend-codebuild" {
  name = "inline-2"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:PutImage",
          ]
          Effect   = "Allow"
          Resource = aws_ecr_repository.backend.arn
        },
        {
          Action   = "ecr:GetAuthorizationToken"
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
            "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:log-group:/aws/codebuild/*",
            "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:log-group:/aws/codebuild/*:*",
          ]
        },
        {
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
          ]
          Effect = "Allow"
          Resource = [
            "${aws_s3_bucket.artifact.arn}/*",
            aws_s3_bucket.artifact.arn,
          ]
        },
        {
          Action = [
            "codebuild:CreateReportGroup",
            "codebuild:CreateReport",
            "codebuild:UpdateReport",
            "codebuild:BatchPutTestCases",
            "codebuild:BatchPutCodeCoverages",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:codebuild:${data.aws_region.current.region}:${data.aws_caller_identity.self.account_id}:report-group/*",
          ]
        },

      ]
      Version = "2012-10-17"
    }
  )
  role = aws_iam_role.backend-codebuild.name
}
