#!/bin/bash
set -e

# ─────────────────────────────────────────
#  CONFIG — edit these before running
# ─────────────────────────────────────────
GITHUB_USERNAME="LMAO-armv8"
GITHUB_REPO="docker"
AWS_REGION="us-east-1"
ROLE_NAME="github-packer-role"
# ─────────────────────────────────────────

echo ""
echo "=========================================="
echo "  GitHub Actions OIDC Setup"
echo "=========================================="
echo ""

# ── 1. Get Account ID ──────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[1/4] Account ID: $ACCOUNT_ID"

# ── 2. Create OIDC Provider ────────────────
echo ""
echo "[2/4] Setting up OIDC provider..."

EXISTING_OIDC=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" \
  --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_OIDC" ]; then
  echo "  OIDC provider already exists — skipping."
else
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 > /dev/null
  echo "  OIDC provider created."
fi

# ── 3. Create IAM Role ─────────────────────
echo ""
echo "[3/4] Creating IAM role..."

EXISTING_ROLE=$(aws iam get-role --role-name $ROLE_NAME \
  --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_ROLE" ]; then
  echo "  Role already exists — updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name $ROLE_NAME \
    --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [{
        \"Effect\": \"Allow\",
        \"Principal\": {
          \"Federated\": \"arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com\"
        },
        \"Action\": \"sts:AssumeRoleWithWebIdentity\",
        \"Condition\": {
          \"StringLike\": {
            \"token.actions.githubusercontent.com:sub\": \"repo:${GITHUB_USERNAME}/${GITHUB_REPO}:*\"
          },
          \"StringEquals\": {
            \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
          }
        }
      }]
    }"
else
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [{
        \"Effect\": \"Allow\",
        \"Principal\": {
          \"Federated\": \"arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com\"
        },
        \"Action\": \"sts:AssumeRoleWithWebIdentity\",
        \"Condition\": {
          \"StringLike\": {
            \"token.actions.githubusercontent.com:sub\": \"repo:${GITHUB_USERNAME}/${GITHUB_REPO}:*\"
          },
          \"StringEquals\": {
            \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
          }
        }
      }]
    }" > /dev/null
  echo "  Role created."
fi

# Attach permissions (always overwrite to keep up to date)
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name packer-permissions \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeRegions",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeKeyPairs",
        "ec2:RunInstances",
        "ec2:CreateImage",
        "ec2:DeregisterImage",
        "ec2:DeleteSnapshot",
        "ec2:CreateTags",
        "ec2:ModifyImageAttribute",
        "ec2:TerminateInstances",
        "ec2:StopInstances",
        "ec2:CreateKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    }]
  }' > /dev/null
echo "  Permissions attached."

# ── 4. Print role ARN ──────────────────────
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

echo ""
echo "=========================================="
echo "  ✅ OIDC Setup Complete"
echo "=========================================="
echo ""
echo "  Add this to GitHub Secrets:"
echo ""
echo "  Secret name : AWS_ROLE_ARN"
echo "  Secret value: $ROLE_ARN"
echo ""
echo "  Go to:"
echo "  github.com/${GITHUB_USERNAME}/${GITHUB_REPO}/settings/secrets/actions"
echo "=========================================="
