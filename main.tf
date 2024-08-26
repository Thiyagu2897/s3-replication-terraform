
provider "aws" {
  alias  = "use1"
  region = "us-east-1"  # Source bucket region
}

provider "aws" {
  alias  = "use2"
  region = "us-east-2"  # Destination bucket region
}

# Source bucket in us-east-1
resource "aws_s3_bucket" "source_bucket" {
  provider = aws.use1
  bucket   = "my-source-bucket-unique-name-use1"
  acl      = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name = "SourceBucket"
  }
}

# Destination bucket in us-east-2
resource "aws_s3_bucket" "destination_bucket" {
  provider = aws.use2
  bucket   = "my-destination-bucket-unique-name-use2"
  acl      = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name = "DestinationBucket"
  }
}

# IAM Role for S3 Replication
resource "aws_iam_role" "replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for S3 Replication
resource "aws_iam_role_policy" "replication_policy" {
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.source_bucket.arn}/*",
        ]
      },
      {
        Action = "s3:ListBucket"
        Effect = "Allow"
        Resource = aws_s3_bucket.source_bucket.arn
      },
      {
        Action = "s3:ReplicateObject"
        Effect = "Allow"
        Resource = "${aws_s3_bucket.destination_bucket.arn}/*"
      }
    ]
  })
}

# S3 Bucket Replication Configuration in the source bucket
resource "aws_s3_bucket_replication_configuration" "replication" {
  depends_on = [aws_iam_role_policy.replication_policy]
  bucket     = aws_s3_bucket.source_bucket.bucket
  role       = aws_iam_role.replication_role.arn

  rule {
    id     = "replication-rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
      
    }
  }
}
